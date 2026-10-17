/**
 * SINGLE-CANVAS AI STORED PROCEDURE ANALYZER
 * Client application orchestrating Tool Hub selection, parameter/prompt workspace,
 * multi-step navigation, and executive AI results visualization.
 */

// Application State
const state = {
  tools: [],
  selectedTool: null,
  selectedReport: null,
  selectedPrompt: null,
  currentAnalysis: null,
  currentRawAnalysis: null,
  currentTables: [],
  activeTableIndex: 0,
  tableFilterQuery: "",
  tableViewMode: "all",
  showSqlTables: false,
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
  reportSelectorBar: document.getElementById("report-selector-bar"),
  reportSelectorTabs: document.getElementById("report-selector-tabs"),
  paramsColumnTitle: document.getElementById("params-column-title"),
  promptsColumnTitle: document.getElementById("prompts-column-title"),
  promptsColumnDesc: document.getElementById("prompts-column-desc"),
  
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
  btnTablesOff: document.getElementById("btn-tables-off"),
  btnTablesOn: document.getElementById("btn-tables-on"),
  btnHideTablesCard: document.getElementById("btn-hide-tables-card"),
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
  dataTableBody: document.getElementById("data-table-body"),
  allTablesContainer: document.getElementById("all-tables-container"),
  singleTableContainer: document.getElementById("single-table-container"),
  btnViewAll: document.getElementById("btn-view-all"),
  btnViewSingle: document.getElementById("btn-view-single")
};

