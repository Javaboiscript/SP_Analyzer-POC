/**
 * SINGLE-CANVAS AI STORED PROCEDURE ANALYZER
 * Client application orchestrating Tool Hub selection, parameter/prompt workspace,
 * multi-step navigation, and executive AI results visualization.
 */

// Application State
const state = {
  tools: [],
  selectedTool: null,
  selectedPrompt: null,
  currentAnalysis: null,
  currentTables: [],
  activeTableIndex: 0,
  tableFilterQuery: ""
};

// Preset examples for quick demonstration
const TOOL_PRESETS = {
  sales_analyzer: [
    {
      name: "Q1 2024 Audit",
      values: {
        CompanyNo: 1,
        FromDate: "2024-01-01",
        ToDate: "2024-03-31",
        CustomerLocationNo: 0,
        InvoiceType: 0,
        TaxBookNo: 0,
        IsMisReport: 0
      }
    },
    {
      name: "Tax Invoices (Jan 24)",
      values: {
        CompanyNo: 1,
        FromDate: "2024-01-01",
        ToDate: "2024-01-31",
        CustomerLocationNo: 0,
        InvoiceType: 1,
        TaxBookNo: 0,
        IsMisReport: 0
      }
    },
    {
      name: "Commercial Invoices",
      values: {
        CompanyNo: 1,
        FromDate: "2024-01-01",
        ToDate: "2024-03-31",
        CustomerLocationNo: 0,
        InvoiceType: 2,
        TaxBookNo: 0,
        IsMisReport: 0
      }
    }
  ],
  po_analyzer: [
    {
      name: "PO #1644 (Active Sample)",
      values: {
        PONo: 1644,
        CompanyNo: 4,
        PONoYearly: ""
      }
    },
    {
      name: "PO '0090/22-23' (Yearly Doc)",
      values: {
        PONo: "",
        PONoYearly: "0090/22-23",
        CompanyNo: 4
      }
    },
    {
      name: "PO #1640",
      values: {
        PONo: 1640,
        CompanyNo: 4,
        PONoYearly: ""
      }
    }
  ],
  indent_analyzer: [
    {
      name: "Company #1 Requisitions",
      values: {
        CompanyNo: 1
      }
    }
  ]
};

// DOM Elements
const el = {
  brandHomeLink: document.getElementById("brand-home-link"),
  btnHeaderBack: document.getElementById("btn-header-back"),
  headerActiveTool: document.getElementById("header-active-tool"),
  headerToolIcon: document.getElementById("header-tool-icon"),
  headerToolName: document.getElementById("header-tool-name"),
  dbStatusBadge: document.getElementById("db-status-badge"),
  dbStatusDot: document.getElementById("db-status-dot"),
  dbStatusText: document.getElementById("db-status-text"),
  
  // Views
  viewToolHub: document.getElementById("view-tool-hub"),
  toolsHubGrid: document.getElementById("tools-hub-grid"),
  viewToolWorkspace: document.getElementById("view-tool-workspace"),
  
  // Workspace Header
  wsToolIcon: document.getElementById("ws-tool-icon"),
  wsToolName: document.getElementById("ws-tool-name"),
  wsSpName: document.getElementById("ws-sp-name"),
  btnWsBack: document.getElementById("btn-ws-back"),
  
  // Workspace Setup
  btnResetParams: document.getElementById("btn-reset-params"),
  presetsContainer: document.getElementById("presets-container"),
  formFieldsContainer: document.getElementById("form-fields-container"),
  promptsCountBadge: document.getElementById("prompts-count-badge"),
  promptsListContainer: document.getElementById("prompts-list-container"),
  
  // Action Bar
  actionPromptName: document.getElementById("action-prompt-name"),
  btnRunAnalysis: document.getElementById("btn-run-analysis"),
  
  // Loading & Error
  loadingBox: document.getElementById("loading-box"),
  loadingStatusText: document.getElementById("loading-status-text"),
  errorBox: document.getElementById("error-box"),
  errorTitle: document.getElementById("error-title"),
  errorDetail: document.getElementById("error-detail"),
  
  // Results
  resultsSection: document.getElementById("results-section"),
  statSqlTime: document.getElementById("stat-sql-time"),
  statAiTime: document.getElementById("stat-ai-time"),
  statTotalRows: document.getElementById("stat-total-rows"),
  statTableCount: document.getElementById("stat-table-count"),
  btnCopyReport: document.getElementById("btn-copy-report"),
  btnScrollSql: document.getElementById("btn-scroll-sql"),
  executiveSummaryBlock: document.getElementById("executive-summary-block"),
  metricsDeck: document.getElementById("metrics-deck"),
  findingsCountPill: document.getElementById("findings-count-pill"),
  findingsList: document.getElementById("findings-list"),
  recsCountPill: document.getElementById("recs-count-pill"),
  recommendationsList: document.getElementById("recommendations-list"),
  supplementaryNotesContainer: document.getElementById("supplementary-notes-container"),
  supplementaryNotesText: document.getElementById("supplementary-notes-text"),
  
  // SQL Tables
  sqlTablesSection: document.getElementById("sql-tables-section"),
  resultSetsBadge: document.getElementById("result-sets-badge"),
  btnExportCsv: document.getElementById("btn-export-csv"),
  tableTabsContainer: document.getElementById("table-tabs-container"),
  tableSearchInput: document.getElementById("table-search-input"),
  tableRowsInfo: document.getElementById("table-rows-info"),
  dataTableHead: document.getElementById("data-table-head"),
  dataTableBody: document.getElementById("data-table-body")
};

