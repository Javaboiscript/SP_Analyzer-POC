/**
 * SP ANALYZER // ENTERPRISE AI STORED PROCEDURE CHATBOT
 * Full-screen conversational AI client communicating with FastAPI & Google Gemini
 */

// Application State
const state = {
  tools: [],
  selectedTool: null,
  selectedReport: null,
  selectedPrompt: null,
  messages: [],
  isAnalyzing: false,
  currentTables: [],
  activeTableIndex: 0,
  tableViewMode: "all",
  tableFilterQuery: "",
  companies: [],
  sidebarCollapsed: false
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

// DOM Elements Cache
const el = {
  // Sidebar
  chatSidebar: document.getElementById("chat-sidebar"),
  btnCollapseSidebar: document.getElementById("btn-collapse-sidebar"),
  btnExpandSidebar: document.getElementById("btn-expand-sidebar"),
  btnNewChat: document.getElementById("btn-new-chat"),
  sidebarToolList: document.getElementById("sidebar-tool-list"),
  sidebarReportsSection: document.getElementById("sidebar-reports-section"),
  sidebarReportsList: document.getElementById("sidebar-reports-list"),
  sidebarPresetsChips: document.getElementById("sidebar-presets-chips"),
  sidebarFormFields: document.getElementById("sidebar-form-fields"),
  btnResetParams: document.getElementById("btn-reset-params"),
  dbStatusBadge: document.getElementById("db-status-badge"),
  dbStatusDot: document.getElementById("db-status-dot"),
  dbStatusText: document.getElementById("db-status-text"),

  // Chat Header
  chatHeaderToolIcon: document.getElementById("chat-header-tool-icon"),
  chatHeaderToolTitle: document.getElementById("chat-header-tool-title"),
  chatHeaderSpBadge: document.getElementById("chat-header-sp-badge"),
  activeContextPill: document.getElementById("active-context-pill"),
  activeContextSummary: document.getElementById("active-context-summary"),
  btnHeaderViewTables: document.getElementById("btn-header-view-tables"),
  btnClearChat: document.getElementById("btn-clear-chat"),

  // Chat Stream
  chatStreamContainer: document.getElementById("chat-stream-container"),
  chatWelcomeHero: document.getElementById("chat-welcome-hero"),
  welcomeTitle: document.getElementById("welcome-title"),
  welcomeDescription: document.getElementById("welcome-description"),
  starterPromptsGrid: document.getElementById("starter-prompts-grid"),
  chatMessagesList: document.getElementById("chat-messages-list"),

  // Composer
  btnLensSelector: document.getElementById("btn-lens-selector"),
  composerSelectedLensLabel: document.getElementById("composer-selected-lens-label"),
  lensPopoverMenu: document.getElementById("lens-popover-menu"),
  lensMenuItems: document.getElementById("lens-menu-items"),
  composerContextTag: document.getElementById("composer-context-tag"),
  composerContextValue: document.getElementById("composer-context-value"),
  composerInput: document.getElementById("composer-input"),
  btnComposerSend: document.getElementById("btn-composer-send"),

  // SQL Modal
  sqlModalBackdrop: document.getElementById("sql-modal-backdrop"),
  modalResultSetsBadge: document.getElementById("modal-result-sets-badge"),
  modalBtnViewAll: document.getElementById("modal-btn-view-all"),
  modalBtnViewSingle: document.getElementById("modal-btn-view-single"),
  modalBtnExportCsv: document.getElementById("modal-btn-export-csv"),
  modalBtnClose: document.getElementById("modal-btn-close"),
  modalTableTabsContainer: document.getElementById("modal-table-tabs-container"),
  modalAllTablesContainer: document.getElementById("modal-all-tables-container"),
  modalSingleTableContainer: document.getElementById("modal-single-table-container"),
  modalTableSearchInput: document.getElementById("modal-table-search-input"),
  modalTableRowsInfo: document.getElementById("modal-table-rows-info"),
  modalDataTableHead: document.getElementById("modal-data-table-head"),
  modalDataTableBody: document.getElementById("modal-data-table-body")
};

// Initialize Application
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
    renderSidebarTools();

    // Select first tool by default
    if (state.tools.length > 0) {
      selectTool(state.tools[0].id);
    }
  } catch (err) {
    console.error("Failed to load tools registry:", err);
  }
}

/**
 * Render Sidebar Tools List
 */
function renderSidebarTools() {
  el.sidebarToolList.innerHTML = "";
  state.tools.forEach(tool => {
    const item = document.createElement("button");
    item.type = "button";
    item.className = "sidebar-tool-item";
    item.id = `sidebar-tool-${tool.id}`;
    item.innerHTML = `
      <span class="tool-icon">${tool.icon || "📋"}</span>
      <div class="tool-details">
        <span class="tool-title">${escapeHtml(tool.label)}</span>
        <span class="tool-sub">${escapeHtml(tool.storedProcedure || "")}</span>
      </div>
    `;
    item.addEventListener("click", () => selectTool(tool.id));
    el.sidebarToolList.appendChild(item);
  });
}

/**
 * Select Active Tool
 */
function selectTool(toolId) {
  const tool = state.tools.find(t => t.id === toolId);
  if (!tool) return;
  state.selectedTool = tool;

  // Highlight active in sidebar
  document.querySelectorAll(".sidebar-tool-item").forEach(item => item.classList.remove("active"));
  const activeBtn = document.getElementById(`sidebar-tool-${toolId}`);
  if (activeBtn) activeBtn.classList.add("active");

  // Check if tool has reports (e.g. report_analyzer)
  if (tool.reports && tool.reports.length > 0) {
    el.sidebarReportsSection.style.display = "flex";
    renderSidebarReports(tool);
    selectReport(tool.reports[0]);
  } else {
    el.sidebarReportsSection.style.display = "none";
    state.selectedReport = null;
    updateWorkspaceForTarget(tool);
  }
}

