"""
SQL Client for Microsoft SQL Server using pyodbc.
Handles connection management, parameterized query execution, multi-resultset iteration,
and type serialization for JSON compliance.
"""

import os
import time
from datetime import date, datetime, time as dt_time
from decimal import Decimal
from typing import Any, Dict, List, Tuple
from urllib.parse import parse_qs, unquote, urlparse
import pyodbc
from dotenv import load_dotenv

load_dotenv()


class SQLClient:
    def __init__(self):
        self.database_url = os.getenv("SQL_SERVER_DATABASE_URL", "").strip().strip('"').strip("'")
        self.server = os.getenv("SQL_SERVER", "localhost")
        self.database = os.getenv("SQL_DATABASE", "")
        self.user = os.getenv("SQL_USER", "sa")
        self.password = os.getenv("SQL_PASSWORD", "")
        self.port = os.getenv("SQL_PORT", "1433")
        self.driver = os.getenv("SQL_DRIVER", "ODBC Driver 18 for SQL Server")
        self.trust_cert = os.getenv("SQL_TRUST_CERT", "yes")
        self.timeout = int(os.getenv("SQL_TIMEOUT", "30"))

    def get_connection_string(self) -> str:
        """
        Constructs an ODBC connection string for SQL Server.
        Prioritizes SQL_SERVER_DATABASE_URL if configured.
        """
        if self.database_url:
            return self._parse_database_url(self.database_url)

        # Fallback to individual environment parameters
        server_str = f"{self.server},{self.port}" if self.port and self.port != "1433" else self.server
        conn_parts = [
            f"DRIVER={{{self.driver}}}",
            f"SERVER={server_str}",
            f"DATABASE={self.database}",
            f"UID={self.user}",
            f"PWD={self.password}",
            f"TrustServerCertificate={self.trust_cert}",
            f"Connection Timeout={self.timeout}",
        ]
        return ";".join(conn_parts)

    def _parse_database_url(self, raw_url: str) -> str:
        """Parses mssql+pyodbc:// database URL into a native pyodbc ODBC connection string."""
        url = raw_url.strip().strip('"').strip("'")

        if "://" in url:
            _, rest = url.split("://", 1)
            parsed = urlparse("http://" + rest)
        else:
            parsed = urlparse("http://" + url)

        user = unquote(parsed.username) if parsed.username else self.user
        password = unquote(parsed.password) if parsed.password else self.password
        hostname = parsed.hostname or self.server
        port = parsed.port
        db_name = parsed.path.lstrip("/") if parsed.path else self.database

        server_str = f"{hostname},{port}" if port and port != 1433 else hostname

        # Parse query string parameters (driver, Encrypt, TrustServerCertificate)
        query_params = parse_qs(parsed.query)
        driver = query_params.get("driver", [self.driver])[0]
        encrypt = query_params.get("Encrypt", query_params.get("encrypt", ["yes"]))[0]
        trust_cert = query_params.get("TrustServerCertificate", query_params.get("trustservercertificate", [self.trust_cert]))[0]

        # Update instance properties for health reporting
        self.server = server_str
        self.database = db_name
        self.user = user
        self.driver = driver

        conn_parts = [
            f"DRIVER={{{driver}}}",
            f"SERVER={server_str}",
            f"DATABASE={db_name}",
            f"UID={user}",
            f"PWD={password}",
            f"Encrypt={encrypt}",
            f"TrustServerCertificate={trust_cert}",
            f"Connection Timeout={self.timeout}",
        ]
        return ";".join(conn_parts)

    def test_connection(self) -> Dict[str, Any]:
        """Tests SQL Server connectivity with a lightweight ping query."""
        start_time = time.time()
        conn_str = self.get_connection_string()
        try:
            with pyodbc.connect(conn_str, timeout=self.timeout) as conn:
                with conn.cursor() as cursor:
                    cursor.execute("SELECT 1 AS is_alive, @@VERSION AS version")
                    row = cursor.fetchone()
                    latency_ms = int((time.time() - start_time) * 1000)
                    return {
                        "connected": True,
                        "server": self.server,
                        "database": self.database,
                        "driver": self.driver,
                        "response_time_ms": latency_ms,
                        "version": row[1].split("\n")[0] if row else "Unknown",
                        "error": None
                    }
        except Exception as e:
            latency_ms = int((time.time() - start_time) * 1000)
            return {
                "connected": False,
                "server": self.server,
                "database": self.database,
                "driver": self.driver,
                "response_time_ms": latency_ms,
                "version": None,
                "error": str(e)
            }

    @staticmethod
    def _serialize_value(val: Any) -> Any:
        """Converts SQL data types into JSON-serializable Python primitives."""
        if val is None:
            return None
        if isinstance(val, (datetime, date, dt_time)):
            return val.isoformat()
        if isinstance(val, Decimal):
            # Convert decimal to float or int for clean JSON
            return int(val) if val % 1 == 0 else float(val)
        if isinstance(val, (bytes, bytearray)):
            return val.hex()
        return val

    def execute_query_multi_resultset(
        self,
        query: str,
        params: List[Any]
    ) -> Tuple[List[Dict[str, Any]], int]:
        """
        Executes a parameterized stored procedure or SQL query and captures all result sets.

        Returns:
            Tuple[List[TableDict], execution_time_ms]
            where each TableDict contains:
                - "table_index": int
                - "name": str
                - "columns": List[str]
                - "row_count": int
                - "rows": List[List[Any]]
        """
        conn_str = self.get_connection_string()
        start_time = time.time()
        tables = []
        table_idx = 0

        with pyodbc.connect(conn_str, timeout=self.timeout) as conn:
            with conn.cursor() as cursor:
                # Execute parameterized query
                if params:
                    cursor.execute(query, params)
                else:
                    cursor.execute(query)

                # Iterate through all returned result sets using cursor.nextset()
                while True:
                    if cursor.description is not None:
                        col_names = [col[0] for col in cursor.description]
                        raw_rows = cursor.fetchall()
                        serialized_rows = [
                            [self._serialize_value(item) for item in row]
                            for row in raw_rows
                        ]
                        tables.append({
                            "table_index": table_idx,
                            "name": f"ResultSet_{table_idx + 1}",
                            "columns": col_names,
                            "row_count": len(serialized_rows),
                            "rows": serialized_rows
                        })
                        table_idx += 1

                    # Check for subsequent result sets
                    try:
                        if not cursor.nextset():
                            break
                    except Exception:
                        # Some stored procedures throw on final nextset() when finished
                        break

        execution_time_ms = int((time.time() - start_time) * 1000)
        return tables, execution_time_ms


# Global singleton instance
sql_client = SQLClient()
