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
  currentRawAnalysis: null,
  currentTables: [],
  activeTableIndex: 0,
  tableFilterQuery: "",
  companies: []
};

const TOOL_PRESETS = {
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
  customResponseCard: document.getElementById("custom-response-card"),
  customResponseText: document.getElementById("custom-response-text"),
  rawAnalysisContainer: document.getElementById("raw-analysis-container"),
  rawAnalysisContent: document.getElementById("raw-analysis-content"),
  structuredResultsContainer: document.getElementById("structured-results-container"),
  
  // Breakdown Table
  breakdownTableContainer: document.getElementById("breakdown-table-container"),
  breakdownTableTitle: document.getElementById("breakdown-table-title"),
  breakdownCountPill: document.getElementById("breakdown-count-pill"),
  breakdownTableHead: document.getElementById("breakdown-table-head"),
  breakdownTableBody: document.getElementById("breakdown-table-body"),
  
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
 * Fetch Companies for Dynamic Dropdown
 */
async function fetchCompanies() {
  if (state.companies && state.companies.length > 0) return state.companies;
  try {
    const res = await fetch("/api/companies");
    const data = await res.json();
    state.companies = data.companies || [];
    return state.companies;
  } catch (err) {
    console.error("Failed to fetch companies:", err);
    return [];
  }
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

    // Handle Select Dropdown (e.g. Company from masterdata.mCompanyMaster)
    if (param.type === "select") {
      item.innerHTML = `
        <div class="form-item-header">
          <label class="form-item-label" for="param-${param.name}">${param.label || param.name}</label>
          ${param.required ? '<span class="tag-required">REQUIRED</span>' : '<span class="tag-optional">OPTIONAL</span>'}
        </div>
        <select 
          id="param-${param.name}" 
          name="${param.name}" 
          class="minimal-input select-dropdown"
        >
          <option value="">-- All Companies (None / Optional) --</option>
        </select>
        <div class="example-hint">
          <span>${param.description ? truncate(param.description, 42) : ''}</span>
          <span class="example-fill" data-clear="param-${param.name}">Reset</span>
        </div>
      `;
      el.formFieldsContainer.appendChild(item);

      const clearBtn = item.querySelector("[data-clear]");
      if (clearBtn) {
        clearBtn.addEventListener("click", () => {
          const sel = document.getElementById(`param-${param.name}`);
          if (sel) sel.value = "";
        });
      }

      fetchCompanies().then(companies => {
        const selectEl = document.getElementById(`param-${param.name}`);
        if (!selectEl) return;
        selectEl.innerHTML = `<option value="">-- All Companies (None / Optional) --</option>`;
        companies.forEach(c => {
          const opt = document.createElement("option");
          opt.value = c.value;
          opt.textContent = c.label;
          selectEl.appendChild(opt);
        });
        // Default remains null / empty ("") per user requirement
      });
      return;
    }

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
  el.promptsCountBadge.textContent = `${prompts.length + 1} Options`;

  // Default to first prompt template
  if (prompts.length > 0) {
    state.selectedPrompt = prompts[0];
    el.actionPromptName.textContent = prompts[0].label;
  } else {
    state.selectedPrompt = { id: "custom", label: "Custom Free-form Analysis", isCustom: true };
    el.actionPromptName.textContent = "Custom Free-form Analysis";
  }

  // 1. Render predefined prompt cards
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

      // Collapse custom prompt input when a standard template is selected
      const customWrapper = document.getElementById("custom-prompt-wrapper");
      if (customWrapper) customWrapper.style.display = "none";
    });

    el.promptsListContainer.appendChild(card);
  });

  // 2. Render Custom Free-form Analysis prompt card (treated as a prompt lens option)
  const customCard = document.createElement("div");
  customCard.className = `prompt-select-card custom-prompt-card ${prompts.length === 0 ? "selected" : ""}`;
  customCard.id = "prompt-card-custom";
  customCard.innerHTML = `
    <div class="prompt-radio-dot"></div>
    <div class="prompt-card-details" style="width: 100%;">
      <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 2px;">
        <h4 style="margin: 0;">✍️ Custom Free-form Analysis</h4>
        <span style="font-size: 9px; font-weight: 700; background: rgba(204, 139, 101, 0.18); color: var(--color-terracotta-dark); padding: 2px 6px; border-radius: 4px; text-transform: uppercase;">Unconstrained</span>
      </div>
      <p style="margin-bottom: 4px;">Define your own analysis prompt without rigid JSON schema constraints. The LLM responds in free-form Markdown.</p>
      <div class="custom-prompt-input-wrapper" id="custom-prompt-wrapper" style="display: none; margin-top: 8px;">
        <textarea
          id="custom-prompt-textarea"
          class="minimal-input"
          rows="3"
          placeholder="e.g. Focus on vendor delivery turnaround, list all late line items with delay days, and give immediate recommendations..."
          style="width: 100%; resize: vertical; font-size: 12px; line-height: 1.45; padding: 8px 10px; background: #FFFFFF;"
        ></textarea>
        <div style="font-size: 10.5px; color: var(--color-espresso-faint); margin-top: 4px;">
          Direct LLM response will be displayed without enforcing predefined schemas.
        </div>
      </div>
    </div>
  `;

  customCard.addEventListener("click", (e) => {
    // If the click originated inside the textarea, do not deselect
    if (e.target.id === "custom-prompt-textarea") return;

    state.selectedPrompt = { id: "custom", label: "Custom Free-form Analysis", isCustom: true };
    document.querySelectorAll(".prompt-select-card").forEach(c => c.classList.remove("selected"));
    customCard.classList.add("selected");
    el.actionPromptName.textContent = "Custom Free-form Analysis";

    const customWrapper = document.getElementById("custom-prompt-wrapper");
    if (customWrapper) {
      customWrapper.style.display = "block";
      const textarea = document.getElementById("custom-prompt-textarea");
      if (textarea) textarea.focus();
    }
  });

  el.promptsListContainer.appendChild(customCard);
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
  const customTextarea = document.getElementById("custom-prompt-textarea");
  if (customTextarea) {
    customTextarea.value = "";
  }
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
      } else if (p.type === "int" || p.type === "select") {
        const parsed = parseInt(val, 10);
        params[p.name] = isNaN(parsed) ? val : parsed;
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

  const isCustom = state.selectedPrompt.id === "custom";
  let customInputVal = null;

  if (isCustom) {
    const customTextarea = document.getElementById("custom-prompt-textarea");
    customInputVal = customTextarea ? customTextarea.value.trim() : "";
    if (!customInputVal) {
      el.loadingBox.classList.remove("active");
      el.btnRunAnalysis.disabled = false;
      showError(
        "Custom Prompt Required",
        "Please enter your analytical question or instructions in the Custom Free-form Analysis box."
      );
      const customWrapper = document.getElementById("custom-prompt-wrapper");
      if (customWrapper) {
        customWrapper.style.display = "block";
        if (customTextarea) customTextarea.focus();
      }
      return;
    }
  }

  const payload = {
    toolId: state.selectedTool.id,
    promptId: isCustom ? "custom" : state.selectedPrompt.id,
    params: collectParameters(),
    custom_input: isCustom ? customInputVal : null
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
  state.currentRawAnalysis = data.raw_analysis || null;
  state.currentTables = data.tables || [];

  const meta = data.metadata || {};
  el.statSqlTime.textContent = `${meta.sql_execution_time_ms || 0} ms`;
  el.statAiTime.textContent = `${meta.ai_latency_ms || 0} ms`;
  el.statTotalRows.textContent = `${meta.total_rows || 0}`;
  el.statTableCount.textContent = `${meta.table_count || state.currentTables.length}`;

  // If this was a custom unconstrained prompt, render raw analysis directly
  if (data.raw_analysis) {
    if (el.structuredResultsContainer) el.structuredResultsContainer.style.display = "none";
    if (el.rawAnalysisContainer) {
      el.rawAnalysisContainer.style.display = "block";
      el.rawAnalysisContent.innerHTML = renderMarkdown(data.raw_analysis);
    }
  } else {
    // Structured analysis mode
    if (el.rawAnalysisContainer) el.rawAnalysisContainer.style.display = "none";
    if (el.structuredResultsContainer) el.structuredResultsContainer.style.display = "block";

    // Custom Inquiry Response (if answered)
    if (data.analysis && data.analysis.custom_response && data.analysis.custom_response.trim()) {
      el.customResponseText.innerHTML = formatParagraphs(data.analysis.custom_response);
      el.customResponseCard.style.display = "block";
    } else {
      el.customResponseCard.style.display = "none";
    }

    // Executive Narrative
    if (data.analysis && data.analysis.executive_summary) {
      el.executiveSummaryBlock.innerHTML = formatParagraphs(data.analysis.executive_summary);
    } else {
      el.executiveSummaryBlock.innerHTML = "<em>No executive narrative summary generated.</em>";
    }

    // KPI Metrics
    renderKeyMetrics(data.analysis ? data.analysis.key_metrics || [] : []);

    // Structured Breakdown Matrix (Line-Level, Delays, Quality, or 3-Way Match)
    renderBreakdownTable(data.analysis ? data.analysis.breakdown_table || [] : []);

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
      <div class="metric-pill-label">${escapeHtml(m.label)}</div>
      <div class="metric-pill-val">${escapeHtml(m.value)}</div>
      ${m.trend ? `<div class="metric-pill-trend">${escapeHtml(m.trend)}</div>` : ""}
    `;
    el.metricsDeck.appendChild(card);
  });
}

/**
 * Render Structured Breakdown Table
 */
function renderBreakdownTable(breakdownRows) {
  if (!breakdownRows || breakdownRows.length === 0) {
    el.breakdownTableContainer.style.display = "none";
    return;
  }

  el.breakdownTableContainer.style.display = "block";
  el.breakdownCountPill.textContent = `${breakdownRows.length} item${breakdownRows.length === 1 ? '' : 's'}`;

  // Dynamic titles depending on selected prompt
  const pId = state.selectedPrompt ? state.selectedPrompt.id : "";
  if (pId === "three_way_matching_finance") {
    el.breakdownTableTitle.textContent = "⚖️ Three-Way Match & Financial Valuation Matrix";
  } else if (pId === "vendor_delivery_performance") {
    el.breakdownTableTitle.textContent = "⏱️ Supplier Delivery Schedule & Delay Matrix";
  } else if (pId === "quality_rejection_audit") {
    el.breakdownTableTitle.textContent = "🔍 Material Inspection & Rejection Variance Matrix";
  } else {
    el.breakdownTableTitle.textContent = "📋 Line-Level Health & Quantity Fulfillment Matrix";
  }

  // Determine dynamic column headers from the first row
  const first = breakdownRows[0];
  const h1 = first.col1_label || "Metric 1";
  const h2 = first.col2_label || "Metric 2";
  const h3 = first.col3_label || "Metric 3";

  el.breakdownTableHead.innerHTML = `
    <tr>
      <th style="min-width: 170px;">Item / Scope</th>
      <th>${escapeHtml(h1)}</th>
      <th>${escapeHtml(h2)}</th>
      <th>${escapeHtml(h3)}</th>
      <th style="text-align: right; min-width: 110px;">Status / Flag</th>
    </tr>
  `;

  el.breakdownTableBody.innerHTML = "";
  breakdownRows.forEach(r => {
    const tr = document.createElement("tr");
    const tag = (r.status_tag || "").toUpperCase();

    let tagClass = "tag-info";
    if (["COMPLETED", "MATCHED", "ON_TIME", "ACCEPTED", "FULLY_RECEIVED"].some(s => tag.includes(s))) {
      tagClass = "tag-success";
    } else if (["PENDING", "PENDING_BILLING", "WAITING", "UNBILLED", "PARTIAL"].some(s => tag.includes(s))) {
      tagClass = "tag-warning";
    } else if (["OVERDUE", "REJECTED", "CANCELLED", "REJECTION", "EXPIRED", "DELAYED"].some(s => tag.includes(s))) {
      tagClass = "tag-danger";
    }

    tr.innerHTML = `
      <td class="breakdown-item-cell">
        <strong>${escapeHtml(r.item_or_category || "—")}</strong>
      </td>
      <td>${escapeHtml(r.col1_value || "—")}</td>
      <td>${escapeHtml(r.col2_value || "—")}</td>
      <td>${escapeHtml(r.col3_value || "—")}</td>
      <td style="text-align: right;">
        ${tag ? `<span class="breakdown-status-badge ${tagClass}">${escapeHtml(tag)}</span>` : "—"}
      </td>
    `;
    el.breakdownTableBody.appendChild(tr);
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
  if (state.currentRawAnalysis) {
    navigator.clipboard.writeText(state.currentRawAnalysis).then(() => {
      el.btnCopyReport.textContent = "✓ Copied!";
      setTimeout(() => { el.btnCopyReport.textContent = "📋 Copy Briefing"; }, 2000);
    });
    return;
  }

  if (!state.currentAnalysis) return;
  const a = state.currentAnalysis;

  let md = `# EXECUTIVE ANALYSIS REPORT\n\n`;
  if (a.custom_response) {
    md += `## Custom Inquiry Answer\n${a.custom_response}\n\n`;
  }
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

/**
 * Lightweight, safe Markdown-to-HTML parser for unconstrained LLM responses.
 */
function renderMarkdown(md) {
  if (!md) return "";

  // 1. Normalize line endings
  let text = md.replace(/\r\n/g, "\n");

  // 2. Extract code blocks to preserve them
  const codeBlocks = [];
  text = text.replace(/```([a-zA-Z0-9_-]*)\n([\s\S]*?)```/g, (_, lang, code) => {
    const idx = codeBlocks.length;
    codeBlocks.push(`<pre><code class="language-${escapeHtml(lang)}">${escapeHtml(code.trim())}</code></pre>`);
    return `\n\n@@CODEBLOCK_${idx}@@\n\n`;
  });

  // Helper for inline styles
  function inlineMarkdown(str) {
    return escapeHtml(str)
      .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
      .replace(/\*([^*]+)\*/g, '<em>$1</em>')
      .replace(/`([^`]+)`/g, '<code>$1</code>');
  }

  // 3. Extract tables
  const tableRegex = /((?:^|\n)\|[^\n]+\|\n\|[\s:-|-]+\|\n(?:\|[^\n]+\|\n?)+)/g;
  text = text.replace(tableRegex, (match) => {
    const lines = match.trim().split("\n");
    if (lines.length < 2) return match;
    const headerCells = lines[0].split("|").filter((_, i, arr) => i > 0 && i < arr.length - 1).map(c => c.trim());
    const bodyRows = lines.slice(2).map(line => {
      return line.split("|").filter((_, i, arr) => i > 0 && i < arr.length - 1).map(c => c.trim());
    });

    let html = '<table><thead><tr>';
    headerCells.forEach(h => { html += `<th>${escapeHtml(h)}</th>`; });
    html += '</tr></thead><tbody>';
    bodyRows.forEach(row => {
      html += '<tr>';
      row.forEach(cell => { html += `<td>${inlineMarkdown(cell)}</td>`; });
      html += '</tr>';
    });
    html += '</tbody></table>';
    return `\n\n${html}\n\n`;
  });

  // 4. Split into paragraphs / blocks
  const blocks = text.split(/\n{2,}/);
  const parsedBlocks = blocks.map(block => {
    block = block.trim();
    if (!block) return "";

    if (block.startsWith("@@CODEBLOCK_")) {
      const idxMatch = block.match(/@@CODEBLOCK_(\d+)@@/);
      if (idxMatch) {
        return codeBlocks[parseInt(idxMatch[1], 10)];
      }
    }

    if (block.startsWith("<table")) {
      return block;
    }

    // Headings
    if (block.startsWith("#### ")) return `<h4>${inlineMarkdown(block.slice(5))}</h4>`;
    if (block.startsWith("### ")) return `<h3>${inlineMarkdown(block.slice(4))}</h3>`;
    if (block.startsWith("## ")) return `<h2>${inlineMarkdown(block.slice(3))}</h2>`;
    if (block.startsWith("# ")) return `<h1>${inlineMarkdown(block.slice(2))}</h1>`;

    // Blockquote
    if (block.startsWith("> ")) {
      const content = block.split("\n").map(l => l.replace(/^>\s?/, "")).join("<br>");
      return `<blockquote>${inlineMarkdown(content)}</blockquote>`;
    }

    // Unordered List
    if (/^[-*]\s+/m.test(block)) {
      const items = block.split("\n").filter(l => l.trim());
      const lis = items.map(l => `<li>${inlineMarkdown(l.replace(/^[-*]\s+/, ""))}</li>`).join("");
      return `<ul>${lis}</ul>`;
    }

    // Ordered List
    if (/^\d+\.\s+/m.test(block)) {
      const items = block.split("\n").filter(l => l.trim());
      const lis = items.map(l => `<li>${inlineMarkdown(l.replace(/^\d+\.\s+/, ""))}</li>`).join("");
      return `<ol>${lis}</ol>`;
    }

    // Normal paragraph
    return `<p>${inlineMarkdown(block).replace(/\n/g, "<br>")}</p>`;
  });

  let finalHtml = parsedBlocks.join("");

  // Restore any placeholder that might remain
  finalHtml = finalHtml.replace(/@@CODEBLOCK_(\d+)@@/g, (_, idx) => codeBlocks[parseInt(idx, 10)] || "");
  return finalHtml;
}

