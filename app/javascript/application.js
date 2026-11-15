import "@hotwired/turbo-rails";

// Stockroom client-side behaviour.
//
// This file is a plain ES module so it can be loaded by Rails' importmap. It
// deliberately uses DOM APIs rather than a framework: the interface remains
// usable if JavaScript is slow to load, while the enhancements below make
// filtering, reordering, autosave, and live discussion effortless.

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

const csrfToken = () => $('meta[name="csrf-token"]')?.content || "";

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function debounce(callback, wait) {
  let timer;
  return (...args) => {
    window.clearTimeout(timer);
    timer = window.setTimeout(() => callback(...args), wait);
  };
}

function formBody(form) {
  const body = new URLSearchParams();
  new FormData(form).forEach((value, key) => body.append(key, value));
  return body;
}

async function jsonRequest(url, options = {}) {
  const headers = new Headers(options.headers || {});
  headers.set("Accept", "application/json");
  headers.set("X-CSRF-Token", csrfToken());
  headers.set("X-Requested-With", "XMLHttpRequest");

  const response = await fetch(url, { ...options, headers });
  let payload = null;
  const contentType = response.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    payload = await response.json();
  }
  return { response, payload };
}

function initTheme() {
  const toggle = $("[data-theme-toggle]");
  if (!toggle) return;

  const applyTheme = (theme, persist) => {
    const normalized = theme === "dark" ? "dark" : "light";
    document.documentElement.dataset.theme = normalized;

    try {
      window.localStorage.setItem("stockroom-theme", normalized);
      document.cookie = `stockroom_theme=${normalized}; path=/; max-age=31536000; SameSite=Lax`;
    } catch (_error) {
      // Private browsing can disable localStorage; the current page still works.
    }

    if (persist && document.body?.dataset.signedIn === "true") {
      const settingsUrl = document.body.dataset.settingsUrl;
      if (settingsUrl) {
        fetch(settingsUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "Accept": "application/json",
            "X-CSRF-Token": csrfToken(),
          },
          body: new URLSearchParams({ theme: normalized }),
        }).catch(() => {
          // The local theme remains applied even if the account update fails.
        });
      }
    }
  };

  toggle.addEventListener("click", () => {
    const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    applyTheme(next, true);
  });
}

function initGlobalSearch() {
  const input = $("[data-search-input]");
  if (!input) return;

  document.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault();
      input.focus();
      input.select();
    }
  });
}

function initFlashMessages() {
  $$("[data-dismiss-flash]").forEach((button) => {
    button.addEventListener("click", () => {
      const flash = button.closest(".flash");
      flash?.style.setProperty("opacity", "0");
      window.setTimeout(() => flash?.remove(), 180);
    });
  });

  const stack = $(".flash-stack");
  if (!stack) return;
  window.setTimeout(() => {
    stack.querySelectorAll(".flash").forEach((flash) => {
      flash.style.opacity = "0";
      flash.style.transform = "translateY(-8px)";
    });
    window.setTimeout(() => stack.remove(), 220);
  }, 6500);
}

function initMenus() {
  document.addEventListener("click", (event) => {
    $$("[data-menu][open]").forEach((menu) => {
      if (!menu.contains(event.target)) menu.removeAttribute("open");
    });
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      $$("[data-menu][open]").forEach((menu) => menu.removeAttribute("open"));
    }
  });
}

function initClickableRows() {
  document.addEventListener("click", (event) => {
    if (event.target.closest("a, button, input, select, textarea, label, [contenteditable='true']")) return;
    const row = event.target.closest("[data-row-link]");
    if (!row) return;
    const link = row.querySelector("a[href]");
    if (link) window.location.assign(link.href);
  });
}

function updateFilterState(table) {
  const controls = $$(`[data-table-filter="${table.id}"]`);
  const panel = table.closest(".panel");
  let visible = 0;

  $$("tbody tr", table).forEach((row) => {
    const haystack = `${row.dataset.filterText || ""} ${row.textContent}`.toLocaleLowerCase();
    const matches = controls.every((control) => {
      const value = control.value.trim().toLocaleLowerCase();
      if (!value) return true;
      return haystack.includes(value);
    });
    row.hidden = !matches;
    if (matches) visible += 1;
  });

  const empty = panel?.querySelector("[data-filter-empty]");
  if (empty) empty.hidden = visible !== 0;
}