function renderSidebarReports(tool) {
  el.sidebarReportsList.innerHTML = "";
  (tool.reports || []).forEach((report, idx) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `sidebar-report-btn ${idx === 0 ? "active" : ""}`;
    btn.id = `sidebar-report-${report.id}`;
    btn.innerHTML = `<span>${report.icon || "📄"}</span> <span>${escapeHtml(report.label)}</span>`;
    btn.addEventListener("click", () => {
      document.querySelectorAll(".sidebar-report-btn").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      selectReport(report);
    });
    el.sidebarReportsList.appendChild(btn);
  });
}

function selectReport(report) {
  state.selectedReport = report;
  updateWorkspaceForTarget(report);
}

/**
 * Update UI for current tool/report target
 */
function updateWorkspaceForTarget(target) {
  // Update header titles
  el.chatHeaderToolIcon.textContent = target.icon || "📋";
  el.chatHeaderToolTitle.textContent = target.label;
  el.chatHeaderSpBadge.textContent = target.storedProcedure || "";

  // Welcome hero titles
  el.welcomeTitle.textContent = `${target.label} Assistant`;
  el.welcomeDescription.textContent = target.description || "Inspect stored procedure data and run specialized analytical reasoning with Gemini.";

  // Render Parameters & Presets in Sidebar
  renderSidebarPresets(target);
  renderSidebarParameters(target);

  // Setup prompt lenses
  setupPromptLenses(target);

  // Update context pills in header & composer
  updateContextSummary();

  // Reset to welcome view if no messages
  if (state.messages.length === 0) {
    el.chatWelcomeHero.style.display = "flex";
  }
}

/**
 * Render Presets in Sidebar
 */
function renderSidebarPresets(target) {
  el.sidebarPresetsChips.innerHTML = "";
  const toolId = typeof target === "string" ? target : (target ? target.id : "");
  const presets = (target && target.presets) ? target.presets : (TOOL_PRESETS[toolId] || []);

  if (presets.length === 0) {
    el.sidebarPresetsChips.innerHTML = `<span style="font-size:10px; color:var(--color-espresso-faint);">No presets configured.</span>`;
    return;
  }

  presets.forEach(preset => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "preset-chip-btn";
    btn.textContent = preset.name;
    btn.addEventListener("click", () => {
      applyPresetValues(preset.values);
      updateContextSummary();
    });
    el.sidebarPresetsChips.appendChild(btn);
  });
}

