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

        val = user_args.get(p_name)
        # If not provided or empty string/whitespace, fall back to configured default if available
        if val is None or (isinstance(val, str) and val.strip() == ""):
            val = p.get("default")

        # Convert empty string/whitespace or None to SQL NULL
        if val is None or (isinstance(val, str) and val.strip() == ""):
            val = None
        elif p.get("type") in ("int", "select") and val is not None:
            try:
                val = int(val)
            except (ValueError, TypeError):
                pass

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

    print("\n" + "=" * 75, flush=True)
    print("--> [REQUEST RECEIVED] POST /api/analyze", flush=True)
    print(f"   - Tool ID: {request.toolId} | Report: {request.reportId or 'N/A'} | Prompt ID: {request.promptId}", flush=True)
    print(f"   - SP Parameters: {request.params}", flush=True)
    if request.custom_input:
        preview = request.custom_input.strip()[:90] + ("..." if len(request.custom_input.strip()) > 90 else "")
        print(f"   - Custom Input: \"{preview}\"", flush=True)
    print("-" * 75, flush=True)

    # 1. Load registry and validate tool & prompt
    print("[STEP 1/5] Resolving Tool & Report Specification...", flush=True)
    tools_config = load_tools_config()
    tool_match = next((t for t in tools_config.get("tools", []) if t["id"] == request.toolId), None)
    if not tool_match:
        print(f"   [ERROR] Tool '{request.toolId}' not found in registry.", flush=True)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tool with id '{request.toolId}' not found in tools.json."
        )

    # Check if tool defines multiple reports (e.g. report_analyzer)
    is_multi_report = bool(tool_match.get("reports"))
    active_spec = tool_match
    if is_multi_report:
        reports = tool_match.get("reports", [])
        if request.reportId:
            report_match = next((r for r in reports if r["id"] == request.reportId), None)
            if not report_match:
                print(f"   [ERROR] Report '{request.reportId}' not found for tool '{request.toolId}'.", flush=True)
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Report with id '{request.reportId}' not found for tool '{request.toolId}'."
                )
            active_spec = report_match
        elif reports:
            active_spec = reports[0]

    is_custom_prompt = (request.promptId == "custom" or is_multi_report)
    prompt_match = None
    if not is_custom_prompt:
        prompt_match = next((p for p in tool_match.get("prompts", []) if p["id"] == request.promptId), None)
        if not prompt_match:
            print(f"   [ERROR] Prompt '{request.promptId}' not found for tool '{request.toolId}'.", flush=True)
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Prompt with id '{request.promptId}' not found for tool '{request.toolId}'."
            )

    print(f"   [OK] Active Tool: '{tool_match.get('label')}' | Report: '{active_spec.get('label')}'", flush=True)

    # 2. Build the parameterized SP query with user arguments using active_spec
    print("[STEP 2/5] Building Parameterized SQL Call...", flush=True)
    try:
        query_str, param_values, sp_name = build_stored_procedure_call(
            active_spec, request.params
        )
        print(f"   [OK] Target Stored Procedure: {sp_name}", flush=True)
        print(f"   [OK] Constructed Query: {query_str}", flush=True)
        print(f"   [OK] Bound Parameter Values: {param_values}", flush=True)
    except Exception as e:
        print(f"   [ERROR] Parameter resolution failed: {str(e)}", flush=True)
        return AnalyzeResponse(
            success=False,
            error="Parameter resolution failed",
            detail=str(e)
        )

    # 3. Execute stored procedure on SQL Server
    print("[STEP 3/5] Executing Stored Procedure on SQL Server...", flush=True)
    try:
        raw_tables, sql_execution_ms = sql_client.execute_query_multi_resultset(
            query=query_str,
            params=param_values
        )
    except Exception as e:
        print(f"   [ERROR] Database execution failed in {int((time.time() - total_start)*1000)}ms: {str(e)}", flush=True)
        return AnalyzeResponse(
            success=False,
            error="Database query execution failed",
            detail=f"Error executing '{query_str}' with params {param_values}: {str(e)}"
        )

    # 3b. Automatically enrich table names from tool/report configuration and SP metadata
    configured_names = active_spec.get("tableNames") or tool_match.get("tableNames") or []
    for idx, t in enumerate(raw_tables):
        if idx < len(configured_names) and configured_names[idx]:
            t["name"] = configured_names[idx]

    if raw_tables and raw_tables[0].get("columns") and "ResultSetNo" in raw_tables[0]["columns"] and "Name" in raw_tables[0]["columns"]:
        cols = raw_tables[0]["columns"]
        r_idx = cols.index("ResultSetNo")
        n_idx = cols.index("Name")
        s_idx = cols.index("Section") if "Section" in cols else -1
        name_map = {}
        for row in raw_tables[0]["rows"]:
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
    print(f"   [OK] SQL Query Succeeded in {sql_execution_ms}ms: {len(raw_tables)} table(s) returned, {total_rows} total row(s)", flush=True)

    # 4. Prepare metadata dictionary
    sp_metadata = {
        "tool_id": request.toolId,
        "report_id": request.reportId or (active_spec.get("id") if is_multi_report else None),
        "prompt_id": request.promptId,
        "sp_executed": sp_name,
        "sql_execution_time_ms": sql_execution_ms,
        "total_rows": total_rows,
        "table_count": len(raw_tables)
    }

    # 5. Execute Gemini AI Analysis
    mode_desc = "Unconstrained Free-form Markdown" if is_custom_prompt else f"Structured Schema ({prompt_match.get('id')})"
    print(f"[STEP 4/5] Synthesizing Insights with Gemini AI ({gemini_client.default_model})...", flush=True)
    print(f"   [OK] Reasoning Mode: {mode_desc}", flush=True)

    analysis_result = None
    raw_analysis_text = None
    ai_latency_ms = 0

    if is_custom_prompt:
        custom_query = (request.custom_input or "").strip()
        if not custom_query:
            if is_multi_report:
                custom_query = (
                    f"Provide an executive operational summary, key numerical highlights, and any anomalies "
                    f"from the returned '{active_spec.get('label', sp_name)}' report data."
                )
        report_label = active_spec.get("label", sp_name)
        report_overview = active_spec.get("overview") or active_spec.get("description", "Enterprise business data.")

        if is_multi_report:
            system_instruction = (
                "You are an expert enterprise business intelligence and data analyst.\n\n"
                f"Scope of this Report:\n"
                f"- Report: {report_label}\n"
                f"- Overview: {report_overview}\n\n"
                "CRITICAL FORMATTING & PRESENTATION GUIDELINES (STRICTLY REQUIRED):\n"
                "1. MAXIMIZE TABLES: Wherever possible, use clean, well-structured Markdown tables to present numbers, comparative figures, item summaries, customer breakdowns, tax totals, and status matrices. Markdown tables render beautifully in the UI and provide the highest clarity.\n"
                "2. BOLD TITLES & SPACED SECTIONS: Use bold Markdown headings with icons (e.g. '### 📊 Executive Summary', '### 🔢 Key Metrics & Numerical Totals', '### 📋 Data Breakdown Table', '### ⚠️ Operational Highlights', '### 🎯 Actionable Recommendations') with generous line spacing between sections for clean visual appeal.\n"
                "3. BULLET POINTS WITH BOLD LEAD-INS: Use crisp bullet points with bold headline prefixes (e.g. '- **Total Turnover**: ₹4,82,31,000 across 237 billed invoices.') for all observations, anomalies, and recommendations. Keep each point short, concise, and scannable.\n"
                "4. NO TEXT BLOBS: Absolutely avoid dense narrative paragraphs or walls of text. Every point must be concise, scannable, and distinct.\n"
                "5. ANALYZE ACTUAL ROWS: Focus directly on analyzing the actual data rows—extracting totals, quantities, values, patterns, anomalies, delays, and operational discrepancies.\n"
                "6. LANGUAGE MATCHING: Detect the language or dialect used in the user's question or input (English, Hinglish) and reply in that same style while strictly maintaining the rich table and bullet formatting."
            )
        else:
            system_instruction = (
                "You are an expert enterprise business intelligence and data analyst.\n\n"
                f"Scope:\n"
                "- Overview: Purchase Order Lifecycle Intelligence (evaluating vendor fulfillment, delivery delays, gate-to-GRN lag, inspection rejections, and open balance exposure).\n\n"
                "CRITICAL FORMATTING GUIDELINES (STRICTLY REQUIRED):\n"
                "1. MAXIMIZE TABLES: Wherever possible, use clean Markdown tables to present comparisons, metrics, line items, and schedule statuses.\n"
                "2. BOLD TITLES & SPACING: Use bold Markdown headings (###) with generous line spacing between sections.\n"
                "3. BULLET POINTS: Use crisp bullet points with bold headline prefixes for all findings, risks, and recommendations—never output dense text blobs. Keep points short and readable.\n"
                "4. LANGUAGE MATCHING: Detect the language or dialect used in the user's question or input (English, Hinglish) and reply in that same style while strictly using rich table and bullet formatting."
            )

        try:
            raw_analysis_text, ai_latency_ms = gemini_client.analyze_custom_data(
                tables=raw_tables,
                custom_prompt=custom_query,
                sp_metadata=sp_metadata,
                system_prompt=system_instruction
            )
            print(f"   [OK] AI Reasoning Complete in {ai_latency_ms}ms ({len(raw_analysis_text)} chars generated)", flush=True)
        except Exception as e:
            print(f"   [ERROR] AI Generation Failed: {str(e)}", flush=True)
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
            print(f"   [OK] AI Reasoning Complete in {ai_latency_ms}ms (Structured schema parsed)", flush=True)
        except Exception as e:
            print(f"   [ERROR] AI Generation Failed: {str(e)}", flush=True)
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
    print(f"[STEP 5/5] Packaging & Dispatching Response...", flush=True)
    print(f"   [OK] Success! Total Execution Time: {total_time_ms}ms (SQL: {sql_execution_ms}ms | AI: {ai_latency_ms}ms)", flush=True)
    print("=" * 75 + "\n", flush=True)

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