// Initialize
document.addEventListener("DOMContentLoaded", () => {
  checkDbHealth();
  loadTools();
  setTablesVisibility(false);
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

  // Check if tool has reports (e.g. report_analyzer)
  if (tool.reports && tool.reports.length > 0) {
    if (el.reportSelectorBar) el.reportSelectorBar.style.display = "flex";
    renderReportSelector(tool);
    selectReport(tool.reports[0]);
  } else {
    // Single-purpose tool (e.g. po_analyzer)
    if (el.reportSelectorBar) el.reportSelectorBar.style.display = "none";
    state.selectedReport = null;
    el.wsSpName.textContent = tool.storedProcedure || "";
    if (el.paramsColumnTitle) el.paramsColumnTitle.textContent = "01 // Input Parameters";
    if (el.promptsColumnTitle) el.promptsColumnTitle.textContent = "02 // Analytical Prompt Lens";
    if (el.promptsColumnDesc) el.promptsColumnDesc.textContent = "Select the analytical focus for Gemini to reason over the returned stored procedure data:";

    renderPresets(tool);
    renderParametersForm(tool);
    renderPromptsList(tool);
  }

  // Hide previous results & errors
  el.resultsSection.classList.remove("active");
  hideError();

  // Show Workspace View
  el.viewToolHub.style.display = "none";
  el.viewToolWorkspace.style.display = "flex";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function renderReportSelector(tool) {
  if (!el.reportSelectorTabs) return;
  el.reportSelectorTabs.innerHTML = "";
  (tool.reports || []).forEach((report, idx) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `report-tab-btn ${idx === 0 ? "active" : ""}`;
    btn.id = `report-tab-${report.id}`;
    btn.innerHTML = `<span>${report.icon || "📄"}</span> <span>${report.label}</span>`;
    btn.addEventListener("click", () => {
      document.querySelectorAll(".report-tab-btn").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      selectReport(report);
    });
    el.reportSelectorTabs.appendChild(btn);
  });
}

function selectReport(report) {
  state.selectedReport = report;
  el.wsSpName.textContent = report.storedProcedure || "";
  if (el.paramsColumnTitle) el.paramsColumnTitle.textContent = `01 // ${report.label} Parameters`;
  if (el.promptsColumnTitle) el.promptsColumnTitle.textContent = "02 // Custom Analytical Lens";
  if (el.promptsColumnDesc) el.promptsColumnDesc.textContent = "Enter your custom analytical questions, requirements, or focus areas for Gemini to reason over this report:";

  renderPresets(report);
  renderParametersForm(report);
  renderReportCustomPrompt(report);
}

function renderReportCustomPrompt(report) {
  el.promptsListContainer.innerHTML = "";
  el.promptsCountBadge.textContent = "Custom Prompt";
  state.selectedPrompt = { id: "custom", label: "Custom Free-form Analysis", isCustom: true };
  el.actionPromptName.textContent = `Custom Analysis: ${report.label}`;

  const customCard = document.createElement("div");
  customCard.className = "prompt-select-card custom-prompt-card selected";
  customCard.id = "prompt-card-custom";
  customCard.style.cursor = "default";
  customCard.innerHTML = `
    <div class="prompt-radio-dot"></div>
    <div class="prompt-card-details" style="width: 100%;">
      <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px;">
        <h4 style="margin: 0;">✍️ Custom Free-form Analysis</h4>
        <span style="font-size: 9px; font-weight: 700; background: rgba(1, 51, 40, 0.1); color: var(--color-forest); padding: 2px 6px; border-radius: 4px; text-transform: uppercase;">Direct LLM</span>
      </div>
      <div class="custom-prompt-input-wrapper" style="display: block;">
        <textarea
          id="custom-prompt-textarea"
          class="minimal-input"
          rows="5"
          placeholder="e.g. Analyze overall volume, flag lines with delivery delays or high rejections, compare customer totals, or summarize key trends..."
          style="width: 100%; resize: vertical; min-height: 95px; font-size: 12.5px; line-height: 1.5; padding: 10px 12px; background: #FFFFFF;"
        ></textarea>
      </div>
    </div>
  `;
  el.promptsListContainer.appendChild(customCard);
}

/**
 * Render Presets in Workspace
 */
function renderPresets(target) {
  el.presetsContainer.innerHTML = "";
  const toolId = typeof target === "string" ? target : (target ? target.id : "");
  const presets = (target && target.presets) ? target.presets : (TOOL_PRESETS[toolId] || []);

  if (presets.length === 0) {
    el.presetsContainer.innerHTML = `<span style="font-size:11px; color:var(--color-espresso-faint);">No presets configured.</span>`;
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

    // Handle Select Dropdown (e.g. static options or dynamic companies)
    if (param.type === "select") {
      let optionsHtml = '';
      if (param.options && param.options.length > 0) {
        optionsHtml = param.options.map(opt => {
          const isSel = (param.default !== null && param.default !== undefined && String(param.default) === String(opt.value)) ? "selected" : "";
          return `<option value="${opt.value}" ${isSel}>${escapeHtml(opt.label)}</option>`;
        }).join("");
      } else {
        optionsHtml = `<option value="">-- All Companies (None / Optional) --</option>`;
      }

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
          ${optionsHtml}
        </select>
        <div class="example-hint">
          <span>${param.description ? truncate(param.description, 45) : ''}</span>
          <span class="example-fill" data-clear="param-${param.name}">Reset</span>
        </div>
      `;
      el.formFieldsContainer.appendChild(item);

      const clearBtn = item.querySelector("[data-clear]");
      if (clearBtn) {
        clearBtn.addEventListener("click", () => {
          const sel = document.getElementById(`param-${param.name}`);
          if (sel) {
            sel.value = param.default !== undefined && param.default !== null ? String(param.default) : "";
          }
        });
      }

      if (param.optionsUrl) {
        fetchCompanies().then(companies => {
          const selectEl = document.getElementById(`param-${param.name}`);
          if (!selectEl) return;
          selectEl.innerHTML = `<option value="">-- All Companies (None / Optional) --</option>`;
          companies.forEach(c => {
            const opt = document.createElement("option");
            opt.value = c.value;
            opt.textContent = c.label;
            if (param.default !== null && param.default !== undefined && String(param.default) === String(c.value)) {
              opt.selected = true;
            }
            selectEl.appendChild(opt);
          });
        });
      }
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
        value="${defVal}"
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
    const isSelected = idx === 0;
    const card = document.createElement("div");
    card.className = `prompt-select-card ${isSelected ? "selected" : ""}`;
    card.id = `prompt-card-${p.id}`;

    // Prepare underlying prompt content
    const sysPrompt = p.systemPrompt ? p.systemPrompt.trim() : "";
    const userPrompt = p.userPromptTemplate ? p.userPromptTemplate.trim() : "";

    let underlyingHtml = "";
    let toggleBtnHtml = "";
    if (sysPrompt || userPrompt) {
      toggleBtnHtml = `
        <div class="prompt-toggle-row">
          <button type="button" class="btn-toggle-prompt-view" data-prompt-id="${p.id}" title="Toggle underlying prompt details">
            <span class="toggle-icon">👁</span> <span class="toggle-text">View Prompt</span>
          </button>
        </div>
      `;
      underlyingHtml = `
        <div class="prompt-underlying-container" id="prompt-underlying-${p.id}" style="display: none;">
          <div class="prompt-underlying-header">
            <span class="prompt-underlying-title">📜 Underlying Template Prompt</span>
            <button type="button" class="btn-copy-underlying" title="Copy full prompt text">📋 Copy</button>
          </div>
          <div class="prompt-underlying-body">
            ${sysPrompt ? `
              <div class="prompt-underlying-label">⚡ System Directive & Deliverables</div>
              <pre class="prompt-underlying-pre">${escapeHtml(sysPrompt)}</pre>
            ` : ''}
            ${userPrompt ? `
              <div class="prompt-underlying-label" style="${sysPrompt ? 'margin-top: 8px;' : ''}">💬 User Prompt Template</div>
              <pre class="prompt-underlying-pre">${escapeHtml(userPrompt)}</pre>
            ` : ''}
          </div>
        </div>
      `;
    }

    card.innerHTML = `
      <div class="prompt-radio-dot"></div>
      <div class="prompt-card-details" style="width: 100%;">
        <h4>${p.label}</h4>
        <p>${p.description || ""}</p>
        ${toggleBtnHtml}
        ${underlyingHtml}
      </div>
    `;

    // Toggle View Prompt button listener
    const toggleBtn = card.querySelector(".btn-toggle-prompt-view");
    if (toggleBtn) {
      toggleBtn.addEventListener("click", (e) => {
        e.stopPropagation();

        // Also ensure the card is selected
        state.selectedPrompt = p;
        document.querySelectorAll(".prompt-select-card").forEach(c => c.classList.remove("selected"));
        card.classList.add("selected");
        el.actionPromptName.textContent = p.label;

        // Collapse custom prompt input when a standard template is selected
        const customWrapper = document.getElementById("custom-prompt-wrapper");
        if (customWrapper) customWrapper.style.display = "none";

        const myUnderlying = card.querySelector(".prompt-underlying-container");
        if (!myUnderlying) return;

        const isCurrentlyOpen = myUnderlying.style.display === "block";
        if (isCurrentlyOpen) {
          myUnderlying.style.display = "none";
          toggleBtn.classList.remove("active");
          toggleBtn.innerHTML = `<span class="toggle-icon">👁</span> <span class="toggle-text">View Prompt</span>`;
        } else {
          myUnderlying.style.display = "block";
          toggleBtn.classList.add("active");
          toggleBtn.innerHTML = `<span class="toggle-icon">✕</span> <span class="toggle-text">Hide Prompt</span>`;
        }
      });
    }

    // Copy prompt text listener
    const copyBtn = card.querySelector(".btn-copy-underlying");
    if (copyBtn) {
      copyBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        const copyParts = [];
        if (sysPrompt) copyParts.push(`--- SYSTEM DIRECTIVE ---\n${sysPrompt}`);
        if (userPrompt) copyParts.push(`--- USER PROMPT TEMPLATE ---\n${userPrompt}`);
        const textToCopy = copyParts.join("\n\n");
        navigator.clipboard.writeText(textToCopy).then(() => {
          copyBtn.textContent = "✓ Copied";
          setTimeout(() => { copyBtn.textContent = "📋 Copy"; }, 1500);
        }).catch(() => {
          copyBtn.textContent = "✓ Copied";
          setTimeout(() => { copyBtn.textContent = "📋 Copy"; }, 1500);
        });
      });
    }

    card.addEventListener("click", (e) => {
      // Do not deselect or toggle if clicking toggle or copy button
      if (e.target.closest(".btn-toggle-prompt-view") || e.target.closest(".btn-copy-underlying")) return;

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
      <div class="custom-prompt-input-wrapper" id="custom-prompt-wrapper" style="display: none; margin-top: 8px;">
        <textarea
          id="custom-prompt-textarea"
          class="minimal-input"
          rows="3"
          placeholder="e.g. Focus on vendor delivery turnaround, list all late line items with delay days, and give immediate recommendations..."
          style="width: 100%; resize: vertical; font-size: 12px; line-height: 1.45; padding: 8px 10px; background: #FFFFFF;"
        ></textarea>
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

    // Hide any open underlying prompt containers and reset toggle buttons
    document.querySelectorAll(".prompt-underlying-container").forEach(box => box.style.display = "none");
    document.querySelectorAll(".btn-toggle-prompt-view").forEach(btn => {
      btn.classList.remove("active");
      btn.innerHTML = `<span class="toggle-icon">👁</span> <span class="toggle-text">View Prompt</span>`;
    });

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
  const activeObj = state.selectedReport || state.selectedTool;
  if (!activeObj) return;
  (activeObj.params || []).forEach(p => {
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
  const activeObj = state.selectedReport || state.selectedTool;
  if (!activeObj) return params;

  (activeObj.params || []).forEach(p => {
    const input = document.getElementById(`param-${p.name}`);
    if (input) {
      let val = input.value.trim();
      if (val === "" && p.default !== undefined && p.default !== null) {
        val = String(p.default);
      }
      if (val === "") {
        params[p.name] = null;
      } else if (p.type === "int" || p.type === "select") {
        const parsed = parseInt(val, 10);
        params[p.name] = isNaN(parsed) ? val : parsed;
      } else {
        params[p.name] = val;
      }
    } else {
      params[p.name] = p.default !== undefined ? p.default : null;
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
    reportId: state.selectedReport ? state.selectedReport.id : null,
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
  setTablesVisibility(false);

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
 * 5. Render SQL Tables & Multi-Table Viewer
 */
function setTableViewMode(mode) {
  state.tableViewMode = mode;
  if (mode === "all") {
    if (el.btnViewAll) el.btnViewAll.classList.add("active");
    if (el.btnViewSingle) el.btnViewSingle.classList.remove("active");
    if (el.allTablesContainer) el.allTablesContainer.style.display = "flex";
    if (el.singleTableContainer) el.singleTableContainer.style.display = "none";
  } else {
    if (el.btnViewSingle) el.btnViewSingle.classList.add("active");
    if (el.btnViewAll) el.btnViewAll.classList.remove("active");
    if (el.allTablesContainer) el.allTablesContainer.style.display = "none";
    if (el.singleTableContainer) el.singleTableContainer.style.display = "block";
    renderActiveTableRows();
  }
}

function setTablesVisibility(show, shouldScroll = false) {
  state.showSqlTables = Boolean(show);

  if (el.btnTablesOff) {
    el.btnTablesOff.classList.toggle("active", !state.showSqlTables);
  }
  if (el.btnTablesOn) {
    el.btnTablesOn.classList.toggle("active", state.showSqlTables);
  }

  if (el.sqlTablesSection) {
    el.sqlTablesSection.style.display = state.showSqlTables ? "block" : "none";
  }

  if (state.showSqlTables && shouldScroll && el.sqlTablesSection) {
    el.sqlTablesSection.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

function renderSqlTables(tables) {
  el.resultSetsBadge.textContent = `${tables.length} Table${tables.length === 1 ? '' : 's'}`;
  el.tableTabsContainer.innerHTML = "";
  if (el.allTablesContainer) el.allTablesContainer.innerHTML = "";

  if (tables.length === 0) {
    if (el.allTablesContainer) {
      el.allTablesContainer.innerHTML = `<div style="padding:24px; text-align:center; color:var(--color-espresso-muted); font-size:13px; background:#FFFFFF; border-radius:8px;">No records returned by stored procedure.</div>`;
    }
    el.dataTableHead.innerHTML = "";
    el.dataTableBody.innerHTML = `<tr><td style="padding:16px; text-align:center;">No records returned by stored procedure.</td></tr>`;
    el.tableRowsInfo.textContent = "Showing 0 rows";
    return;
  }

  state.activeTableIndex = 0;

  // Render navigation tab chips
  tables.forEach((t, idx) => {
    const chip = document.createElement("button");
    chip.type = "button";
    chip.className = `table-tab-chip ${idx === 0 ? "active" : ""}`;
    chip.id = `table-chip-${idx}`;
    chip.innerHTML = `
      <span>${t.name || `Table ${idx + 1}`}</span>
      <span class="table-row-count-pill">${t.row_count || (t.rows ? t.rows.length : 0)}</span>
    `;

    chip.addEventListener("click", () => {
      state.activeTableIndex = idx;
      document.querySelectorAll(".table-tab-chip").forEach(c => c.classList.remove("active"));
      chip.classList.add("active");

      if (state.tableViewMode === "all") {
        const targetCard = document.getElementById(`table-card-${idx}`);
        if (targetCard) {
          targetCard.scrollIntoView({ behavior: "smooth", block: "start" });
          targetCard.style.borderColor = "var(--color-terracotta)";
          setTimeout(() => { targetCard.style.borderColor = ""; }, 1000);
        }
      } else {
        state.tableFilterQuery = "";
        el.tableSearchInput.value = "";
        renderActiveTableRows();
      }
    });

    el.tableTabsContainer.appendChild(chip);
  });

  // Render All Tables Stacked
  renderAllTablesStacked(tables);

  // Render Active Single Table
  renderActiveTableRows();

  // Apply default view mode
  setTableViewMode(state.tableViewMode || "all");
}

function renderAllTablesStacked(tables) {
  if (!el.allTablesContainer) return;
  el.allTablesContainer.innerHTML = "";

  tables.forEach((t, idx) => {
    const cols = t.columns || [];
    const rows = t.rows || [];
    const rowCount = t.row_count !== undefined ? t.row_count : rows.length;

    const card = document.createElement("div");
    card.className = "table-individual-card";
    card.id = `table-card-${idx}`;

    card.innerHTML = `
      <div class="table-card-subhead">
        <div class="table-card-subhead-left">
          <span class="table-idx-badge">Table ${idx + 1}</span>
          <strong style="font-size:13px; color:var(--color-espresso);">${escapeHtml(t.name || `Table ${idx + 1}`)}</strong>
          <span class="table-row-count-pill">${rowCount} row${rowCount === 1 ? '' : 's'}</span>
          <span class="table-col-count-pill">${cols.length} column${cols.length === 1 ? '' : 's'}</span>
        </div>
        <div class="table-card-subhead-right">
          ${rowCount > 0 ? `<input type="text" class="table-search-mini" data-card-idx="${idx}" placeholder="🔍 Filter rows...">` : ''}
          <button type="button" class="btn-action-sm" data-csv-idx="${idx}" style="font-size:10.5px; padding:3px 10px;">⬇ CSV</button>
        </div>
      </div>
      <div class="table-responsive" style="max-height: 380px;">
        <table class="pastel-table" id="card-table-${idx}">
          <thead>
            <tr>
              <th style="width:36px; text-align:center;">#</th>
              ${cols.map(c => `<th>${escapeHtml(c)}</th>`).join("")}
            </tr>
          </thead>
          <tbody>
            ${rowCount === 0 ? `
              <tr>
                <td colspan="${cols.length + 1}" style="padding:14px; text-align:center; color:var(--color-espresso-muted); font-style:italic;">
                  0 records returned for this table (schema defined with ${cols.length} column${cols.length === 1 ? '' : 's'}).
                </td>
              </tr>
            ` : rows.map((row, rIdx) => {
              const cells = row.map(cell => {
                const v = cell === null || cell === undefined ? '<span style="color:#aaa;">NULL</span>' : escapeHtml(String(cell));
                return `<td>${v}</td>`;
              }).join("");
              return `<tr><td style="text-align:center; color:var(--color-espresso-faint); font-size:10px;">${rIdx + 1}</td>${cells}</tr>`;
            }).join("")}
          </tbody>
        </table>
      </div>
    `;

    el.allTablesContainer.appendChild(card);

    // CSV export per table card
    const csvBtn = card.querySelector(`[data-csv-idx="${idx}"]`);
    if (csvBtn) {
      csvBtn.addEventListener("click", () => exportTableAsCsv(idx));
    }

    // Mini search filter per table card
    const searchInp = card.querySelector(`[data-card-idx="${idx}"]`);
    if (searchInp) {
      searchInp.addEventListener("input", (e) => {
        const query = e.target.value.toLowerCase().trim();
        const tbody = card.querySelector("tbody");
        if (!tbody) return;

        const filtered = query === "" ? rows : rows.filter(r => r.some(c => String(c).toLowerCase().includes(query)));
        if (filtered.length === 0) {
          tbody.innerHTML = `<tr><td colspan="${cols.length + 1}" style="padding:14px; text-align:center;">No matching records found.</td></tr>`;
          return;
        }
        tbody.innerHTML = filtered.map((row, rIdx) => {
          const cells = row.map(cell => {
            const v = cell === null || cell === undefined ? '<span style="color:#aaa;">NULL</span>' : escapeHtml(String(cell));
            return `<td>${v}</td>`;
          }).join("");
          return `<tr><td style="text-align:center; color:var(--color-espresso-faint); font-size:10px;">${rIdx + 1}</td>${cells}</tr>`;
        }).join("");
      });
    }
  });
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
      ${cols.map(c => `<th>${escapeHtml(c)}</th>`).join("")}
    </tr>
  `;

  if (filtered.length === 0) {
    el.dataTableBody.innerHTML = `<tr><td colspan="${cols.length + 1}" style="padding:16px; text-align:center;">No matching records found.</td></tr>`;
    return;
  }

  el.dataTableBody.innerHTML = filtered.map((row, rIdx) => {
    const cells = row.map(cell => {
      const v = cell === null || cell === undefined ? '<span style="color:#aaa;">NULL</span>' : escapeHtml(String(cell));
      return `<td>${v}</td>`;
    }).join("");
    return `<tr><td style="text-align:center; color:var(--color-espresso-faint); font-size:10px;">${rIdx + 1}</td>${cells}</tr>`;
  }).join("");
}

/**
 * CSV Export (Individual Table by Index)
 */
function exportTableAsCsv(idx) {
  const table = state.currentTables[idx];
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
  const name = (table.name || `table_${idx + 1}`).toLowerCase().replace(/[^a-z0-9]/g, "_");
  a.download = `${name}_export.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

/**
 * CSV Export (Active / All)
 */
function exportActiveTableAsCsv() {
  if (state.tableViewMode === "all" && state.currentTables.length > 0) {
    // Export each table with rows
    state.currentTables.forEach((t, i) => {
      if (t.rows && t.rows.length > 0) {
        setTimeout(() => exportTableAsCsv(i), i * 200);
      }
    });
  } else {
    exportTableAsCsv(state.activeTableIndex);
  }
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

  // Segmented OFF / ON tables toggle
  if (el.btnTablesOff) {
    el.btnTablesOff.addEventListener("click", () => setTablesVisibility(false));
  }
  if (el.btnTablesOn) {
    el.btnTablesOn.addEventListener("click", () => setTablesVisibility(true, true));
  }
  if (el.btnHideTablesCard) {
    el.btnHideTablesCard.addEventListener("click", () => {
      setTablesVisibility(false);
      if (el.resultsSection) {
        el.resultsSection.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });
  }

  // Table search
  el.tableSearchInput.addEventListener("input", (e) => {
    state.tableFilterQuery = e.target.value;
    renderActiveTableRows();
  });

  // Table view mode toggles
  if (el.btnViewAll) {
    el.btnViewAll.addEventListener("click", () => setTableViewMode("all"));
  }
  if (el.btnViewSingle) {
    el.btnViewSingle.addEventListener("click", () => setTableViewMode("single"));
  }
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
  return renderMarkdown(text);
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

  // 4. Line-by-line parser to cleanly isolate headings and list blocks
  const lines = text.split("\n");
  let html = "";
  let inUl = false;
  let inOl = false;

  function closeLists() {
    if (inUl) { html += "</ul>"; inUl = false; }
    if (inOl) { html += "</ol>"; inOl = false; }
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    if (!trimmed) {
      closeLists();
      continue;
    }

    if (trimmed.startsWith("@@CODEBLOCK_")) {
      closeLists();
      const idxMatch = trimmed.match(/@@CODEBLOCK_(\d+)@@/);
      if (idxMatch) {
        html += codeBlocks[parseInt(idxMatch[1], 10)] || "";
      }
      continue;
    }

    if (trimmed.startsWith("<table") || trimmed.startsWith("</table>") || trimmed.startsWith("<tr>") || trimmed.startsWith("<thead") || trimmed.startsWith("<tbody")) {
      closeLists();
      html += line;
      continue;
    }

    // Headings
    if (/^####\s+/.test(trimmed)) {
      closeLists();
      html += `<h4>${inlineMarkdown(trimmed.replace(/^####\s+/, ""))}</h4>`;
      continue;
    }
    if (/^###\s+/.test(trimmed)) {
      closeLists();
      html += `<h3>${inlineMarkdown(trimmed.replace(/^###\s+/, ""))}</h3>`;
      continue;
    }
    if (/^##\s+/.test(trimmed)) {
      closeLists();
      html += `<h2>${inlineMarkdown(trimmed.replace(/^##\s+/, ""))}</h2>`;
      continue;
    }
    if (/^#\s+/.test(trimmed)) {
      closeLists();
      html += `<h1>${inlineMarkdown(trimmed.replace(/^#\s+/, ""))}</h1>`;
      continue;
    }

    // Blockquote
    if (/^>\s?/.test(trimmed)) {
      closeLists();
      html += `<blockquote>${inlineMarkdown(trimmed.replace(/^>\s?/, ""))}</blockquote>`;
      continue;
    }

    // Unordered List item
    if (/^[-*]\s+/.test(trimmed)) {
      if (inOl) { html += "</ol>"; inOl = false; }
      if (!inUl) { html += "<ul>"; inUl = true; }
      html += `<li>${inlineMarkdown(trimmed.replace(/^[-*]\s+/, ""))}</li>`;
      continue;
    }

    // Ordered List item
    if (/^\d+\.\s+/.test(trimmed)) {
      if (inUl) { html += "</ul>"; inUl = false; }
      if (!inOl) { html += "<ol>"; inOl = true; }
      html += `<li>${inlineMarkdown(trimmed.replace(/^\d+\.\s+/, ""))}</li>`;
      continue;
    }

    // Normal paragraph line
    closeLists();
    html += `<p>${inlineMarkdown(trimmed)}</p>`;
  }

  closeLists();

  // Restore any placeholder that might remain
  html = html.replace(/@@CODEBLOCK_(\d+)@@/g, (_, idx) => codeBlocks[parseInt(idx, 10)] || "");
  return html;
}

