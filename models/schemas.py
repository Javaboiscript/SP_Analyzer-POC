"""
Pydantic schemas for the Analyzer POC API and Gemini structured outputs.
"""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


# ---------------------------------------------------------
# Request Models
# ---------------------------------------------------------

class AnalyzeRequest(BaseModel):
    toolId: str = Field(
        ...,
        description="Identifier of the tool to execute (e.g. 'po_analyzer')",
        json_schema_extra={"example": "po_analyzer"}
    )
    promptId: str = Field(
        ...,
        description="Identifier of the analytical prompt (e.g. 'po_lifecycle_health_audit')",
        json_schema_extra={"example": "po_lifecycle_health_audit"}
    )
    params: Dict[str, Any] = Field(
        default_factory=dict,
        description="Parameters passed to the underlying stored procedure",
        json_schema_extra={
            "example": {
                "PONo": 1644,
                "CompanyNo": 4
            }
        }
    )
    custom_input: Optional[str] = Field(
        None,
        description="Optional custom query, notes, or specific analytical focus instructions from the user",
        json_schema_extra={"example": "Focus on reasons for item rejection or payment clearance status"}
    )


# ---------------------------------------------------------
# AI Structured Output Models (Enforced on Gemini responses)
# ---------------------------------------------------------

class KeyMetric(BaseModel):
    label: str = Field(..., description="Name or description of the metric (e.g., 'Total Net Revenue', 'CGST Total')")
    value: str = Field(..., description="Formatted string value (e.g., '₹4,82,31,000' or '14.2%')")
    trend: Optional[str] = Field(None, description="Trend or benchmark indicator (e.g., '+12.5% YoY', 'Within normal threshold')")


class Finding(BaseModel):
    title: str = Field(..., description="Concise headline of the finding or observation")
    description: str = Field(..., description="Detailed explanation of what the data shows")
    severity: str = Field(..., description="Severity level: 'info', 'warning', or 'critical'")


class Recommendation(BaseModel):
    action: str = Field(..., description="Specific operational or strategic action to take")
    expected_impact: str = Field(..., description="Anticipated business or financial benefit")
    priority: str = Field(..., description="Urgency of the action: 'high', 'medium', or 'low'")


class AnalysisBreakdownRow(BaseModel):
    item_or_category: str = Field(..., description="Item name/description, document ID, or line reference (e.g. '1 LTR CANE EN8D' or 'GRN #1817')")
    col1_label: str = Field(..., description="Short header label for metric 1 (e.g. 'Ordered Qty', 'Min Schedule Date', 'Challan Qty', 'PO Value')")
    col1_value: str = Field(..., description="Value for metric 1 (e.g. '12,000 NOS', '2022-12-10', '₹6,00,000')")
    col2_label: str = Field(..., description="Short header label for metric 2 (e.g. 'Received Qty', 'Receipt Date', 'Accepted Qty', 'GRN Accepted')")
    col2_value: str = Field(..., description="Value for metric 2 (e.g. '12,000 NOS', '2022-11-01', '₹6,00,000')")
    col3_label: str = Field(..., description="Short header label for metric 3 (e.g. 'Balance Qty', 'Delay Days', 'Rejected Qty', 'Billed Amount')")
    col3_value: str = Field(..., description="Value for metric 3 (e.g. '0 NOS', '0 Days', '₹0')")
    status_tag: Optional[str] = Field(None, description="Concise status or flag: 'COMPLETED', 'OVERDUE', 'PENDING_BILLING', 'REJECTED', 'MATCHED', 'ON_TIME', etc.")


class AIAnalysisResult(BaseModel):
    executive_summary: str = Field(
        ...,
        description="Concise executive briefing in 2 to 3 structured highlight points. Focus on business impact so executives don't need to read walls of text."
    )
    key_metrics: List[KeyMetric] = Field(
        default_factory=list,
        description="Top 3 to 5 key numerical figures and calculated KPIs extracted from the data"
    )
    breakdown_table: List[AnalysisBreakdownRow] = Field(
        default_factory=list,
        description="Structured line-level or comparative breakdown matrix tailored to the selected prompt template."
    )
    findings: List[Finding] = Field(
        default_factory=list,
        description="Detailed observations, anomalies, compliance items, or risks identified"
    )
    recommendations: List[Recommendation] = Field(
        default_factory=list,
        description="Prioritized, actionable business recommendations"
    )
    additional_notes: Optional[str] = Field(
        None,
        description="Optional supplementary notes, audit disclaimers, or data limitation observations"
    )
    custom_response: Optional[str] = Field(
        None,
        description="Direct answer or targeted analytical assessment addressing the user's custom inquiries or instructions if provided."
    )


# ---------------------------------------------------------
# SQL Table & Metadata Models
# ---------------------------------------------------------

class TableResult(BaseModel):
    table_index: int = Field(..., description="0-indexed position of the result set")
    name: str = Field(..., description="Descriptive identifier for the table")
    columns: List[str] = Field(..., description="List of column header names")
    row_count: int = Field(..., description="Total rows in this result table")
    rows: List[List[Any]] = Field(..., description="Row data as list of lists (JSON-serializable)")


class ExecutionMetadata(BaseModel):
    tool_id: str
    prompt_id: str
    sp_executed: str
    sql_execution_time_ms: int
    ai_latency_ms: int
    total_execution_time_ms: int
    table_count: int
    total_rows: int
    model_used: str


# ---------------------------------------------------------
# API Response Models
# ---------------------------------------------------------

class AnalyzeResponse(BaseModel):
    success: bool
    analysis: Optional[AIAnalysisResult] = None
    raw_analysis: Optional[str] = Field(
        None,
        description="Raw, unstructured Markdown response from Gemini when a custom prompt is executed without schema enforcement."
    )
    tables: Optional[List[TableResult]] = None
    metadata: Optional[ExecutionMetadata] = None
    error: Optional[str] = None
    detail: Optional[str] = None


class HealthResponse(BaseModel):
    status: str
    database_connected: bool
    server: str
    database: str
    driver: str
    response_time_ms: int
    error: Optional[str] = None
