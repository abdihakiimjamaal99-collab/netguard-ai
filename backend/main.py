from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.models import AnalyzeRequest, AnalyzeResponse
from backend.ai_service import analyze_log


app = FastAPI(
    title="NetGuard AI API",
    description="AI-powered network and system incident-response copilot.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {
        "name": "NetGuard AI",
        "status": "running",
    }


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(request: AnalyzeRequest):
    return analyze_log(request.log_text)