function initTableFilters() {
  $$("[data-table-filter]").forEach((control) => {
    const table = document.getElementById(control.dataset.tableFilter);
    if (!table) return;
    control.addEventListener("input", () => updateFilterState(table));
    control.addEventListener("change", () => updateFilterState(table));
  });
}

function initTableSorting() {
  $$("[data-table-sort]").forEach((control) => {
    const table = document.getElementById(control.dataset.tableSort);
    if (!table) return;

    control.addEventListener("change", () => {
      const body = table.tBodies[0];
      if (!body) return;
      const rows = Array.from(body.rows);
      const mode = control.value;

      rows.sort((left, right) => {
        if (mode === "name") {
          const leftName = left.querySelector("a")?.textContent.trim().toLocaleLowerCase() || "";
          const rightName = right.querySelector("a")?.textContent.trim().toLocaleLowerCase() || "";
          return leftName.localeCompare(rightName);
        }

        if (mode === "newest" || mode === "oldest") {
          const dateOf = (row) => {
            const candidate = Array.from(row.cells)
              .map((cell) => cell.textContent.trim())
              .find((text) => /\b\d{4}\b/.test(text));
            const timestamp = candidate ? Date.parse(candidate) : 0;
            return Number.isNaN(timestamp) ? 0 : timestamp;
          };
          const difference = dateOf(right) - dateOf(left);
          return mode === "newest" ? difference : -difference;
        }

        return 0;
      });

      rows.forEach((row) => body.appendChild(row));
    });
  });
}

function initFieldReordering() {
  const table = $("[data-field-reorder-table]");
  if (!table) return;

  const body = $("[data-field-reorder-list]", table);
  const moveButtons = $$("[data-reorder-move]");
  const saveButton = $("[data-reorder-save]");
  const deleteButton = $("[data-delete-selected]");
  let dirty = false;

  const selectedRows = () => $$("[data-field-select]:checked", table).map((input) => input.closest("[data-field-row]"));
  const syncControls = () => {
    const selected = selectedRows();
    moveButtons.forEach((button) => { button.disabled = selected.length !== 1; });
    if (deleteButton) deleteButton.disabled = selected.length === 0;
    if (saveButton) saveButton.disabled = !dirty;
  };

  const markDirty = () => {
    dirty = true;
    syncControls();
  };

  table.addEventListener("change", (event) => {
    if (event.target.matches("[data-field-select]")) syncControls();
  });

  let draggedRow = null;
  body?.addEventListener("dragstart", (event) => {
    draggedRow = event.target.closest("[data-field-row]");
    draggedRow?.classList.add("is-dragging");
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", draggedRow?.dataset.fieldId || "");
  });

  body?.addEventListener("dragover", (event) => {
    event.preventDefault();
    const target = event.target.closest("[data-field-row]");
    if (!target || !draggedRow || target === draggedRow) return;
    const bounds = target.getBoundingClientRect();
    body.insertBefore(draggedRow, event.clientY < bounds.top + bounds.height / 2 ? target : target.nextSibling);
  });

  body?.addEventListener("dragend", () => {
    draggedRow?.classList.remove("is-dragging");
    draggedRow = null;
    markDirty();
  });

  moveButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const row = selectedRows()[0];
      if (!row || !body) return;
      if (button.dataset.reorderMove === "up" && row.previousElementSibling) {
        body.insertBefore(row, row.previousElementSibling);
      } else if (button.dataset.reorderMove === "down" && row.nextElementSibling) {
        body.insertBefore(row.nextElementSibling, row);
      }
      markDirty();
      row.querySelector("[data-field-select]")?.focus();
    });
  });

  saveButton?.addEventListener("click", async () => {
    if (!dirty || !table.dataset.reorderUrl) return;
    saveButton.disabled = true;
    const status = $("[data-reorder-status]");
    if (status) status.dataset.state = "saving";

    const ids = $$("[data-field-row]", table).map((row) => row.dataset.fieldId);
    const { response } = await jsonRequest(table.dataset.reorderUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ids }),
    }).catch(() => ({ response: { ok: false } }));

    if (response.ok) {
      dirty = false;
      if (status) {
        status.dataset.state = "saved";
        status.textContent = status.dataset.savedMessage || "Field order is up to date";
      }
    } else if (status) {
      status.dataset.state = "error";
      status.textContent = status.dataset.errorMessage || "Could not save field order";
    }
    syncControls();
  });

  deleteButton?.addEventListener("click", async () => {
    const rows = selectedRows();
    if (!rows.length) return;
    if (!window.confirm(deleteButton.dataset.confirmMessage || "Delete the selected fields and their values? This cannot be undone.")) return;

    deleteButton.disabled = true;
    for (const row of rows) {
      const path = row.dataset.fieldDeletePath;
      if (!path) continue;
      const { response } = await jsonRequest(path, { method: "DELETE" }).catch(() => ({ response: { ok: false } }));
      if (response.ok) row.remove();
    }
    dirty = true;
    syncControls();
  });

  syncControls();
}

