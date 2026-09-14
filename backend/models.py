from typing import Literal
from pydantic import BaseModel, Field


class AnalyzeRequest(BaseModel):
    log_text: str = Field(
        ...,
        min_length=3,
        max_length=20000,
        description="Network or system logs to analyze",
    )


class AnalyzeResponse(BaseModel):
    severity: Literal["low", "medium", "high", "critical"]
    summary: str
    likely_cause: str
    evidence: list[str]
    recommendations: list[str]