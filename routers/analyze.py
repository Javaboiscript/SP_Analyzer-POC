"""
Analyze router orchestrating parameterized stored procedure execution
using user arguments, followed by Gemini AI analysis using the selected prompt.
"""

import time
from typing import Any, Dict, List, Tuple
from fastapi import APIRouter, HTTPException, status
from ai.gemini_client import gemini_client
from db.sql_client import sql_client
from models.schemas import (
    AnalyzeRequest,
    AnalyzeResponse,
    ExecutionMetadata,
    TableResult,
)
from routers.tools import load_tools_config

router = APIRouter(prefix="/api", tags=["Analysis & Reasoning"])


def build_stored_procedure_call(
    tool: Dict[str, Any],
    user_args: Dict[str, Any]
) -> Tuple[str, List[Any], str]:
    """
    Constructs the parameterized stored procedure execution query and binds user arguments.
    Combines tool defaults with user-supplied arguments.
    """
    sp_name = tool.get("storedProcedure")
    if not sp_name:
        raise ValueError(f"No stored procedure defined for tool '{tool.get('id')}'.")

    param_defs = tool.get("params", [])
    param_values = []
    param_placeholders = []

    for p in param_defs:
        p_name = p.get("name")
        param_placeholders.append(f"@{p_name} = ?")

        if p_name in user_args:
            val = user_args[p_name]
            # Convert empty string, whitespace, or null to None (SQL NULL)
            if val is None or (isinstance(val, str) and val.strip() == ""):
                val = None
            elif p.get("type") in ("int", "select") and val is not None:
                try:
                    val = int(val)
                except (ValueError, TypeError):
                    pass
        else:
            # Not provided by user -> pass as None (SQL NULL)
            val = None

        param_values.append(val)

    if param_placeholders:
        query_str = f"EXEC {sp_name} " + ", ".join(param_placeholders)
    else:
        query_str = f"EXEC {sp_name}"

    return query_str, param_values, sp_name