function applyPresetValues(values) {
  Object.entries(values).forEach(([key, val]) => {
    const input = document.getElementById(`param-${key}`);
    if (input) {
      input.value = val === null || val === undefined ? "" : val;
      input.style.backgroundColor = "var(--color-terracotta-light)";
      setTimeout(() => { input.style.backgroundColor = ""; }, 350);
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
 * Render Sidebar Parameters Form
 */
function renderSidebarParameters(target) {
  el.sidebarFormFields.innerHTML = "";
  const params = target.params || [];

  if (params.length === 0) {
    el.sidebarFormFields.innerHTML = `<div style="font-size:11px; color:var(--color-espresso-muted);">No input parameters required.</div>`;
    return;
  }

  params.forEach(param => {
    const item = document.createElement("div");
    item.className = "form-item";

    if (param.type === "select") {
      let optionsHtml = '';
      if (param.options && param.options.length > 0) {
        optionsHtml = param.options.map(opt => {
          const isSel = (param.default !== null && param.default !== undefined && String(param.default) === String(opt.value)) ? "selected" : "";
          return `<option value="${opt.value}" ${isSel}>${escapeHtml(opt.label)}</option>`;
        }).join("");
      } else {
        optionsHtml = `<option value="">-- All Companies (None) --</option>`;
      }

      item.innerHTML = `
        <div class="form-item-header">
          <label class="form-item-label" for="param-${param.name}">${param.label || param.name}</label>
          ${param.required ? '<span class="tag-required">REQ</span>' : '<span class="tag-optional">OPT</span>'}
        </div>
        <select id="param-${param.name}" name="${param.name}" class="minimal-input select-dropdown">
          ${optionsHtml}
        </select>
        <div class="example-hint">
          <span>${param.description ? truncate(param.description, 35) : ''}</span>
          <span class="example-fill" data-clear="param-${param.name}">Reset</span>
        </div>
      `;
      el.sidebarFormFields.appendChild(item);

      const clearBtn = item.querySelector("[data-clear]");
      if (clearBtn) {
        clearBtn.addEventListener("click", () => {
          const sel = document.getElementById(`param-${param.name}`);
          if (sel) {
            sel.value = param.default !== undefined && param.default !== null ? String(param.default) : "";
            updateContextSummary();
          }
        });
      }

      if (param.optionsUrl) {
        fetchCompanies().then(companies => {
          const selectEl = document.getElementById(`param-${param.name}`);
          if (!selectEl) return;
          selectEl.innerHTML = `<option value="">-- All Companies (None) --</option>`;
          companies.forEach(c => {
            const opt = document.createElement("option");
            opt.value = c.value;
            opt.textContent = `${c.name || 'Company ' + c.value} (ID: ${c.value})`;
            if (param.default !== null && String(c.value) === String(param.default)) {
              opt.selected = true;
            }
            selectEl.appendChild(opt);
          });
          updateContextSummary();
        });
      }

      const selectEl = item.querySelector("select");
      if (selectEl) {
        selectEl.addEventListener("change", updateContextSummary);
      }
    } else {
      // Text or int input
      const defVal = (param.default !== undefined && param.default !== null) ? param.default : "";
      item.innerHTML = `
        <div class="form-item-header">
          <label class="form-item-label" for="param-${param.name}">${param.label || param.name}</label>
          ${param.required ? '<span class="tag-required">REQ</span>' : '<span class="tag-optional">OPT</span>'}
        </div>
        <input 
          type="${param.type === 'int' ? 'number' : 'text'}" 
          id="param-${param.name}" 
          name="${param.name}" 
          value="${defVal}"
          class="minimal-input" 
          placeholder="${param.description ? truncate(param.description, 32) : ''}"
        />
        <div class="example-hint">
          <span>${param.default ? 'Default: ' + param.default : ''}</span>
          <span class="example-fill" data-clear="param-${param.name}">Clear</span>
        </div>
      `;
      el.sidebarFormFields.appendChild(item);

      const inputEl = item.querySelector("input");
      if (inputEl) {
        inputEl.addEventListener("input", updateContextSummary);
      }

      const clearBtn = item.querySelector("[data-clear]");
      if (clearBtn) {
        clearBtn.addEventListener("click", () => {
          const inp = document.getElementById(`param-${param.name}`);
          if (inp) {
            inp.value = "";
            updateContextSummary();
          }
        });
      }
    }
  });

  updateContextSummary();
}

/**
 * Setup Analytical Prompt Lenses & Starter Grid
 */
function setupPromptLenses(target) {
  const prompts = target.prompts || [];
  el.starterPromptsGrid.innerHTML = "";
  el.lensMenuItems.innerHTML = "";

  // 1. Starter Prompts on Welcome Screen
  prompts.forEach((p, idx) => {
    const card = document.createElement("div");
    card.className = "starter-prompt-card";
    card.innerHTML = `
      <div class="starter-card-head">
        <span class="starter-card-icon">${getPromptIcon(p.id)}</span>
        <div>
          <div class="starter-card-title">${escapeHtml(p.label)}</div>
          <div class="starter-card-desc">${escapeHtml(p.description || "")}</div>
        </div>
      </div>
      <div class="starter-card-foot">
        <span class="starter-card-param" id="starter-card-param-${idx}">PO #1644</span>
        <span class="starter-card-action">Run Analysis ➤</span>
      </div>
    `;

    card.addEventListener("click", () => {
      selectPromptLens(p);
      triggerAnalysis();
    });

    el.starterPromptsGrid.appendChild(card);
  });

  // 2. Populate Composer Lens Popover Menu
  prompts.forEach(p => {
    const item = document.createElement("div");
    item.className = "lens-menu-item";
    item.id = `lens-item-${p.id}`;
    item.innerHTML = `
      <div class="lens-item-title">${getPromptIcon(p.id)} ${escapeHtml(p.label)}</div>
      <div class="lens-item-desc">${escapeHtml(p.description || "")}</div>
    `;
    item.addEventListener("click", () => {
      selectPromptLens(p);
      el.lensPopoverMenu.style.display = "none";
    });
    el.lensMenuItems.appendChild(item);
  });

  // Custom Prompt option
  const customItem = document.createElement("div");
  customItem.className = "lens-menu-item";
  customItem.id = "lens-item-custom";
  customItem.innerHTML = `
    <div class="lens-item-title">✍️ Custom Free-form Analysis</div>
    <div class="lens-item-desc">Direct LLM reasoning with unconstrained analytical inquiry.</div>
  `;
  customItem.addEventListener("click", () => {
    selectPromptLens({ id: "custom", label: "Custom Free-form Analysis", isCustom: true });
    el.lensPopoverMenu.style.display = "none";
  });
  el.lensMenuItems.appendChild(customItem);

  // Set default prompt lens
  if (prompts.length > 0) {
    selectPromptLens(prompts[0]);
  } else {
    selectPromptLens({ id: "custom", label: "Custom Free-form Analysis", isCustom: true });
  }
}

function selectPromptLens(prompt) {
  state.selectedPrompt = prompt;
  el.composerSelectedLensLabel.textContent = prompt.label;

  // Highlight in popover menu
  document.querySelectorAll(".lens-menu-item").forEach(item => item.classList.remove("active"));
  const activeItem = document.getElementById(`lens-item-${prompt.id}`);
  if (activeItem) activeItem.classList.add("active");

  // Adjust placeholder
  if (prompt.id === "custom") {
    el.composerInput.placeholder = "Type your custom inquiry or analysis instructions... (Press Enter to send)";
  } else {
    el.composerInput.placeholder = `Run "${prompt.label}" (add specific questions or press Enter)...`;
  }
}

function getPromptIcon(promptId) {
  if (promptId.includes("health") || promptId.includes("lifecycle")) return "📋";
  if (promptId.includes("delivery") || promptId.includes("lead_time")) return "⏱️";
  if (promptId.includes("quality") || promptId.includes("rejection")) return "🔍";
  if (promptId.includes("three_way") || promptId.includes("matching")) return "⚖️";
  if (promptId.includes("purchase_head")) return "👔";
  return "✨";
}

/**
 * Update Context Summary (PO #, Company)
 */
function updateContextSummary() {
  const params = collectParameters();
  let summary = "";

  if (params.PONo) {
    summary = `PO #${params.PONo}`;
  } else if (params.PONoYearly) {
    summary = `Doc: ${params.PONoYearly}`;
  } else if (params.FromDate && params.ToDate) {
    summary = `${params.FromDate} → ${params.ToDate}`;
  } else {
    summary = state.selectedTool ? state.selectedTool.label : "Active";
  }

  if (params.CompanyNo) {
    summary += ` | Co: ${params.CompanyNo}`;
  }

  el.activeContextSummary.textContent = summary;
  el.composerContextValue.textContent = summary;

  // Update starter cards params
  document.querySelectorAll("[id^='starter-card-param-']").forEach(p => {
    p.textContent = summary;
  });
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
 * 3. Conversational Message Execution
 */
async function triggerAnalysis(customQueryText = null) {
  if (state.isAnalyzing) return;
  if (!state.selectedTool || !state.selectedPrompt) return;

  const isCustom = state.selectedPrompt.id === "custom";
  const userText = customQueryText !== null ? customQueryText : el.composerInput.value.trim();

  if (isCustom && !userText) {
    el.composerInput.focus();
    el.composerInput.style.backgroundColor = "var(--color-rust-light)";
    setTimeout(() => { el.composerInput.style.backgroundColor = ""; }, 500);
    return;
  }

  state.isAnalyzing = true;
  el.btnComposerSend.disabled = true;

  // Hide welcome hero on first message
  el.chatWelcomeHero.style.display = "none";

  // 1. Append User Message Bubble
  const currentParams = collectParameters();
  const promptLabel = state.selectedPrompt.label;
  const userDisplayText = userText || `Execute ${promptLabel}`;
  appendUserMessage(userDisplayText, promptLabel, currentParams);

  // Clear composer input
  el.composerInput.value = "";
  autoResizeTextarea(el.composerInput);

  // 2. Append Typing Indicator Bubble
  const typingId = appendTypingIndicator();
  scrollStreamToBottom();

  const payload = {
    toolId: state.selectedTool.id,
    reportId: state.selectedReport ? state.selectedReport.id : null,
    promptId: isCustom ? "custom" : state.selectedPrompt.id,
    params: currentParams,
    custom_input: isCustom ? userDisplayText : (userText || null)
  };

  try {
    const res = await fetch("/api/analyze", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    const data = await res.json();
    removeTypingIndicator(typingId);
    state.isAnalyzing = false;
    el.btnComposerSend.disabled = false;

    if (!res.ok || data.success === false) {
      appendErrorMessage(data.error || "Analysis Failed", data.detail || JSON.stringify(data, null, 2));
      scrollStreamToBottom();
      return;
    }

    // Save tables in state for global viewer
    if (data.tables && data.tables.length > 0) {
      state.currentTables = data.tables;
      el.btnHeaderViewTables.style.display = "inline-flex";
    }

    // 3. Append Assistant Rich Response Card
    appendAssistantMessage(data, promptLabel, currentParams);
    scrollStreamToBottom();
  } catch (err) {
    removeTypingIndicator(typingId);
    state.isAnalyzing = false;
    el.btnComposerSend.disabled = false;
    appendErrorMessage("Network/Execution Error", err.message);
    scrollStreamToBottom();
  }
}

/**
 * Message Stream Renderers
 */
function appendUserMessage(text, lensName, params) {
  const row = document.createElement("div");
  row.className = "chat-message-row user";

  let paramBadge = "";
  if (params.PONo) paramBadge = `PO #${params.PONo}`;
  else if (params.PONoYearly) paramBadge = `Doc: ${params.PONoYearly}`;
  else if (params.FromDate) paramBadge = `${params.FromDate} → ${params.ToDate}`;

  row.innerHTML = `
    <div class="user-bubble">
      <div class="user-bubble-header">
        <span class="user-badge-lens">${escapeHtml(lensName)}</span>
        ${paramBadge ? `<span class="user-badge-param">${escapeHtml(paramBadge)}</span>` : ""}
      </div>
      <div class="user-bubble-text">${escapeHtml(text)}</div>
    </div>
    <div class="chat-avatar user-avatar">👤</div>
  `;

  el.chatMessagesList.appendChild(row);
  state.messages.push({ role: "user", text, lensName, params });
}

function appendTypingIndicator() {
  const id = `typing-${Date.now()}`;
  const row = document.createElement("div");
  row.className = "chat-message-row bot typing-indicator-msg";
  row.id = id;

  const spName = (state.selectedReport || state.selectedTool).storedProcedure || "Stored Procedure";

  row.innerHTML = `
    <div class="chat-avatar bot-avatar">🔬</div>
    <div class="chat-message-content">
      <div class="typing-bubble">
        <div class="typing-dots">
          <span></span><span></span><span></span>
        </div>
        <span class="typing-status-text">Querying ${escapeHtml(spName)} on SQL Server & synthesizing Gemini insights...</span>
      </div>
    </div>
  `;

  el.chatMessagesList.appendChild(row);
  return id;
}

function removeTypingIndicator(id) {
  const row = document.getElementById(id);
  if (row) row.remove();
}

function appendErrorMessage(title, detail) {
  const row = document.createElement("div");
  row.className = "chat-message-row bot";
  row.innerHTML = `
    <div class="chat-avatar bot-avatar">⚠️</div>
    <div class="chat-message-content">
      <div class="error-bubble">
        <div class="error-bubble-title">Execution Error: ${escapeHtml(title)}</div>
        <div class="error-bubble-detail">${escapeHtml(detail)}</div>
      </div>
    </div>
  `;
  el.chatMessagesList.appendChild(row);
}

function appendAssistantMessage(data, promptLabel, params) {
  const row = document.createElement("div");
  row.className = "chat-message-row bot";

  const meta = data.metadata || {};
  const msgId = `msg-${Date.now()}`;
  const tableCount = meta.table_count || (data.tables ? data.tables.length : 0);

  // Build Assistant Message Content
  const container = document.createElement("div");
  container.className = "chat-message-content";

  const wrapper = document.createElement("div");
  wrapper.className = "bot-message-wrapper";

  // Meta stats bar
  const metaBar = document.createElement("div");
  metaBar.className = "bot-meta-bar";
  metaBar.innerHTML = `
    <div class="bot-meta-left">
      <span class="bot-meta-title">★ Gemini Executive Reasoning</span>
      <div class="bot-stat-group">
        <span class="stat-pill">SQL: <strong>${meta.sql_execution_time_ms || 0} ms</strong></span>
        <span class="stat-pill">AI: <strong>${meta.ai_latency_ms || 0} ms</strong></span>
        <span class="stat-pill">Rows: <strong>${meta.total_rows || 0}</strong></span>
        <span class="stat-pill">Tables: <strong>${tableCount}</strong></span>
      </div>
    </div>
    <div class="bot-actions-right">
      ${tableCount > 0 ? `<button type="button" class="btn-action-outline btn-msg-tables" data-msg-id="${msgId}">📊 SQL Tables (${tableCount})</button>` : ""}
      <button type="button" class="btn-action-sm btn-msg-copy" data-msg-id="${msgId}">📋 Copy Briefing</button>
    </div>
  `;
  wrapper.appendChild(metaBar);

  // If custom raw unconstrained analysis
  if (data.raw_analysis) {
    const rawBox = document.createElement("div");
    rawBox.className = "raw-analysis-container";
    rawBox.innerHTML = `<div class="raw-analysis-content">${renderMarkdown(data.raw_analysis)}</div>`;
    wrapper.appendChild(rawBox);
  } else {
    // Structured Analysis Output
    const analysis = data.analysis || {};

    // 1. Custom response card (if custom question answered)
    if (analysis.custom_response && analysis.custom_response.trim()) {
      const customCard = document.createElement("div");
      customCard.className = "custom-response-card";
      customCard.innerHTML = `
        <div style="display:flex; align-items:center; gap:8px; margin-bottom:8px;">
          <span style="font-size:16px;">💬</span>
          <strong style="color:var(--color-forest); font-size:12px; text-transform:uppercase; letter-spacing:0.04em;">Answer to Custom Inquiry</strong>
        </div>
        <div style="font-size:13.5px; color:var(--color-espresso); line-height:1.55;">
          ${formatParagraphs(analysis.custom_response)}
        </div>
      `;
      wrapper.appendChild(customCard);
    }

    // 2. Executive Narrative Summary
    if (analysis.executive_summary) {
      const narrativeCard = document.createElement("div");
      narrativeCard.className = "narrative-card";
      narrativeCard.innerHTML = formatParagraphs(analysis.executive_summary);
      wrapper.appendChild(narrativeCard);
    }

    // 3. KPI Metrics Deck
    if (analysis.key_metrics && analysis.key_metrics.length > 0) {
      const metricsDeck = document.createElement("div");
      metricsDeck.className = "metrics-deck";
      const themes = ["lavender", "sky", "mint", "butter", "peach"];

      analysis.key_metrics.forEach((m, idx) => {
        const theme = themes[idx % themes.length];
        const card = document.createElement("div");
        card.className = `metric-pill-card ${theme}`;
        card.innerHTML = `
          <div class="metric-pill-label">${escapeHtml(m.label)}</div>
          <div class="metric-pill-val">${escapeHtml(m.value)}</div>
          ${m.trend ? `<div class="metric-pill-trend">${escapeHtml(m.trend)}</div>` : ""}
        `;
        metricsDeck.appendChild(card);
      });
      wrapper.appendChild(metricsDeck);
    }

    // 4. Line-Level Breakdown Matrix Table
    if (analysis.breakdown_table && analysis.breakdown_table.length > 0) {
      const breakdownRows = analysis.breakdown_table;
      const first = breakdownRows[0];
      const h1 = first.col1_label || "Metric 1";
      const h2 = first.col2_label || "Metric 2";
      const h3 = first.col3_label || "Metric 3";

      const breakdownCard = document.createElement("div");
      breakdownCard.className = "breakdown-card";
      breakdownCard.innerHTML = `
        <div class="breakdown-card-header">
          <div class="breakdown-card-title">
            <span>📊 Line-Level & Fulfillment Breakdown</span>
            <span class="table-row-count-pill">${breakdownRows.length} items</span>
          </div>
        </div>
        <div class="breakdown-table-wrapper">
          <table class="breakdown-data-table">
            <thead>
              <tr>
                <th style="min-width: 170px;">Item / Scope</th>
                <th>${escapeHtml(h1)}</th>
                <th>${escapeHtml(h2)}</th>
                <th>${escapeHtml(h3)}</th>
                <th style="text-align: right; min-width: 110px;">Status / Flag</th>
              </tr>
            </thead>
            <tbody>
              ${breakdownRows.map(r => {
                const tag = (r.status_tag || "").toUpperCase();
                let tagClass = "tag-info";
                if (["COMPLETED", "MATCHED", "ON_TIME", "ACCEPTED", "FULLY_RECEIVED"].some(s => tag.includes(s))) tagClass = "tag-success";
                else if (["PENDING", "WAITING", "UNBILLED", "PARTIAL"].some(s => tag.includes(s))) tagClass = "tag-warning";
                else if (["OVERDUE", "REJECTED", "CANCELLED", "DELAYED"].some(s => tag.includes(s))) tagClass = "tag-danger";

                return `
                  <tr>
                    <td><strong>${escapeHtml(r.item_or_category || "—")}</strong></td>
                    <td>${escapeHtml(r.col1_value || "—")}</td>
                    <td>${escapeHtml(r.col2_value || "—")}</td>
                    <td>${escapeHtml(r.col3_value || "—")}</td>
                    <td style="text-align: right;">
                      ${tag ? `<span class="breakdown-status-badge ${tagClass}">${escapeHtml(tag)}</span>` : "—"}
                    </td>
                  </tr>
                `;
              }).join("")}
            </tbody>
          </table>
        </div>
      `;
      wrapper.appendChild(breakdownCard);
    }

    // 5. Findings & Recommendations Deck
    const hasFindings = analysis.findings && analysis.findings.length > 0;
    const hasRecs = analysis.recommendations && analysis.recommendations.length > 0;

    if (hasFindings || hasRecs) {
      const insightsDeck = document.createElement("div");
      insightsDeck.className = "insights-deck";

      // Findings
      const findingsSub = document.createElement("div");
      findingsSub.className = "insight-subcard";
      findingsSub.innerHTML = `
        <div class="insight-subcard-title">
          <span>🔍 Key Findings & Risk Items</span>
          <span style="font-size:11px; color:var(--color-espresso-muted);">${(analysis.findings || []).length}</span>
        </div>
        <div class="finding-pill-row">
          ${(analysis.findings || []).map(f => {
            const sev = (f.severity || "info").toLowerCase();
            return `
              <div class="finding-bubble ${sev}">
                <div class="finding-bubble-header">
                  <strong>${escapeHtml(f.title)}</strong>
                  <span class="finding-tag">${escapeHtml(sev)}</span>
                </div>
                <p>${escapeHtml(f.description)}</p>
              </div>
            `;
          }).join("") || `<span style="font-size:12px; color:var(--color-espresso-muted);">No risk findings identified.</span>`}
        </div>
      `;
      insightsDeck.appendChild(findingsSub);

      // Recommendations
      const recsSub = document.createElement("div");
      recsSub.className = "insight-subcard";
      recsSub.innerHTML = `
        <div class="insight-subcard-title">
          <span>🎯 Actionable Recommendations</span>
          <span style="font-size:11px; color:var(--color-espresso-muted);">${(analysis.recommendations || []).length}</span>
        </div>
        <div class="finding-pill-row">
          ${(analysis.recommendations || []).map(r => {
            const pri = (r.priority || "medium").toLowerCase();
            return `
              <div class="rec-bubble">
                <div class="rec-bubble-top">
                  <span class="rec-bubble-action">${escapeHtml(r.action)}</span>
                  <span class="rec-priority-badge ${pri}">${escapeHtml(pri)}</span>
                </div>
                ${r.expected_impact ? `<div style="font-size:11px; color:var(--color-espresso-muted); margin-top:3px;">${escapeHtml(r.expected_impact)}</div>` : ""}
              </div>
            `;
          }).join("") || `<span style="font-size:12px; color:var(--color-espresso-muted);">No specific actions recommended.</span>`}
        </div>
      `;
      insightsDeck.appendChild(recsSub);

      wrapper.appendChild(insightsDeck);
    }

    // Supplementary Notes
    if (analysis.additional_notes) {
      const notesBox = document.createElement("div");
      notesBox.className = "supplementary-notes-box";
      notesBox.innerHTML = `<strong>📝 Notes:</strong> ${escapeHtml(analysis.additional_notes)}`;
      wrapper.appendChild(notesBox);
    }
  }

  // Follow-up Suggestion Chips at bottom of message
  const prompts = (state.selectedReport || state.selectedTool).prompts || [];
  if (prompts.length > 1) {
    const followupRow = document.createElement("div");
    followupRow.className = "followup-chips-row";
    followupRow.innerHTML = `<span class="followup-caption">Follow-up Analysis:</span>`;

    prompts.forEach(p => {
      if (p.label !== promptLabel) {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "followup-chip-btn";
        btn.textContent = `${getPromptIcon(p.id)} ${p.label}`;
        btn.addEventListener("click", () => {
          selectPromptLens(p);
          triggerAnalysis();
        });
        followupRow.appendChild(btn);
      }
    });
    wrapper.appendChild(followupRow);
  }

  container.appendChild(wrapper);

  row.innerHTML = `<div class="chat-avatar bot-avatar">🔬</div>`;
  row.appendChild(container);

  // Attach event listener to Copy Briefing button
  const copyBtn = row.querySelector(".btn-msg-copy");
  if (copyBtn) {
    copyBtn.addEventListener("click", () => {
      copyAnalysisToClipboard(data, copyBtn);
    });
  }

  // Attach event listener to View SQL Tables button
  const tablesBtn = row.querySelector(".btn-msg-tables");
  if (tablesBtn && data.tables) {
    tablesBtn.addEventListener("click", () => {
      openSqlModal(data.tables);
    });
  }

  el.chatMessagesList.appendChild(row);
  state.messages.push({ role: "assistant", data, promptLabel, params });
}

function copyAnalysisToClipboard(data, buttonEl) {
  const parts = [];
  const meta = data.metadata || {};
  parts.push(`=== SP ANALYZER EXECUTIVE BRIEFING ===`);
  parts.push(`Tool: ${(state.selectedReport || state.selectedTool).label}`);
  parts.push(`SQL Duration: ${meta.sql_execution_time_ms || 0} ms | AI Latency: ${meta.ai_latency_ms || 0} ms | Rows: ${meta.total_rows || 0}`);
  parts.push(``);

  if (data.raw_analysis) {
    parts.push(data.raw_analysis);
  } else if (data.analysis) {
    const a = data.analysis;
    if (a.executive_summary) {
      parts.push(`--- EXECUTIVE SUMMARY ---\n${a.executive_summary}\n`);
    }
    if (a.key_metrics && a.key_metrics.length > 0) {
      parts.push(`--- KEY METRICS ---`);
      a.key_metrics.forEach(m => parts.push(`- ${m.label}: ${m.value} ${m.trend || ''}`));
      parts.push(``);
    }
    if (a.findings && a.findings.length > 0) {
      parts.push(`--- FINDINGS ---`);
      a.findings.forEach(f => parts.push(`[${f.severity || 'INFO'}] ${f.title}: ${f.description}`));
      parts.push(``);
    }
    if (a.recommendations && a.recommendations.length > 0) {
      parts.push(`--- RECOMMENDATIONS ---`);
      a.recommendations.forEach(r => parts.push(`[${r.priority || 'MED'}] ${r.action}`));
      parts.push(``);
    }
  }

  navigator.clipboard.writeText(parts.join("\n")).then(() => {
    buttonEl.textContent = "✓ Copied";
    setTimeout(() => { buttonEl.textContent = "📋 Copy Briefing"; }, 1500);
  }).catch(() => {
    buttonEl.textContent = "✓ Copied";
    setTimeout(() => { buttonEl.textContent = "📋 Copy Briefing"; }, 1500);
  });
}

/**
 * 4. SQL Result Sets Modal Viewer
 */
function openSqlModal(tables) {
  state.currentTables = tables || [];
  el.modalResultSetsBadge.textContent = `${state.currentTables.length} Tables`;
  el.sqlModalBackdrop.style.display = "flex";
  renderModalSqlTables(state.currentTables);
}

function closeSqlModal() {
  el.sqlModalBackdrop.style.display = "none";
}

function renderModalSqlTables(tables) {
  el.modalTableTabsContainer.innerHTML = "";
  el.modalAllTablesContainer.innerHTML = "";

  if (tables.length === 0) {
    el.modalAllTablesContainer.innerHTML = `<div style="padding:24px; text-align:center; color:var(--color-espresso-muted);">No records returned by stored procedure.</div>`;
    return;
  }

  state.activeTableIndex = 0;

  // Navigation tab chips
  tables.forEach((t, idx) => {
    const chip = document.createElement("button");
    chip.type = "button";
    chip.className = `table-tab-chip ${idx === 0 ? "active" : ""}`;
    chip.innerHTML = `
      <span>${escapeHtml(t.name || `Table ${idx + 1}`)}</span>
      <span class="table-row-count-pill">${t.row_count || (t.rows ? t.rows.length : 0)}</span>
    `;

    chip.addEventListener("click", () => {
      state.activeTableIndex = idx;
      document.querySelectorAll("#modal-table-tabs-container .table-tab-chip").forEach(c => c.classList.remove("active"));
      chip.classList.add("active");

      if (state.tableViewMode === "all") {
        const targetCard = document.getElementById(`modal-table-card-${idx}`);
        if (targetCard) targetCard.scrollIntoView({ behavior: "smooth", block: "start" });
      } else {
        renderModalActiveSingleTable();
      }
    });

    el.modalTableTabsContainer.appendChild(chip);
  });

  renderModalAllTablesStacked(tables);
  renderModalActiveSingleTable();
  setModalTableViewMode(state.tableViewMode || "all");
}

function setModalTableViewMode(mode) {
  state.tableViewMode = mode;
  if (mode === "all") {
    el.modalBtnViewAll.classList.add("active");
    el.modalBtnViewSingle.classList.remove("active");
    el.modalAllTablesContainer.style.display = "flex";
    el.modalSingleTableContainer.style.display = "none";
  } else {
    el.modalBtnViewSingle.classList.add("active");
    el.modalBtnViewAll.classList.remove("active");
    el.modalAllTablesContainer.style.display = "none";
    el.modalSingleTableContainer.style.display = "block";
    renderModalActiveSingleTable();
  }
}

function renderModalAllTablesStacked(tables) {
  el.modalAllTablesContainer.innerHTML = "";
  tables.forEach((t, idx) => {
    const cols = t.columns || [];
    const rows = t.rows || [];
    const rowCount = t.row_count !== undefined ? t.row_count : rows.length;

    const card = document.createElement("div");
    card.className = "table-individual-card";
    card.id = `modal-table-card-${idx}`;
    card.innerHTML = `
      <div class="table-card-subhead">
        <div class="table-card-subhead-left">
          <span class="table-idx-badge">Table ${idx + 1}</span>
          <strong>${escapeHtml(t.name || `Table ${idx + 1}`)}</strong>
          <span class="table-row-count-pill">${rowCount} rows</span>
          <span class="table-col-count-pill">${cols.length} cols</span>
        </div>
        <div class="table-card-subhead-right">
          ${rowCount > 0 ? `<input type="text" class="table-search-mini" data-card-idx="${idx}" placeholder="🔍 Filter rows...">` : ''}
          <button type="button" class="btn-action-sm" data-csv-idx="${idx}">⬇ CSV</button>
        </div>
      </div>
      <div class="table-responsive">
        <table class="pastel-table" id="modal-subtable-${idx}">
          <thead>
            <tr>${cols.map(c => `<th>${escapeHtml(c)}</th>`).join("")}</tr>
          </thead>
          <tbody>
            ${rows.slice(0, 50).map(r => `<tr>${cols.map(c => `<td>${escapeHtml(r[c] !== null && r[c] !== undefined ? String(r[c]) : '—')}</td>`).join("")}</tr>`).join("")}
          </tbody>
        </table>
      </div>
      ${rows.length > 50 ? `<div style="padding:6px 14px; font-size:10.5px; color:var(--color-espresso-faint); background:var(--color-linen-light);">Showing first 50 of ${rowCount} rows. Switch to Single Table mode or Export CSV for full data.</div>` : ''}
    `;

    // CSV button handler
    const csvBtn = card.querySelector(`[data-csv-idx="${idx}"]`);
    if (csvBtn) {
      csvBtn.addEventListener("click", () => exportTableCsv(t));
    }

    // Mini search handler
    const miniSearch = card.querySelector(`[data-card-idx="${idx}"]`);
    if (miniSearch) {
      miniSearch.addEventListener("input", (e) => {
        filterStackedTableRows(idx, t, e.target.value.toLowerCase().trim());
      });
    }

    el.modalAllTablesContainer.appendChild(card);
  });
}

function filterStackedTableRows(idx, table, query) {
  const tbody = document.querySelector(`#modal-subtable-${idx} tbody`);
  if (!tbody) return;
  const cols = table.columns || [];
  const rows = table.rows || [];

  const filtered = query ? rows.filter(r => cols.some(c => String(r[c] || "").toLowerCase().includes(query))) : rows.slice(0, 50);

  tbody.innerHTML = filtered.map(r => `
    <tr>${cols.map(c => `<td>${escapeHtml(r[c] !== null && r[c] !== undefined ? String(r[c]) : '—')}</td>`).join("")}</tr>
  `).join("") || `<tr><td colspan="${cols.length}" style="text-align:center; padding:12px;">No matching rows found.</td></tr>`;
}

function renderModalActiveSingleTable() {
  const table = state.currentTables[state.activeTableIndex];
  if (!table) return;

  const cols = table.columns || [];
  const rows = table.rows || [];

  el.modalDataTableHead.innerHTML = `<tr>${cols.map(c => `<th>${escapeHtml(c)}</th>`).join("")}</tr>`;

  const query = (el.modalTableSearchInput.value || "").toLowerCase().trim();
  const filtered = query ? rows.filter(r => cols.some(c => String(r[c] || "").toLowerCase().includes(query))) : rows;

  el.modalTableRowsInfo.textContent = `Showing ${filtered.length} of ${rows.length} rows`;

  el.modalDataTableBody.innerHTML = filtered.slice(0, 200).map(r => `
    <tr>${cols.map(c => `<td>${escapeHtml(r[c] !== null && r[c] !== undefined ? String(r[c]) : '—')}</td>`).join("")}</tr>
  `).join("") || `<tr><td colspan="${cols.length}" style="text-align:center; padding:16px;">No rows matching search.</td></tr>`;
}

function exportTableCsv(table) {
  if (!table || !table.rows || table.rows.length === 0) return;
  const cols = table.columns || [];
  const lines = [cols.map(c => `"${String(c).replace(/"/g, '""')}"`).join(",")];

  table.rows.forEach(r => {
    lines.push(cols.map(c => {
      const val = r[c];
      return `"${val !== null && val !== undefined ? String(val).replace(/"/g, '""') : ''}"`;
    }).join(","));
  });

  const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${table.name || "sql_result"}_${Date.now()}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

/**
 * 5. Event Listeners & Interactions
 */
function attachEventListeners() {
  // Sidebar Collapse / Expand
  el.btnCollapseSidebar.addEventListener("click", () => {
    el.chatSidebar.classList.add("collapsed");
    el.btnExpandSidebar.style.display = "flex";
  });

  el.btnExpandSidebar.addEventListener("click", () => {
    el.chatSidebar.classList.remove("collapsed");
    el.btnExpandSidebar.style.display = "none";
  });

  // New Chat / Clear
  el.btnNewChat.addEventListener("click", resetConversation);
  el.btnClearChat.addEventListener("click", resetConversation);

  // Active Context Pill click opens sidebar
  el.activeContextPill.addEventListener("click", () => {
    el.chatSidebar.classList.remove("collapsed");
    el.btnExpandSidebar.style.display = "none";
  });

  // Reset Parameters button
  el.btnResetParams.addEventListener("click", () => {
    const activeObj = state.selectedReport || state.selectedTool;
    if (!activeObj) return;
    (activeObj.params || []).forEach(p => {
      const inp = document.getElementById(`param-${p.name}`);
      if (inp) inp.value = p.default !== undefined && p.default !== null ? String(p.default) : "";
    });
    updateContextSummary();
  });

  // Lens Popover Toggle
  el.btnLensSelector.addEventListener("click", (e) => {
    e.stopPropagation();
    const isVisible = el.lensPopoverMenu.style.display === "flex";
    el.lensPopoverMenu.style.display = isVisible ? "none" : "flex";
  });

  document.addEventListener("click", (e) => {
    if (!e.target.closest(".lens-dropdown-wrapper")) {
      el.lensPopoverMenu.style.display = "none";
    }
  });

  // Composer Input auto-expand and Enter key submission
  el.composerInput.addEventListener("input", () => {
    autoResizeTextarea(el.composerInput);
  });

  el.composerInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      triggerAnalysis();
    }
  });

  el.btnComposerSend.addEventListener("click", () => {
    triggerAnalysis();
  });

  // Header SQL Tables View
  el.btnHeaderViewTables.addEventListener("click", () => {
    if (state.currentTables.length > 0) {
      openSqlModal(state.currentTables);
    }
  });

  // Modal Table Actions
  el.modalBtnClose.addEventListener("click", closeSqlModal);
  el.sqlModalBackdrop.addEventListener("click", (e) => {
    if (e.target === el.sqlModalBackdrop) closeSqlModal();
  });

  el.modalBtnViewAll.addEventListener("click", () => setModalTableViewMode("all"));
  el.modalBtnViewSingle.addEventListener("click", () => setModalTableViewMode("single"));

  el.modalBtnExportCsv.addEventListener("click", () => {
    const activeTable = state.currentTables[state.activeTableIndex];
    if (activeTable) exportTableCsv(activeTable);
  });

  el.modalTableSearchInput.addEventListener("input", () => {
    renderModalActiveSingleTable();
  });
}

function resetConversation() {
  state.messages = [];
  el.chatMessagesList.innerHTML = "";
  el.chatWelcomeHero.style.display = "flex";
  el.btnHeaderViewTables.style.display = "none";
  scrollStreamToBottom();
}

function autoResizeTextarea(textarea) {
  textarea.style.height = "auto";
  const newHeight = Math.min(textarea.scrollHeight, 140);
  textarea.style.height = `${newHeight}px`;
}

function scrollStreamToBottom() {
  setTimeout(() => {
    el.chatStreamContainer.scrollTo({
      top: el.chatStreamContainer.scrollHeight,
      behavior: "smooth"
    });
  }, 60);
}

/**
 * 6. Utilities & Markdown Rendering
 */
function escapeHtml(str) {
  if (str === null || str === undefined) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function truncate(str, maxLen = 40) {
  if (!str) return "";
  return str.length > maxLen ? str.slice(0, maxLen) + "…" : str;
}

function formatParagraphs(text) {
  if (!text) return "";
  const lines = text.split("\n");
  const result = [];
  let inList = false;

  for (let line of lines) {
    const trimmed = line.trim();
    if (!trimmed) {
      if (inList) { result.push("</ul>"); inList = false; }
      continue;
    }
    if (trimmed.startsWith("- ") || trimmed.startsWith("* ") || trimmed.startsWith("• ")) {
      if (!inList) { result.push("<ul>"); inList = true; }
      result.push(`<li>${renderInlineMarkdown(trimmed.slice(2))}</li>`);
    } else if (/^\d+\.\s/.test(trimmed)) {
      if (inList) { result.push("</ul>"); inList = false; }
      result.push(`<p><strong>${renderInlineMarkdown(trimmed)}</strong></p>`);
    } else {
      if (inList) { result.push("</ul>"); inList = false; }
      result.push(`<p>${renderInlineMarkdown(trimmed)}</p>`);
    }
  }
  if (inList) result.push("</ul>");
  return result.join("");
}

function renderInlineMarkdown(str) {
  return escapeHtml(str)
    .replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>")
    .replace(/\*(.*?)\*/g, "<em>$1</em>")
    .replace(/`(.*?)`/g, "<code style='background:var(--color-linen-light); padding:1px 5px; border-radius:3px; font-family:var(--font-mono); font-size:11.5px;'>$1</code>");
}

function renderMarkdown(md) {
  if (!md) return "";
  const lines = md.split("\n");
  const html = [];
  let inList = false;

  for (let line of lines) {
    const trimmed = line.trim();
    if (!trimmed) {
      if (inList) { html.push("</ul>"); inList = false; }
      continue;
    }
    if (trimmed.startsWith("### ")) {
      if (inList) { html.push("</ul>"); inList = false; }
      html.push(`<h3>${renderInlineMarkdown(trimmed.slice(4))}</h3>`);
    } else if (trimmed.startsWith("## ")) {
      if (inList) { html.push("</ul>"); inList = false; }
      html.push(`<h2>${renderInlineMarkdown(trimmed.slice(3))}</h2>`);
    } else if (trimmed.startsWith("# ")) {
      if (inList) { html.push("</ul>"); inList = false; }
      html.push(`<h1>${renderInlineMarkdown(trimmed.slice(2))}</h1>`);
    } else if (trimmed.startsWith("- ") || trimmed.startsWith("* ")) {
      if (!inList) { html.push("<ul>"); inList = true; }
      html.push(`<li>${renderInlineMarkdown(trimmed.slice(2))}</li>`);
    } else {
      if (inList) { html.push("</ul>"); inList = false; }
      html.push(`<p>${renderInlineMarkdown(trimmed)}</p>`);
    }
  }
  if (inList) html.push("</ul>");
  return html.join("");
}
