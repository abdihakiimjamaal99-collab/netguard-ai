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