// Initialize
document.addEventListener("DOMContentLoaded", () => {
  checkDbHealth();
  loadTools();
  attachEventListeners();
});

/**
 * 1. Health Check
 */
async function checkDbHealth() {
  try {
    const res = await fetch("/api/health");
    const data = await res.json();
    if (data.database_connected) {
      el.dbStatusDot.classList.remove("offline");
      el.dbStatusBadge.classList.remove("offline");
      el.dbStatusText.textContent = `Connected: ${data.database}`;
      el.dbStatusBadge.title = `Server: ${data.server} | Driver: ${data.driver}`;
    } else {
      el.dbStatusDot.classList.add("offline");
      el.dbStatusBadge.classList.add("offline");
      el.dbStatusText.textContent = "SQL Disconnected";
    }
  } catch (err) {
    el.dbStatusDot.classList.add("offline");
    el.dbStatusBadge.classList.add("offline");
    el.dbStatusText.textContent = "API Offline";
  }
}

/**
 * 2. Load Tools Registry
 */
async function loadTools() {
  try {
    const res = await fetch("/api/tools");
    const data = await res.json();
    state.tools = data.tools || [];
    renderToolHubCards();
    showToolHub();
  } catch (err) {
    showError("Registry Error", err.message);
  }
}

/**
 * Render Cards in View 1: Tool Selection Hub
 */
function renderToolHubCards() {
  el.toolsHubGrid.innerHTML = "";
  state.tools.forEach(tool => {
    const card = document.createElement("div");
    card.className = "tool-hub-card";
    card.innerHTML = `
      <div class="tool-card-head">
        <div class="tool-card-icon">${tool.icon || "🔧"}</div>
        <div class="tool-card-text">
          <h3>${tool.label}</h3>
          <p>${tool.description}</p>
        </div>
      </div>
      <div class="tool-card-foot">
        <span class="tool-sp-badge">${tool.storedProcedure || "Stored Procedure"}</span>
        <span class="tool-card-action">Open Tool →</span>
      </div>
    `;

    card.addEventListener("click", () => openToolWorkspace(tool.id));
    el.toolsHubGrid.appendChild(card);
  });
}

/**
 * View Navigation: Show Tool Hub (View 1)
 */
