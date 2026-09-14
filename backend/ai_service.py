def analyze_log(log_text: str) -> dict:
    text = log_text.lower()

    severity = "low"
    likely_cause = "No obvious critical issue detected."
    evidence = []
    recommendations = [
        "Review the complete log around the reported event.",
        "Verify the affected service or device status.",
    ]

    critical_words = ["critical", "fatal", "kernel panic", "data loss"]
    high_words = ["unauthorized", "authentication failed", "connection refused"]
    medium_words = ["error", "timeout", "failed", "unreachable"]
    warning_words = ["warning", "retry", "slow"]

    for word in critical_words:
        if word in text:
            severity = "critical"
            evidence.append(f"Detected critical indicator: {word}")

    if severity != "critical":
        for word in high_words:
            if word in text:
                severity = "high"
                evidence.append(f"Detected high-risk indicator: {word}")

    if severity == "low":
        for word in medium_words:
            if word in text:
                severity = "medium"
                evidence.append(f"Detected issue indicator: {word}")

    if severity == "low":
        for word in warning_words:
            if word in text:
                severity = "low"
                evidence.append(f"Detected warning indicator: {word}")

    if "timeout" in text:
        likely_cause = (
            "A service or network connection may be unavailable, slow, "
            "or blocked."
        )
        recommendations.extend([
            "Check connectivity to the destination host.",
            "Verify DNS, firewall, routing, and service availability.",
        ])

    elif "authentication failed" in text or "unauthorized" in text:
        likely_cause = "An authentication or authorization problem is likely."
        recommendations.extend([
            "Verify the username, credentials, token, or permissions.",
            "Check for repeated failed login attempts.",
        ])

    elif "connection refused" in text:
        likely_cause = (
            "The target host responded, but the requested service "
            "is probably not listening."
        )
        recommendations.extend([
            "Confirm the application or service is running.",
            "Verify the destination port and firewall rules.",
        ])

    elif "error" in text or "failed" in text:
        likely_cause = "The logs contain an application or system failure."
        recommendations.extend([
            "Inspect the lines immediately before and after the failure.",
            "Check the affected application's configuration and dependencies.",
        ])

    if not evidence:
        evidence.append("No high-confidence error keyword was detected.")

    return {
        "severity": severity,
        "summary": (
            f"NetGuard AI analyzed the submitted log and classified "
            f"the incident as {severity.upper()} severity."
        ),
        "likely_cause": likely_cause,
        "evidence": evidence,
        "recommendations": recommendations,
    }

import json
import os

from dotenv import load_dotenv
from openai import OpenAI


load_dotenv()

NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY")
NVIDIA_MODEL = os.getenv(
    "NVIDIA_MODEL",
    "nvidia/nemotron-3.5-lightning-30b-a3b",
)
NVIDIA_BASE_URL = os.getenv(
    "NVIDIA_BASE_URL",
    "https://integrate.api.nvidia.com/v1",
)


def get_client():
    if not NVIDIA_API_KEY:
        raise RuntimeError(
            "NVIDIA_API_KEY was not found. "
            "Add it to the .env file and restart the backend."
        )

    return OpenAI(
        api_key=NVIDIA_API_KEY,
        base_url=NVIDIA_BASE_URL,
    )


def extract_json(content: str) -> dict:
    content = content.strip()

    if content.startswith("```"):
        content = content.replace("```json", "").replace("```", "").strip()

    start = content.find("{")
    end = content.rfind("}")

    if start == -1 or end == -1:
        raise ValueError("The AI response did not contain valid JSON.")

    return json.loads(content[start:end + 1])


def analyze_log(log_text: str) -> dict:
    client = get_client()

    system_prompt = """
You are NetGuard AI, an expert network and system incident-response copilot.

Analyze the submitted technical log carefully.

Return ONLY valid JSON using exactly this structure:

{
  "severity": "low",
  "summary": "short incident summary",
  "likely_cause": "most likely technical root cause",
  "evidence": [
    "specific evidence from the submitted log"
  ],
  "recommendations": [
    "safe troubleshooting action"
  ]
}

Rules:
- severity must be exactly one of:
  low, medium, high, critical
- Base conclusions on evidence in the submitted log.
- Do not invent IP addresses, services, errors, or events.
- Clearly distinguish symptoms from likely root causes.
- Recommendations must be safe and practical.
- Do not return markdown.
- Do not return text before or after the JSON.
"""

    response = client.chat.completions.create(
        model=NVIDIA_MODEL,
        messages=[
            {
                "role": "system",
                "content": system_prompt,
            },
            {
                "role": "user",
                "content": f"Analyze this log:\n\n{log_text}",
            },
        ],
        temperature=0.2,
        max_tokens=1200,
        extra_body={
            "chat_template_kwargs": {
                "enable_thinking": False
            }
        },
    )

    content = response.choices[0].message.content

    if not content:
        raise RuntimeError("NVIDIA returned an empty response.")

    result = extract_json(content)

    allowed_severities = {"low", "medium", "high", "critical"}

    severity = str(result.get("severity", "medium")).lower()

    if severity not in allowed_severities:
        severity = "medium"

    evidence = result.get("evidence", [])
    recommendations = result.get("recommendations", [])

    if not isinstance(evidence, list):
        evidence = [str(evidence)]

    if not isinstance(recommendations, list):
        recommendations = [str(recommendations)]

    return {
        "severity": severity,
        "summary": str(
            result.get(
                "summary",
                "The incident was analyzed by NetGuard AI."
            )
        ),
        "likely_cause": str(
            result.get(
                "likely_cause",
                "The root cause could not be determined with confidence."
            )
        ),
        "evidence": [str(item) for item in evidence],
        "recommendations": [
            str(item) for item in recommendations
        ],
    }