const API_URL = "http://127.0.0.1:8000/analyze";

const analyzeButton = document.getElementById("analyzeButton");
const logInput = document.getElementById("logInput");
const statusText = document.getElementById("status");
const results = document.getElementById("results");

analyzeButton.addEventListener("click", analyzeIncident);

async function analyzeIncident() {

    const logText = logInput.value.trim();

    if (!logText) {
        statusText.textContent = "Please enter a network or system log first.";
        return;
    }

    analyzeButton.disabled = true;
    analyzeButton.textContent = "Analyzing...";
    statusText.textContent = "NetGuard AI is analyzing the incident...";

    try {

        const response = await fetch(API_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                log_text: logText
            })
        });

        if (!response.ok) {
            throw new Error(`Server returned ${response.status}`);
        }

        const data = await response.json();

        displayResults(data);

        statusText.textContent = "Analysis completed successfully.";

    } catch (error) {

        console.error(error);

        statusText.textContent =
            "Could not connect to NetGuard AI API. Make sure the backend server is running.";

    } finally {

        analyzeButton.disabled = false;
        analyzeButton.textContent = "Analyze Incident";
    }
}

function displayResults(data) {

    results.classList.remove("hidden");

    document.getElementById("summary").textContent = data.summary;
    document.getElementById("likelyCause").textContent = data.likely_cause;

    const severityBadge = document.getElementById("severityBadge");

    severityBadge.textContent = data.severity;
    severityBadge.className = `severity-${data.severity}`;

    fillList("evidence", data.evidence);
    fillList("recommendations", data.recommendations);

    results.scrollIntoView({
        behavior: "smooth"
    });
}

function fillList(elementId, items) {

    const list = document.getElementById(elementId);

    list.innerHTML = "";

    items.forEach(item => {

        const li = document.createElement("li");

        li.textContent = item;

        list.appendChild(li);
    });
}