function showToolHub() {
  el.viewToolHub.style.display = "flex";
  el.viewToolWorkspace.style.display = "none";
  el.btnHeaderBack.style.display = "none";
  el.headerActiveTool.style.display = "none";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

/**
 * View Navigation: Open Tool Workspace (View 2)
 */
function openToolWorkspace(toolId) {
  const tool = state.tools.find(t => t.id === toolId);
  if (!tool) return;
  state.selectedTool = tool;

  // Header update
  el.headerToolIcon.textContent = tool.icon || "🔧";
  el.headerToolName.textContent = tool.label;
  el.headerActiveTool.style.display = "inline-flex";
  el.btnHeaderBack.style.display = "inline-flex";

  // Workspace top bar update
  el.wsToolIcon.textContent = tool.icon || "🔧";
  el.wsToolName.textContent = tool.label;
  el.wsSpName.textContent = tool.storedProcedure || "";

  // Render presets
  renderPresets(toolId);

  // Render parameters form
  renderParametersForm(tool);

  // Render prompts
  renderPromptsList(tool);

  // Hide previous results & errors
  el.resultsSection.classList.remove("active");
  hideError();

  // Show Workspace View
  el.viewToolHub.style.display = "none";
  el.viewToolWorkspace.style.display = "flex";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

/**
 * Render Presets in Workspace
 */
function renderPresets(toolId) {
  el.presetsContainer.innerHTML = "";
  const presets = TOOL_PRESETS[toolId] || [];

  if (presets.length === 0) {
    el.presetsContainer.innerHTML = `<span style="font-size:11px; color:var(--color-espresso-faint);">No presets for this tool.</span>`;
    return;
  }

  presets.forEach(preset => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "preset-chip-btn";
    btn.textContent = preset.name;
    btn.addEventListener("click", () => applyPresetValues(preset.values));
    el.presetsContainer.appendChild(btn);
  });
}

function applyPresetValues(values) {
  Object.entries(values).forEach(([key, val]) => {
    const input = document.getElementById(`param-${key}`);
    if (input) {
      input.value = val === null || val === undefined ? "" : val;
      input.style.backgroundColor = "var(--color-terracotta-light)";
      setTimeout(() => { input.style.backgroundColor = ""; }, 300);
    }
  });
}

/**
 * Render Parameters Form
 */
function renderParametersForm(tool) {
  el.formFieldsContainer.innerHTML = "";
  const params = tool.params || [];

  if (params.length === 0) {
    el.formFieldsContainer.innerHTML = `<div style="font-size:12px; color:var(--color-espresso-muted);">This stored procedure executes without required parameters.</div>`;
    return;
  }

  params.forEach(param => {
    const item = document.createElement("div");
    item.className = "form-item";

    let inputType = "text";
    if (param.type === "int") inputType = "number";
    else if (param.type === "date") inputType = "date";

    const defVal = param.default !== undefined && param.default !== null ? param.default : "";

    item.innerHTML = `
      <div class="form-item-header">
        <label class="form-item-label" for="param-${param.name}">${param.label || param.name}</label>
        ${param.required ? '<span class="tag-required">REQUIRED</span>' : '<span class="tag-optional">OPTIONAL</span>'}
      </div>
      <input 
        type="${inputType}" 
        id="param-${param.name}" 
        name="${param.name}" 
        class="minimal-input" 
        value=""
        placeholder="${defVal !== '' ? 'e.g. ' + defVal : (param.description || param.name)}"
      />
      ${defVal !== "" ? `
        <div class="example-hint">
          <span>${param.description ? truncate(param.description, 36) : ''}</span>
          <span class="example-fill" data-fill="${defVal}">Ex: ${defVal}</span>
        </div>` : ''}
    `;

    const fillBadge = item.querySelector(".example-fill");
    if (fillBadge) {
      fillBadge.addEventListener("click", () => {
        const inp = item.querySelector(".minimal-input");
        if (inp) inp.value = fillBadge.getAttribute("data-fill");
      });
    }

    el.formFieldsContainer.appendChild(item);
  });
}

/**
 * Render Prompts List in Workspace
 */
function renderPromptsList(tool) {
  el.promptsListContainer.innerHTML = "";
  const prompts = tool.prompts || [];
  el.promptsCountBadge.textContent = `${prompts.length} Prompts`;

  if (prompts.length === 0) {
    el.promptsListContainer.innerHTML = `<p style="font-size:12px; color:var(--color-espresso-muted);">No prompts configured for this tool.</p>`;
    state.selectedPrompt = null;
    el.actionPromptName.textContent = "No prompt available";
    return;
  }

  // Default to first prompt
  state.selectedPrompt = prompts[0];
  el.actionPromptName.textContent = prompts[0].label;

  prompts.forEach((p, idx) => {
    const card = document.createElement("div");
    card.className = `prompt-select-card ${idx === 0 ? "selected" : ""}`;
    card.id = `prompt-card-${p.id}`;
    card.innerHTML = `
      <div class="prompt-radio-dot"></div>
      <div class="prompt-card-details">
        <h4>${p.label}</h4>
        <p>${p.description || ""}</p>
      </div>
    `;

    card.addEventListener("click", () => {
      state.selectedPrompt = p;
      document.querySelectorAll(".prompt-select-card").forEach(c => c.classList.remove("selected"));
      card.classList.add("selected");
      el.actionPromptName.textContent = p.label;
    });

    el.promptsListContainer.appendChild(card);
  });
}

/**
 * Reset Parameters
 */
function resetParameters() {
  if (!state.selectedTool) return;
  (state.selectedTool.params || []).forEach(p => {
    const input = document.getElementById(`param-${p.name}`);
    if (input) {
      input.value = "";
    }
  });
}

function collectParameters() {
  const params = {};
  if (!state.selectedTool) return params;

  (state.selectedTool.params || []).forEach(p => {
    const input = document.getElementById(`param-${p.name}`);
    if (input) {
      const val = input.value.trim();
      if (val === "") {
        params[p.name] = null;
      } else if (p.type === "int") {
        const parsed = parseInt(val, 10);
        params[p.name] = isNaN(parsed) ? null : parsed;
      } else {
        params[p.name] = val;
      }
    } else {
      params[p.name] = null;
    }
  });
  return params;
}

/**
 * 3. Execute Analysis Action
 */
async function runAnalysis() {
  if (!state.selectedTool || !state.selectedPrompt) return;

  hideError();
  el.resultsSection.classList.remove("active");
  el.loadingBox.classList.add("active");
  el.btnRunAnalysis.disabled = true;

  el.loadingBox.scrollIntoView({ behavior: "smooth", block: "center" });

  const payload = {
    toolId: state.selectedTool.id,
    promptId: state.selectedPrompt.id,
    params: collectParameters()
  };

  try {
    const res = await fetch("/api/analyze", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    const data = await res.json();
    el.loadingBox.classList.remove("active");
    el.btnRunAnalysis.disabled = false;

    if (!res.ok || data.success === false) {
      showError(
        data.error || "Analysis Failed",
        data.detail || JSON.stringify(data, null, 2)
      );
      if (data.tables && data.tables.length > 0) {
        state.currentTables = data.tables;
        renderSqlTables(data.tables);
        el.resultsSection.classList.add("active");
      }
      return;
    }

    renderResults(data);
  } catch (err) {
    el.loadingBox.classList.remove("active");
    el.btnRunAnalysis.disabled = false;
    showError("Network/Execution Error", err.message);
  }
}

/**
 * 4. Render Results
 */
function renderResults(data) {
  state.currentAnalysis = data.analysis;
  state.currentTables = data.tables || [];

  const meta = data.metadata || {};
  el.statSqlTime.textContent = `${meta.sql_execution_time_ms || 0} ms`;
  el.statAiTime.textContent = `${meta.ai_latency_ms || 0} ms`;
  el.statTotalRows.textContent = `${meta.total_rows || 0}`;
  el.statTableCount.textContent = `${meta.table_count || state.currentTables.length}`;

  // Executive Narrative
  if (data.analysis && data.analysis.executive_summary) {
    el.executiveSummaryBlock.innerHTML = formatParagraphs(data.analysis.executive_summary);
  } else {
    el.executiveSummaryBlock.innerHTML = "<em>No executive narrative summary generated.</em>";
  }

  // KPI Metrics
  renderKeyMetrics(data.analysis ? data.analysis.key_metrics || [] : []);

  // Findings
  renderFindings(data.analysis ? data.analysis.findings || [] : []);

  // Recommendations
  renderRecommendations(data.analysis ? data.analysis.recommendations || [] : []);

  // Supplementary Notes
  if (data.analysis && data.analysis.additional_notes) {
    el.supplementaryNotesText.textContent = data.analysis.additional_notes;
    el.supplementaryNotesContainer.style.display = "block";
  } else {
    el.supplementaryNotesContainer.style.display = "none";
  }

  // SQL Result Tables
  renderSqlTables(state.currentTables);

  // Show Results Section & Scroll smoothly
  el.resultsSection.classList.add("active");
  el.resultsSection.scrollIntoView({ behavior: "smooth", block: "start" });
}

/**
 * Render Key Metrics
 */
function renderKeyMetrics(metrics) {
  el.metricsDeck.innerHTML = "";
  if (metrics.length === 0) {
    el.metricsDeck.style.display = "none";
    return;
  }
  el.metricsDeck.style.display = "grid";

  const themes = ["lavender", "sky", "mint", "butter", "peach"];

  metrics.forEach((m, idx) => {
    const theme = themes[idx % themes.length];
    const card = document.createElement("div");
    card.className = `metric-pill-card ${theme}`;
    card.innerHTML = `
      <div class="metric-pill-label">${m.label}</div>
      <div class="metric-pill-val">${m.value}</div>
      ${m.trend ? `<div class="metric-pill-trend">${m.trend}</div>` : ""}
    `;
    el.metricsDeck.appendChild(card);
  });
}

/**
 * Render Findings
 */
function renderFindings(findings) {
  el.findingsList.innerHTML = "";
  el.findingsCountPill.textContent = `${findings.length}`;

  if (findings.length === 0) {
    el.findingsList.innerHTML = `<span style="font-size:12px; color:var(--color-espresso-muted);">No risk findings identified.</span>`;
    return;
  }

  findings.forEach(f => {
    const bubble = document.createElement("div");
    const sev = (f.severity || "info").toLowerCase();
    bubble.className = `finding-bubble ${sev}`;
    bubble.innerHTML = `
      <div class="finding-bubble-header">
        <strong>${f.title}</strong>
        <span class="finding-tag">${sev}</span>
      </div>
      <p>${f.description}</p>
    `;
    el.findingsList.appendChild(bubble);
  });
}

/**
 * Render Recommendations
 */
function renderRecommendations(recs) {
  el.recommendationsList.innerHTML = "";
  el.recsCountPill.textContent = `${recs.length}`;

  if (recs.length === 0) {
    el.recommendationsList.innerHTML = `<span style="font-size:12px; color:var(--color-espresso-muted);">No specific actions recommended.</span>`;
    return;
  }

  recs.forEach(r => {
    const bubble = document.createElement("div");
    bubble.className = "rec-bubble";
    const pri = (r.priority || "medium").toLowerCase();
    bubble.innerHTML = `
      <div class="rec-bubble-top">
        <span class="rec-bubble-action">${r.action}</span>
        <span class="rec-priority-badge ${pri}">${pri}</span>
      </div>
      ${r.expected_impact ? `<div class="rec-bubble-impact">${r.expected_impact}</div>` : ""}
    `;
    el.recommendationsList.appendChild(bubble);
  });
}

/**
 * 5. Render SQL Tables & Tabs
 */
function renderSqlTables(tables) {
  el.resultSetsBadge.textContent = `${tables.length} Table${tables.length === 1 ? '' : 's'}`;
  el.tableTabsContainer.innerHTML = "";

  if (tables.length === 0) {
    el.dataTableHead.innerHTML = "";
    el.dataTableBody.innerHTML = `<tr><td style="padding:16px; text-align:center;">No records returned by stored procedure.</td></tr>`;
    el.tableRowsInfo.textContent = "Showing 0 rows";
    return;
  }

  state.activeTableIndex = 0;

  tables.forEach((t, idx) => {
    const chip = document.createElement("button");
    chip.type = "button";
    chip.className = `table-tab-chip ${idx === 0 ? "active" : ""}`;
    chip.innerHTML = `
      <span>${t.name || `Table ${idx + 1}`}</span>
      <span class="table-row-count-pill">${t.row_count || (t.rows ? t.rows.length : 0)}</span>
    `;

    chip.addEventListener("click", () => {
      state.activeTableIndex = idx;
      document.querySelectorAll(".table-tab-chip").forEach(c => c.classList.remove("active"));
      chip.classList.add("active");
      state.tableFilterQuery = "";
      el.tableSearchInput.value = "";
      renderActiveTableRows();
    });

    el.tableTabsContainer.appendChild(chip);
  });

  renderActiveTableRows();
}

function renderActiveTableRows() {
  const table = state.currentTables[state.activeTableIndex];
  if (!table) return;

  const cols = table.columns || [];
  const rows = table.rows || [];

  const q = state.tableFilterQuery.toLowerCase().trim();
  const filtered = q === "" 
    ? rows 
    : rows.filter(r => r.some(c => String(c).toLowerCase().includes(q)));

  el.tableRowsInfo.textContent = `Showing ${filtered.length} of ${rows.length} rows`;

  el.dataTableHead.innerHTML = `
    <tr>
      <th style="width:36px; text-align:center;">#</th>
      ${cols.map(c => `<th>${c}</th>`).join("")}
    </tr>
  `;

  if (filtered.length === 0) {
    el.dataTableBody.innerHTML = `<tr><td colspan="${cols.length + 1}" style="padding:16px; text-align:center;">No matching records found.</td></tr>`;
    return;
  }

  const slice = filtered.slice(0, 200);
  el.dataTableBody.innerHTML = slice.map((row, rIdx) => {
    const cells = row.map(cell => {
      const v = cell === null || cell === undefined ? '<span style="color:#aaa;">NULL</span>' : escapeHtml(String(cell));
      return `<td>${v}</td>`;
    }).join("");
    return `<tr><td style="text-align:center; color:var(--color-espresso-faint); font-size:10px;">${rIdx + 1}</td>${cells}</tr>`;
  }).join("");
}

/**
 * CSV Export
 */
function exportActiveTableAsCsv() {
  const table = state.currentTables[state.activeTableIndex];
  if (!table) return;

  const cols = table.columns || [];
  const rows = table.rows || [];

  let csv = cols.map(c => `"${c.replace(/"/g, '""')}"`).join(",") + "\r\n";
  rows.forEach(r => {
    csv += r.map(c => `"${(c === null || c === undefined ? '' : String(c)).replace(/"/g, '""')}"`).join(",") + "\r\n";
  });

  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  const name = (table.name || `table_${state.activeTableIndex + 1}`).toLowerCase().replace(/[^a-z0-9]/g, "_");
  a.download = `${name}_export.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

/**
 * Copy Report
 */
function copyAiReport() {
  if (!state.currentAnalysis) return;
  const a = state.currentAnalysis;

  let md = `# EXECUTIVE ANALYSIS REPORT\n\n`;
  md += `## Executive Summary\n${a.executive_summary}\n\n`;

  if (a.key_metrics && a.key_metrics.length > 0) {
    md += `## Key Metrics\n`;
    a.key_metrics.forEach(m => {
      md += `- **${m.label}**: ${m.value} ${m.trend ? `(${m.trend})` : ""}\n`;
    });
    md += `\n`;
  }

  if (a.findings && a.findings.length > 0) {
    md += `## Key Findings\n`;
    a.findings.forEach(f => {
      md += `- [${(f.severity || "INFO").toUpperCase()}] **${f.title}**: ${f.description}\n`;
    });
    md += `\n`;
  }

  if (a.recommendations && a.recommendations.length > 0) {
    md += `## Recommendations\n`;
    a.recommendations.forEach(r => {
      md += `- [${(r.priority || "MEDIUM").toUpperCase()}] **${r.action}** ${r.expected_impact ? `(${r.expected_impact})` : ""}\n`;
    });
    md += `\n`;
  }

  navigator.clipboard.writeText(md).then(() => {
    el.btnCopyReport.textContent = "✓ Copied!";
    setTimeout(() => { el.btnCopyReport.textContent = "📋 Copy Briefing"; }, 2000);
  });
}

function showError(title, detail) {
  el.errorTitle.textContent = title;
  el.errorDetail.textContent = detail;
  el.errorBox.classList.add("active");
  el.errorBox.scrollIntoView({ behavior: "smooth" });
}

function hideError() {
  el.errorBox.classList.remove("active");
}

function attachEventListeners() {
  // Navigation
  el.brandHomeLink.addEventListener("click", showToolHub);
  el.btnHeaderBack.addEventListener("click", showToolHub);
  el.btnWsBack.addEventListener("click", showToolHub);

  // Workspace actions
  el.btnResetParams.addEventListener("click", resetParameters);
  el.btnRunAnalysis.addEventListener("click", runAnalysis);
  el.btnExportCsv.addEventListener("click", exportActiveTableAsCsv);
  el.btnCopyReport.addEventListener("click", copyAiReport);

  // Jump to tables
  el.btnScrollSql.addEventListener("click", () => {
    el.sqlTablesSection.scrollIntoView({ behavior: "smooth" });
  });

  // Table search
  el.tableSearchInput.addEventListener("input", (e) => {
    state.tableFilterQuery = e.target.value;
    renderActiveTableRows();
  });
}

function truncate(str, len) {
  if (!str) return "";
  return str.length > len ? str.substring(0, len) + "..." : str;
}

function escapeHtml(str) {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function formatParagraphs(text) {
  if (!text) return "";
  return text.split("\n\n").map(p => `<p>${escapeHtml(p).replace(/\n/g, "<br>")}</p>`).join("");
}
