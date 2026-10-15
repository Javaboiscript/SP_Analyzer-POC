"""
Health check router to verify SQL Server connectivity and driver status.
"""

from fastapi import APIRouter
from db.sql_client import sql_client
from models.schemas import HealthResponse

router = APIRouter(prefix="/api", tags=["System & Health"])


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Check SQL Server Database Health",
    description="Executes a lightweight query against Microsoft SQL Server to verify connection string, credentials, and ODBC Driver status."
)
def get_health() -> HealthResponse:
    result = sql_client.test_connection()
    status_str = "healthy" if result["connected"] else "unhealthy"

    return HealthResponse(
        status=status_str,
        database_connected=result["connected"],
        server=result["server"],
        database=result["database"],
        driver=result["driver"],
        response_time_ms=result["response_time_ms"],
        error=result["error"]
    )