@router.post(
    "/analyze",
    response_model=AnalyzeResponse,
    summary="Execute Stored Procedure with User Arguments & Analyze with AI Prompt",
    description="Executes the tool's stored procedure passing user arguments as SQL parameters, captures all result sets, and analyzes the data using the selected prompt."
)
def run_analysis(request: AnalyzeRequest) -> AnalyzeResponse:
    total_start = time.time()

    # 1. Load registry and validate tool & prompt
    tools_config = load_tools_config()
    tool_match = next((t for t in tools_config.get("tools", []) if t["id"] == request.toolId), None)
    if not tool_match:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tool with id '{request.toolId}' not found in tools.json."
        )

    is_custom_prompt = (request.promptId == "custom")
    prompt_match = None
    if not is_custom_prompt:
        prompt_match = next((p for p in tool_match.get("prompts", []) if p["id"] == request.promptId), None)
        if not prompt_match:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Prompt with id '{request.promptId}' not found for tool '{request.toolId}'."
            )

    # 2. Build the parameterized SP query with user arguments
    try:
        query_str, param_values, sp_name = build_stored_procedure_call(
            tool_match, request.params
        )
    except Exception as e:
        return AnalyzeResponse(
            success=False,
            error="Parameter resolution failed",
            detail=str(e)
        )

    # 3. Execute stored procedure on SQL Server
    try:
        raw_tables, sql_execution_ms = sql_client.execute_query_multi_resultset(
            query=query_str,
            params=param_values
        )
    except Exception as e:
        return AnalyzeResponse(
            success=False,
            error="Database query execution failed",
            detail=f"Error executing '{query_str}' with params {param_values}: {str(e)}"
        )

    # 3b. Automatically enrich table names if result set 0 contains metadata definitions
    if raw_tables and raw_tables[0].get("columns") and "ResultSetNo" in raw_tables[0]["columns"] and "Name" in raw_tables[0]["columns"]:
        cols = raw_tables[0]["columns"]
        r_idx = cols.index("ResultSetNo")
        n_idx = cols.index("Name")
        s_idx = cols.index("Section") if "Section" in cols else -1
        name_map = {}
        for row in raw_tables[0]["rows"]:
            # Only match rows that define result set names
            if s_idx != -1 and s_idx < len(row) and str(row[s_idx]).upper() != "RESULT_SET":
                continue
            if r_idx < len(row) and n_idx < len(row) and row[r_idx] is not None:
                try:
                    name_map[int(row[r_idx])] = str(row[n_idx])
                except (ValueError, TypeError):
                    pass
        for t in raw_tables:
            idx = t.get("table_index", 0)
            if idx in name_map:
                t["name"] = name_map[idx]

    total_rows = sum(t["row_count"] for t in raw_tables)

    # 4. Prepare metadata dictionary
    sp_metadata = {
        "tool_id": request.toolId,
        "prompt_id": request.promptId,
        "sp_executed": sp_name,
        "sql_execution_time_ms": sql_execution_ms,
        "total_rows": total_rows,
        "table_count": len(raw_tables)
    }

    # 5. Execute Gemini Analysis (Structured Schema for templates, Free-form Markdown for custom prompt)
    analysis_result = None
    raw_analysis_text = None
    ai_latency_ms = 0

    if is_custom_prompt:
        custom_query = (request.custom_input or "").strip()
        if not custom_query:
            custom_query = "Provide a comprehensive analytical summary and key observations from the returned stored procedure data."
        try:
            raw_analysis_text, ai_latency_ms = gemini_client.analyze_custom_data(
                tables=raw_tables,
                custom_prompt=custom_query,
                sp_metadata=sp_metadata
            )
            print("--------------")
            print(raw_analysis_text)
            print("--------------")
        except Exception as e:
            tables_result = [
                TableResult(
                    table_index=t["table_index"],
                    name=t["name"],
                    columns=t["columns"],
                    row_count=t["row_count"],
                    rows=t["rows"]
                )
                for t in raw_tables
            ]
            total_time_ms = int((time.time() - total_start) * 1000)
            return AnalyzeResponse(
                success=False,
                tables=tables_result,
                error="AI reasoning generation failed",
                detail=str(e),
                metadata=ExecutionMetadata(
                    tool_id=request.toolId,
                    prompt_id=request.promptId,
                    sp_executed=sp_name,
                    sql_execution_time_ms=sql_execution_ms,
                    ai_latency_ms=0,
                    total_execution_time_ms=total_time_ms,
                    table_count=len(raw_tables),
                    total_rows=total_rows,
                    model_used=gemini_client.default_model
                )
            )
    else:
        system_prompt = prompt_match.get("systemPrompt", "You are an expert enterprise data analyst.")
        user_prompt_template = prompt_match.get("userPromptTemplate", "Analyze the following data:\n\n{{data}}")

        try:
            analysis_result, ai_latency_ms = gemini_client.analyze_data(
                tables=raw_tables,
                system_prompt=system_prompt,
                user_prompt_template=user_prompt_template,
                sp_metadata=sp_metadata,
                custom_input=request.custom_input
            )
        except Exception as e:
            tables_result = [
                TableResult(
                    table_index=t["table_index"],
                    name=t["name"],
                    columns=t["columns"],
                    row_count=t["row_count"],
                    rows=t["rows"]
                )
                for t in raw_tables
            ]
            total_time_ms = int((time.time() - total_start) * 1000)
            return AnalyzeResponse(
                success=False,
                tables=tables_result,
                error="AI reasoning generation failed",
                detail=str(e),
                metadata=ExecutionMetadata(
                    tool_id=request.toolId,
                    prompt_id=request.promptId,
                    sp_executed=sp_name,
                    sql_execution_time_ms=sql_execution_ms,
                    ai_latency_ms=0,
                    total_execution_time_ms=total_time_ms,
                    table_count=len(raw_tables),
                    total_rows=total_rows,
                    model_used=gemini_client.default_model
                )
            )

    total_time_ms = int((time.time() - total_start) * 1000)

    # 6. Return raw SQL tables along with either structured analysis or raw analysis
    tables_result = [
        TableResult(
            table_index=t["table_index"],
            name=t["name"],
            columns=t["columns"],
            row_count=t["row_count"],
            rows=t["rows"]
        )
        for t in raw_tables
    ]

    metadata_result = ExecutionMetadata(
        tool_id=request.toolId,
        prompt_id=request.promptId,
        sp_executed=sp_name,
        sql_execution_time_ms=sql_execution_ms,
        ai_latency_ms=ai_latency_ms,
        total_execution_time_ms=total_time_ms,
        table_count=len(raw_tables),
        total_rows=total_rows,
        model_used=gemini_client.default_model
    )

    return AnalyzeResponse(
        success=True,
        analysis=analysis_result,
        raw_analysis=raw_analysis_text,
        tables=tables_result,
        metadata=metadata_result
    )
