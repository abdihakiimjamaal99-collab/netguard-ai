from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.models import AnalyzeRequest
from backend.ai_service import analyze_log

app = FastAPI(
    title="NetGuard AI API",
    version="0.1.0",
    description="AI-powered network and system incident-response copilot."
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {
        "name": "NetGuard AI",
        "status": "running"
    }


@app.get("/health")
def health():
    return {
        "status": "ok"
    }


@app.post("/analyze")
def analyze(request: AnalyzeRequest):
    try:
        result = analyze_log(request.log_text)

        print("ANALYZE RESULT:", result)

        return result

    except Exception as e:
        print("ANALYZE ERROR:", repr(e))

        return {
            "severity": "medium",
            "summary": "NetGuard AI detected an incident but the AI analysis service encountered an error.",
            "likely_cause": "The external AI service could not complete the analysis.",
            "evidence": [
                request.log_text
            ],
            "recommendations": [
                "Review the submitted log.",
                "Check network connectivity.",
                "Verify API credentials and model configuration.",
                "Review the backend terminal for additional details."
            ]
        }