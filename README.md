# 🛡️ NetGuard AI

**AI-powered Network & System Incident Response Copilot**

NetGuard AI analyzes network logs, system logs, security alerts, and error messages to help users quickly understand incidents and determine the appropriate response.

Built for the **Nebius x NVIDIA Global AI Hackathon**.

---

## 🚀 What NetGuard AI Does

NetGuard AI allows a user to paste a network or system log and automatically generates:

- Incident severity: LOW, MEDIUM, or HIGH
- Incident summary
- Likely root cause
- Evidence found in the submitted log
- Recommended remediation actions

Example input:

```text
Sep 15 01:20:01 gateway sshd[9001]: Failed password for admin from 203.0.113.25
Sep 15 01:20:03 gateway sshd[9002]: Failed password for admin from 203.0.113.25
Sep 15 01:20:05 gateway sshd[9003]: Failed password for root from 203.0.113.25