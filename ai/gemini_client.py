"""
Gemini AI Client using the official google-genai SDK.
Handles prompt construction, table formatting with a 500-row safety threshold and column statistics,
and structured Pydantic JSON output generation.
"""

import os
import time
from typing import Any, Dict, List, Tuple
from dotenv import load_dotenv
from google import genai
from google.genai import types
from models.schemas import AIAnalysisResult

load_dotenv()


class GeminiClient:
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY", "")
        self.default_model = os.getenv("GEMINI_MODEL", "gemini-3.1-flash")
        raw_max_rows = os.getenv("MAX_PROMPT_ROWS", "").strip()
        try:
            val = int(raw_max_rows)
            # 0 or negative means unlimited (no cap)
            self.max_prompt_rows = val if val > 0 else None
        except (ValueError, TypeError):
            self.max_prompt_rows = None
        self._client = None

    @property
    def client(self) -> genai.Client:
        if self._client is None:
            if not self.api_key:
                raise ValueError("GEMINI_API_KEY environment variable is not set. Please update your .env file.")
            self._client = genai.Client(api_key=self.api_key)
        return self._client

    @staticmethod
    def _is_numeric(val: Any) -> bool:
        return isinstance(val, (int, float)) and not isinstance(val, bool)

    def format_tables_for_prompt(self, tables: List[Dict[str, Any]]) -> str:
        """
        Converts multi-resultset SQL tables into a clean, compact Markdown tabular format for LLM reasoning.
        If self.max_prompt_rows is set (> 0) and any table exceeds it, it truncates the preview to max_prompt_rows and
        calculates complete column-level statistics (totals, averages, min, max) for numeric columns.
        If max_prompt_rows is None (0 or empty in env), all rows are included without capping.
        """
        if not tables:
            return "No data returned by the query."

        output_parts = []

        for table in tables:
            name = table.get("name", "Table")
            columns = table.get("columns", [])
            rows = table.get("rows", [])
            total_rows = len(rows)

            output_parts.append(f"### Result Table: {name} ({total_rows} total rows)")

            if total_rows == 0:
                output_parts.append("_Empty result set (0 rows)._\n")
                continue

            # Compute column statistics if rows are capped
            is_truncated = bool(self.max_prompt_rows and total_rows > self.max_prompt_rows)
            display_rows = rows[:self.max_prompt_rows] if is_truncated else rows

            if is_truncated:
                output_parts.append(
                    f"> **Notice**: Showing top {self.max_prompt_rows} rows out of {total_rows} total rows. "
                    "Complete statistical aggregates across all rows are provided below:"
                )

                # Compute aggregates across ALL rows for numeric columns
                stats_rows = []
                for col_idx, col_name in enumerate(columns):
                    numeric_vals = [
                        row[col_idx] for row in rows
                        if col_idx < len(row) and self._is_numeric(row[col_idx])
                    ]
                    if len(numeric_vals) > total_rows * 0.5:  # predominantly numeric
                        total_sum = sum(numeric_vals)
                        avg_val = total_sum / len(numeric_vals) if numeric_vals else 0
                        min_val = min(numeric_vals) if numeric_vals else 0
                        max_val = max(numeric_vals) if numeric_vals else 0

                        stats_rows.append(
                            f"| `{col_name}` | {total_sum:,.2f} | {avg_val:,.2f} | {min_val:,.2f} | {max_val:,.2f} |"
                        )

                if stats_rows:
                    output_parts.append(
                        "\n| Column Name | Aggregate Sum | Average | Min | Max |\n"
                        "|:---|---:|---:|---:|---:|\n" +
                        "\n".join(stats_rows) + "\n"
                    )

            # Build Markdown table for preview rows
            # Header
            header_line = "| " + " | ".join(columns) + " |"
            separator_line = "| " + " | ".join(["---"] * len(columns)) + " |"
            table_lines = [header_line, separator_line]

            # Rows
            for row in display_rows:
                row_str = "| " + " | ".join(
                    str(val).replace("|", "\\|").replace("\n", " ") if val is not None else ""
                    for val in row
                ) + " |"
                table_lines.append(row_str)

            output_parts.append("\n".join(table_lines) + "\n")

        return "\n\n".join(output_parts)

    def analyze_data(
        self,
        tables: List[Dict[str, Any]],
        system_prompt: str,
        user_prompt_template: str,
        sp_metadata: Dict[str, Any],
        custom_input: str = None,
        model: str = None
    ) -> Tuple[AIAnalysisResult, int]:
        """
        Assembles the prompt with formatted tabular data and invokes Gemini with Pydantic JSON schema enforcement.

        Returns:
            Tuple[AIAnalysisResult, ai_latency_ms]
        """
        chosen_model = model or self.default_model
        start_time = time.time()

        # Format tabular data
        formatted_data = self.format_tables_for_prompt(tables)

        # Build context notes from metadata
        metadata_context = (
            f"\n[Execution Metadata]: Stored Procedure '{sp_metadata.get('sp_executed')}' "
            f"returned {sp_metadata.get('table_count', 1)} table(s) with {sp_metadata.get('total_rows', 0)} total row(s)."
        )

        # Interpolate user prompt template
        if "{{data}}" in user_prompt_template:
            final_user_content = user_prompt_template.replace("{{data}}", formatted_data + metadata_context)
        else:
            final_user_content = f"{user_prompt_template}\n\n--- DATA ---\n{formatted_data}\n{metadata_context}"

        # Append user custom instructions / questions if provided
        if custom_input and custom_input.strip():
            final_user_content += (
                f"\n\n--- USER CUSTOM INQUIRIES & DIRECTIVES ---\n"
                f"{custom_input.strip()}\n\n"
                f"[Guidance for User Inquiry]: Directly address the user's custom question or directives above, and populate the 'custom_response' field in your structured JSON output with a clear, concise answer."
            )

        # Call Gemini using google-genai SDK
        response = self.client.models.generate_content(
            model=chosen_model,
            contents=final_user_content,
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                response_mime_type="application/json",
                response_schema=AIAnalysisResult,
                temperature=0.2,
            )
        )

        ai_latency_ms = int((time.time() - start_time) * 1000)

        # Parse structured output into Pydantic model
        if hasattr(response, "parsed") and response.parsed is not None:
            analysis_result = response.parsed
        else:
            analysis_result = AIAnalysisResult.model_validate_json(response.text)

        return analysis_result, ai_latency_ms

    def analyze_custom_data(
        self,
        tables: List[Dict[str, Any]],
        custom_prompt: str,
        sp_metadata: Dict[str, Any],
        system_prompt: str = None,
        model: str = None
    ) -> Tuple[str, int]:
        """
        Assembles prompt with formatted tabular data and invokes Gemini in free-form (unconstrained) mode.
        No Pydantic schema is enforced; Gemini generates natural language / Markdown directly.

        Returns:
            Tuple[raw_text_response, ai_latency_ms]
        """
        chosen_model = model or self.default_model
        start_time = time.time()

        # Format tabular data
        formatted_data = self.format_tables_for_prompt(tables)

        # Build context notes from metadata
        metadata_context = (
            f"\n[Execution Metadata]: Stored Procedure '{sp_metadata.get('sp_executed')}' "
            f"returned {sp_metadata.get('table_count', 1)} table(s) with {sp_metadata.get('total_rows', 0)} total row(s)."
        )

        sys_prompt = system_prompt or (
            "You are an expert enterprise business intelligence and data analyst.\n"
            "Analyze the provided stored procedure tabular data and directly answer the user's inquiry.\n\n"
            "FORMATTING GUIDELINES:\n"
            "- MAXIMIZE TABLES: Use clean Markdown tables wherever possible to present numbers, comparisons, and item breakdowns.\n"
            "- BOLD TITLES & SPACING: Use bold Markdown section headers (###) with generous vertical spacing.\n"
            "- BULLET POINTS: Use crisp bullet points with bold headline prefixes for observations and recommendations—avoid text blobs."
        )

        if "{{data}}" in custom_prompt:
            final_user_content = custom_prompt.replace("{{data}}", formatted_data + metadata_context)
        else:
            final_user_content = f"{custom_prompt}\n\n--- STORED PROCEDURE DATA ---\n{formatted_data}\n{metadata_context}"

        # Call Gemini in free-form mode (no response_schema, no JSON enforcement)
        response = self.client.models.generate_content(
            model=chosen_model,
            contents=final_user_content,
            config=types.GenerateContentConfig(
                system_instruction=sys_prompt,
                temperature=0.2,
            )
        )

        ai_latency_ms = int((time.time() - start_time) * 1000)
        return response.text or "", ai_latency_ms


# Global singleton instance
gemini_client = GeminiClient()
