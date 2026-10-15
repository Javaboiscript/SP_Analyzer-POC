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


class AIAnalysisResult(BaseModel):
    executive_summary: str = Field(
        ...,
        description="High-level narrative briefing covering the key insights and conclusions"
    )
    key_metrics: List[KeyMetric] = Field(
        default_factory=list,
        description="Key numerical figures and calculated KPIs extracted from the data"
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