function initAccessSorting() {
  const list = $("[data-access-list]");
  if (!list) return;

  $$("[data-access-sort]").forEach((button) => {
    button.addEventListener("click", () => {
      const key = button.dataset.accessSort;
      const rows = Array.from(list.rows);
      rows.sort((left, right) => (left.dataset[key] || "").localeCompare(right.dataset[key] || ""));
      rows.forEach((row) => list.appendChild(row));
      $$("[data-access-sort]").forEach((item) => item.classList.toggle("is-active", item === button));
    });
  });
}

function initAccessRemoval() {
  const removeButton = $("[data-remove-access]");
  if (!removeButton) return;

  const selectedRows = () => $$("[data-access-select]:checked").map((input) => input.closest("[data-access-row]"));
  document.addEventListener("change", (event) => {
    if (event.target.matches("[data-access-select]")) {
      removeButton.disabled = selectedRows().length === 0;
    }
  });

  removeButton.addEventListener("click", async () => {
    const rows = selectedRows();
    if (!rows.length) return;
    removeButton.disabled = true;
    for (const row of rows) {
      const { response } = await jsonRequest(row.dataset.accessPath, { method: "DELETE" }).catch(() => ({ response: { ok: false } }));
      if (response.ok) row.remove();
    }
  });
}

function renderAutocompleteResults(input, results, people, onSelect) {
  results.replaceChildren();
  if (!people.length) {
    results.hidden = true;
    return;
  }

  people.forEach((person) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "autocomplete__result";
    button.setAttribute("role", "option");

    const name = document.createElement("strong");
    name.textContent = person.name || person.email;
    const email = document.createElement("span");
    email.textContent = person.email || "";
    button.append(name, email);

    button.addEventListener("mousedown", (event) => event.preventDefault());
    button.addEventListener("click", () => {
      onSelect(person);
      results.hidden = true;
      results.replaceChildren();
    });
    results.appendChild(button);
  });
  results.hidden = false;
}

function setupAutocomplete(input, mode) {
  const container = input.closest(".autocomplete") || input.parentElement;
  let results = container.querySelector("[data-autocomplete-results]");
  if (!results) {
    results = document.createElement("div");
    results.className = "autocomplete__results";
    results.hidden = true;
    results.setAttribute("role", "listbox");
    container.appendChild(results);
  }

  const url = mode === "access" ? input.dataset.suggestionsUrl : input.dataset.tagSuggestionsUrl;
  if (!url) return;

  const fetchSuggestions = debounce(async () => {
    const query = input.value.trim();
    if (!query) {
      results.hidden = true;
      results.replaceChildren();
      return;
    }

    try {
      const response = await fetch(`${url}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json", "X-Requested-With": "XMLHttpRequest" },
      });
      if (!response.ok) return;
      const people = await response.json();
      renderAutocompleteResults(input, results, people, (person) => {
        if (mode === "access") {
          input.value = person.name || person.email;
          const userId = $("[data-access-user-id]", container);
          const email = $("[data-access-email]", container);
          if (userId) userId.value = person.id;
          if (email) email.value = person.email;
        } else {
          const parts = input.value.split(",").map((part) => part.trim()).filter(Boolean);
          parts[parts.length - 1] = person.name;
          input.value = parts.join(", ");
          input.dispatchEvent(new Event("input", { bubbles: true }));
        }
      });
    } catch (_error) {
      results.hidden = true;
    }
  }, 180);

  input.addEventListener("input", fetchSuggestions);
  input.addEventListener("blur", () => window.setTimeout(() => { results.hidden = true; }, 120));
}

function initAutocompletes() {
  $$('[data-access-autocomplete="true"]').forEach((input) => setupAutocomplete(input, "access"));
  $$('[data-tag-input="true"]').forEach((input) => setupAutocomplete(input, "tag"));
}

function showAutosaveConflict(form, message, serverVersion) {
  let panel = form.parentElement.querySelector("[data-autosave-conflict]");
  if (!panel) {
    panel = document.createElement("div");
    panel.className = "flash flash--danger";
    panel.dataset.autosaveConflict = "";
    panel.setAttribute("role", "alert");
    form.parentElement.prepend(panel);
  }

  panel.replaceChildren();
  const copy = document.createElement("p");
  copy.textContent = message || "This inventory was changed by someone else. Your edits are still here, but they were not overwritten.";
  const reload = document.createElement("button");
  reload.type = "button";
  reload.className = "button button--secondary button--small";
  reload.textContent = $("[data-autosave-status]")?.dataset.reloadMessage || "Reload server version";
  reload.addEventListener("click", () => window.location.reload());
  const close = document.createElement("button");
  close.type = "button";
  close.className = "flash__close";
  close.textContent = "×";
  close.setAttribute("aria-label", "Dismiss conflict message");
  close.addEventListener("click", () => panel.remove());
  panel.append(copy, reload, close);

  if (serverVersion !== undefined && serverVersion !== null) {
    const version = document.createElement("span");
    version.className = "sr-only";
    version.textContent = `Server version ${serverVersion}`;
    panel.appendChild(version);
  }
}

function initInventoryAutosave() {
  const form = $("[data-autosave-form]");
  if (!form) return;

  const status = $("[data-autosave-status]");
  let dirty = false;
  let revision = 0;
  let timer = null;

  const setStatus = (state, text) => {
    if (!status) return;
    status.dataset.state = state;
    status.textContent = text;
  };

  const save = async () => {
    if (!dirty) return;
    const revisionAtStart = revision;
    setStatus("saving", status?.dataset.savingMessage || "Saving changes…");

    try {
      const { response, payload } = await jsonRequest(form.action, {
        method: form.method || "post",
        headers: { "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8" },
        body: formBody(form),
      });

      if (response.status === 409) {
        setStatus("error", status?.dataset.conflictMessage || "Conflict — not saved");
        showAutosaveConflict(form, payload?.message, payload?.version);
        return;
      }

      if (response.status === 422) {
        const message = payload?.message || payload?.errors?.title?.[0] || "Some changes could not be saved.";
        setStatus("error", status?.dataset.attentionMessage || "Changes need attention");
        showAutosaveConflict(form, message, payload?.version);
        return;
      }

      if (!response.ok) {
        setStatus("error", status?.dataset.errorMessage || "Could not save changes");
        return;
      }

      if (payload?.version !== undefined) {
        const versionInput = form.querySelector('[name="inventory[lock_version]"]');
        if (versionInput) versionInput.value = payload.version;
      }

      if (revisionAtStart === revision) {
        dirty = false;
        setStatus("saved", status?.dataset.savedMessage || "All changes saved");
      } else {
        dirty = true;
        setStatus("pending", status?.dataset.pendingMessage || "Waiting to save…");
        window.clearTimeout(timer);
        timer = window.setTimeout(save, 8000);
      }
    } catch (_error) {
      setStatus("error", "Could not save changes");
    }
  };

  const scheduleSave = () => {
    dirty = true;
    revision += 1;
    setStatus("pending", status?.dataset.pendingMessage || "Waiting to save…");
    window.clearTimeout(timer);
    timer = window.setTimeout(save, 8000);
  };

  form.addEventListener("input", scheduleSave);
  form.addEventListener("change", scheduleSave);
  form.addEventListener("submit", (event) => {
    if (dirty) {
      window.clearTimeout(timer);
      save();
    }
    event.preventDefault();
  });
}

function idOptionMarkup(kind, index) {
  const name = `elements[${index}]`;
  if (kind === "fixed") {
    return `<div class="input-with-help"><input class="form-control" name="${name}[text]" placeholder="Fixed text" aria-label="Fixed text" data-id-text><button class="help-button" type="button" data-bs-toggle="popover" data-bs-title="Fixed text" data-bs-content="Any Unicode text, such as LAB- or 2026/." aria-label="Show help">?</button></div>`;
  }
  if (kind === "guid") {
    return `<div class="input-with-help"><select class="form-select" name="${name}[options][format]" aria-label="GUID format" data-id-option><option value="hyphenated">8-4-4-4-12</option><option value="compact">32 hex characters</option></select><button class="help-button" type="button" data-bs-toggle="popover" data-bs-title="GUID format" data-bs-content="Hyphenated uses 8-4-4-4-12; compact uses 32 hexadecimal characters." aria-label="Show help">?</button></div>`;
  }
  if (kind === "datetime") {
    return `<div class="input-with-help"><input class="form-control" name="${name}[options][format]" value="%Y%m%d" aria-label="Date format" data-id-option><button class="help-button" type="button" data-bs-toggle="popover" data-bs-title="Date format" data-bs-content="Use a strftime pattern, for example %Y%m%d for 20261115." aria-label="Show help">?</button></div>`;
  }
  return `<div class="input-with-help"><input class="form-control" type="number" min="1" max="20" name="${name}[options][padding]" placeholder="Padding" aria-label="Number padding" data-id-option><button class="help-button" type="button" data-bs-toggle="popover" data-bs-title="Leading-zero padding" data-bs-content="Numeric padding adds leading zeroes, for example 0007." aria-label="Show help">?</button></div>`;
}

function initCustomIdBuilder() {
  const form = $("[data-id-format-form]");
  const list = $("[data-id-element-list]");
  if (!form || !list) return;

  const preview = $("[data-id-preview]");
  const previewMeta = $("[data-id-preview-meta]");
  const moveButtons = $$("[data-id-move]");
  let focusedRow = null;
  let lastPointer = null;

  const labels = {};
  const helps = {};
  $$("[data-add-id-kind]").forEach((button) => {
    labels[button.dataset.addIdKind] = button.dataset.label;
    helps[button.dataset.addIdKind] = button.dataset.help;
  });

  const reindex = () => {
    Array.from(list.children).forEach((row, index) => {
      $$("[name]", row).forEach((input) => {
        input.name = input.name.replace(/elements\[\d+\]/, `elements[${index}]`);
      });
    });
    list.classList.toggle("is-empty", list.children.length === 0);
  };

  const updateFormatBadge = (row) => {
    const kind = $("[data-id-kind]", row)?.value || "";
    const badge = $(".id-element__format", row);
    if (!badge) return;
    if (kind === "datetime") badge.innerHTML = '<span class="status-pill status-pill--info">%Y%m%d</span>';
    else if (kind.startsWith("random") || kind === "sequence") badge.innerHTML = `<span class="status-pill status-pill--info">${escapeHtml(form.dataset.plainLabel || "plain")}</span>`;
    else badge.innerHTML = `<span class="status-pill status-pill--private">${escapeHtml(form.dataset.generatedLabel || "Generated")}</span>`;
  };

  const setKind = (row, kind) => {
    const options = $(".id-element__options", row);
    if (!options) return;
    const index = Array.from(list.children).indexOf(row);
    options.innerHTML = idOptionMarkup(kind, index < 0 ? 0 : index);
    updateFormatBadge(row);
    const helpButton = $("[data-bs-toggle='popover']", row.querySelector(".input-with-help"));
    if (helpButton && helps[kind]) {
      helpButton.dataset.bsContent = helps[kind];
      helpButton.dataset.bsTitle = labels[kind] || "About this element";
      if (window.bootstrap?.Popover) {
        window.bootstrap.Popover.getInstance(helpButton)?.dispose();
        new window.bootstrap.Popover(helpButton);
      }
    }
  };

  const collect = () => Array.from(list.querySelectorAll("[data-id-element]")).map((row) => {
    const kind = $("[data-id-kind]", row)?.value || "fixed";
    const element = { kind, text: null, options: {} };
    if (kind === "fixed") element.text = $("[data-id-text]", row)?.value || "";
    if (kind === "guid") element.options.format = $("[data-id-option]", row)?.value || "hyphenated";
    if (kind === "datetime") element.options.format = $("[data-id-option]", row)?.value || "%Y%m%d";
    if (kind.startsWith("random") || kind === "sequence") {
      const padding = Number($("[data-id-option]", row)?.value || 0);
      if (padding > 0) element.options.padding = padding;
    }
    return element;
  });

  const updatePreview = debounce(async () => {
    if (!form.dataset.previewUrl) return;
    if (preview) preview.textContent = "…";
    if (previewMeta) previewMeta.textContent = form.dataset.previewUpdatingMessage || "Updating preview…";

    try {
      const { response, payload } = await jsonRequest(form.dataset.previewUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ elements: collect() }),
      });
      if (!response.ok) throw new Error("preview failed");
      if (preview) preview.textContent = payload.preview || "—";
      if (previewMeta) previewMeta.textContent = payload.format || "No format";
    } catch (_error) {
      if (preview) preview.textContent = "—";
      if (previewMeta) previewMeta.textContent = form.dataset.previewUnavailableMessage || "Preview unavailable";
    }
  }, 220);

  const syncMoveButtons = () => {
    moveButtons.forEach((button) => {
      button.disabled = !focusedRow || (button.dataset.idMove === "up" && !focusedRow.previousElementSibling) || (button.dataset.idMove === "down" && !focusedRow.nextElementSibling);
    });
  };

  const makeRow = (kind) => {
    const row = document.createElement("div");
    row.className = "id-element";
    row.draggable = true;
    row.tabIndex = 0;
    row.dataset.idElement = "";
    const kindOptions = Object.entries(labels).map(([value, label]) => `<option value="${escapeHtml(value)}">${escapeHtml(label)}</option>`).join("");
    row.innerHTML = `<span class="drag-handle" aria-hidden="true">⠿</span><input type="hidden" name="elements[0][id]" value=""><div class="input-with-help"><select class="form-select" name="elements[0][kind]" aria-label="Element type" data-id-kind>${kindOptions}</select><button class="help-button" type="button" data-bs-toggle="popover" data-bs-title="${escapeHtml(labels[kind] || "About this element")}" data-bs-content="${escapeHtml(helps[kind] || "This element contributes to the inventory ID.")}" aria-label="Show help">?</button></div><div class="id-element__options"></div><div class="id-element__format"></div><button class="field-card__delete" type="button" data-id-remove aria-label="${escapeHtml(form.dataset.removeLabel || "Remove element")}">×</button>`;
    $("[data-id-kind]", row).value = kind;
    setKind(row, kind);
    return row;
  };

  $$("[data-add-id-kind]").forEach((button) => {
    button.addEventListener("click", () => {
      if (list.children.length >= 10) {
        window.alert(form.dataset.maxElementsMessage || "An ID format can contain up to ten elements.");
        return;
      }
      const row = makeRow(button.dataset.addIdKind);
      list.appendChild(row);
      reindex();
      focusedRow = row;
      syncMoveButtons();
      updatePreview();
    });
  });

  list.addEventListener("click", (event) => {
    const remove = event.target.closest("[data-id-remove]");
    if (!remove) return;
    const row = remove.closest("[data-id-element]");
    row?.remove();
    reindex();
    focusedRow = null;
    syncMoveButtons();
    updatePreview();
  });

  list.addEventListener("change", (event) => {
    if (event.target.matches("[data-id-kind]")) {
      const row = event.target.closest("[data-id-element]");
      setKind(row, event.target.value);
      reindex();
      updatePreview();
    }
  });

  list.addEventListener("input", updatePreview);

  list.addEventListener("focusin", (event) => {
    const row = event.target.closest("[data-id-element]");
    if (!row) return;
    focusedRow = row;
    syncMoveButtons();
  });

  list.addEventListener("keydown", (event) => {
    if (!event.altKey || !focusedRow) return;
    if (event.key === "ArrowUp" && focusedRow.previousElementSibling) {
      event.preventDefault();
      list.insertBefore(focusedRow, focusedRow.previousElementSibling);
      focusedRow.focus();
      reindex();
      updatePreview();
    }
    if (event.key === "ArrowDown" && focusedRow.nextElementSibling) {
      event.preventDefault();
      list.insertBefore(focusedRow.nextElementSibling, focusedRow);
      focusedRow.focus();
      reindex();
      updatePreview();
    }
  });

  moveButtons.forEach((button) => {
    button.addEventListener("click", () => {
      if (!focusedRow) return;
      if (button.dataset.idMove === "up" && focusedRow.previousElementSibling) list.insertBefore(focusedRow, focusedRow.previousElementSibling);
      if (button.dataset.idMove === "down" && focusedRow.nextElementSibling) list.insertBefore(focusedRow.nextElementSibling, focusedRow);
      focusedRow.focus();
      reindex();
      syncMoveButtons();
      updatePreview();
    });
  });

  let draggedRow = null;
  list.addEventListener("dragstart", (event) => {
    draggedRow = event.target.closest("[data-id-element]");
    draggedRow?.classList.add("is-dragging");
    event.dataTransfer.effectAllowed = "move";
  });
  list.addEventListener("dragover", (event) => {
    event.preventDefault();
    lastPointer = { x: event.clientX, y: event.clientY };
    const target = event.target.closest("[data-id-element]");
    if (!target || !draggedRow || target === draggedRow) return;
    const bounds = target.getBoundingClientRect();
    list.insertBefore(draggedRow, event.clientY < bounds.top + bounds.height / 2 ? target : target.nextSibling);
  });
  document.addEventListener("dragover", (event) => {
    if (draggedRow) lastPointer = { x: event.clientX, y: event.clientY };
  });
  list.addEventListener("dragend", () => {
    draggedRow?.classList.remove("is-dragging");
    const bounds = list.getBoundingClientRect();
    if (lastPointer && (lastPointer.x < bounds.left || lastPointer.x > bounds.right || lastPointer.y < bounds.top || lastPointer.y > bounds.bottom)) {
      draggedRow?.remove();
    }
    draggedRow = null;
    reindex();
    updatePreview();
  });

  reindex();
  syncMoveButtons();
  updatePreview();
}

function initDiscussionPolling() {
  const feed = $("[data-discussion-feed]");
  if (!feed || !feed.dataset.discussionPollUrl) return;

  const poll = async () => {
    if (!document.hidden) {
      try {
        const response = await fetch(feed.dataset.discussionPollUrl, {
          headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" },
        });
        if (response.ok) {
          const html = await response.text();
          const parsed = new DOMParser().parseFromString(html, "text/html");
          const fresh = parsed.querySelector("[data-discussion-feed]");
          if (fresh && fresh.innerHTML !== feed.innerHTML) {
            feed.innerHTML = fresh.innerHTML;
            const status = $("[data-discussion-status]");
            if (status) status.textContent = status.dataset.updatedMessage || "Updated just now";
          }
        }
      } catch (_error) {
        // A temporary network failure should not stop future polls.
      }
    }
    window.setTimeout(poll, 4000);
  };

  window.setTimeout(poll, 4000);
}

function initMarkdownToolbar() {
  $$("[data-markdown]").forEach((button) => {
    button.addEventListener("click", () => {
      const editor = $("[data-markdown-editor]");
      if (!editor) return;
      const start = editor.selectionStart;
      const end = editor.selectionEnd;
      const selected = editor.value.slice(start, end);
      const wrappers = {
        bold: ["**", "**"],
        italic: ["_", "_"],
        code: ["`", "`"],
        link: ["[", "](https://)"],
      };
      const [before, after] = wrappers[button.dataset.markdown] || ["", ""];
      editor.setRangeText(`${before}${selected}${after}`, start, end, "select");
      editor.focus();
      editor.dispatchEvent(new Event("input", { bubbles: true }));
    });
  });
}

function initOwnedInventoryActions() {
  const editButton = $("[data-edit-owned]");
  const deleteButton = $("[data-delete-owned]");
  if (!editButton && !deleteButton) return;

  const selectedRows = () => $$("[data-owned-inventory-select]:checked").map((input) => input.closest("[data-row-link]"));
  document.addEventListener("change", (event) => {
    if (!event.target.matches("[data-owned-inventory-select]")) return;
    const rows = selectedRows();
    if (editButton) editButton.disabled = rows.length !== 1;
    if (deleteButton) deleteButton.disabled = rows.length === 0;
  });

  editButton?.addEventListener("click", () => {
    const row = selectedRows()[0];
    if (row?.dataset.inventoryEditPath) window.location.assign(row.dataset.inventoryEditPath);
  });

  deleteButton?.addEventListener("click", async () => {
    const rows = selectedRows();
    if (!rows.length) return;
    if (!window.confirm(deleteButton.dataset.confirmMessage || "Delete the selected inventories? This cannot be undone.")) return;
    deleteButton.disabled = true;
    for (const row of rows) {
      const path = row.dataset.inventoryDeletePath;
      if (!path) continue;
      const { response } = await jsonRequest(path, { method: "DELETE" }).catch(() => ({ response: { ok: false } }));
      if (response.ok) row.remove();
    }
  });
}

function initAdminActions() {
  const actionButtons = $$("[data-admin-user-action]");
  if (!actionButtons.length) return;

  const selectedRows = () => $$("[data-admin-user-select]:checked").map((input) => input.closest("[data-admin-user-row]"));
  document.addEventListener("change", (event) => {
    if (!event.target.matches("[data-admin-user-select]")) return;
    actionButtons.forEach((button) => { button.disabled = selectedRows().length === 0; });
  });

  actionButtons.forEach((button) => {
    button.addEventListener("click", async () => {
      const rows = selectedRows();
      if (!rows.length) return;
      const action = button.dataset.adminUserAction;

      if (action === "delete" && !window.confirm(button.dataset.confirmMessage || "Delete the selected accounts? This cannot be undone.")) return;
      button.disabled = true;

      for (const row of rows) {
        const path = row.dataset.userPath;
        let options;
        if (action === "delete") {
          options = { method: "DELETE" };
        } else if (action === "block") {
          options = { method: "PATCH", body: new URLSearchParams({ blocked: "true" }) };
        } else if (action === "unblock") {
          options = { method: "PATCH", body: new URLSearchParams({ blocked: "false" }) };
        } else if (action === "grant-admin") {
          options = { method: "PATCH", body: new URLSearchParams({ admin: "true" }) };
        } else {
          options = { method: "PATCH", body: new URLSearchParams({ admin: "false" }) };
        }
        options.headers = { "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8" };
        await jsonRequest(path, options).catch(() => null);
      }

      window.location.reload();
    });
  });
}

function initConfirmations() {
  document.addEventListener("submit", (event) => {
    const form = event.target;
    const message = form.dataset.confirm || form.closest("[data-confirm]")?.dataset.confirm;
    if (message && !window.confirm(message)) event.preventDefault();
  });
}

function initPopovers() {
  if (!window.bootstrap?.Popover) return;
  $$('[data-bs-toggle="popover"]').forEach((button) => {
    window.bootstrap.Popover.getInstance(button)?.dispose();
    new window.bootstrap.Popover(button);
  });
}

function initErrorPages() {
  $$("[data-go-back]").forEach((button) => {
    button.addEventListener("click", () => window.history.back());
  });
}

function init() {
  initTheme();
  initGlobalSearch();
  initFlashMessages();
  initMenus();
  initClickableRows();
  initTableFilters();
  initTableSorting();
  initFieldReordering();
  initAccessSorting();
  initAccessRemoval();
  initAutocompletes();
  initInventoryAutosave();
  initCustomIdBuilder();
  initDiscussionPolling();
  initMarkdownToolbar();
  initOwnedInventoryActions();
  initAdminActions();
  initConfirmations();
  initPopovers();
  initErrorPages();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init, { once: true });
} else {
  init();
}
