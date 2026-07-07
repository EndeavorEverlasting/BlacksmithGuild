const cp = require("child_process");
const fs = require("fs");
const path = require("path");
const { fileURLToPath, pathToFileURL } = require("url");

const args = process.argv.slice(2);
function argValue(name, fallback) {
  const index = args.indexOf(name);
  return index >= 0 && index + 1 < args.length ? args[index + 1] : fallback;
}

const repoRoot = path.resolve(argValue("--repoRoot", process.cwd()));
const timeoutSeconds = Number(argValue("--timeoutSeconds", "120"));
const timeoutMs = Math.max(1, timeoutSeconds) * 1000;
const workspacePath = path.join(repoRoot, "src", "BlacksmithGuild");
const csharpLsCommand = argValue("--csharpLs", process.env.TBG_CSHARP_LS || "csharp-ls");

let nextId = 1;
let buffer = Buffer.alloc(0);
const pending = new Map();
const notifications = [];
const opened = new Set();

function uriFromPath(filePath) {
  return pathToFileURL(filePath).href;
}

function pathFromUri(uri) {
  return fileURLToPath(uri);
}

function readLines(filePath) {
  return fs.readFileSync(filePath, "utf8").split(/\r?\n/);
}

function send(processHandle, message) {
  const body = Buffer.from(JSON.stringify(message), "utf8");
  processHandle.stdin.write(`Content-Length: ${body.length}\r\n\r\n`);
  processHandle.stdin.write(body);
}

function request(processHandle, method, params) {
  const id = nextId++;
  send(processHandle, { jsonrpc: "2.0", id, method, params });
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`timeout:${method}`));
    }, timeoutMs);
    pending.set(id, (message) => {
      clearTimeout(timer);
      resolve(message);
    });
  });
}

function notify(processHandle, method, params) {
  send(processHandle, { jsonrpc: "2.0", method, params });
}

function respondToServerRequest(processHandle, message) {
  let result = null;
  if (message.method === "workspace/configuration") {
    const items = message.params && Array.isArray(message.params.items) ? message.params.items : [];
    result = items.map(() => null);
  }
  send(processHandle, { jsonrpc: "2.0", id: message.id, result });
}

function handleMessage(processHandle, message) {
  if (message.id && pending.has(message.id)) {
    pending.get(message.id)(message);
    return;
  }

  if (message.id && message.method) {
    respondToServerRequest(processHandle, message);
    return;
  }

  if (message.method) {
    notifications.push(message);
  }
}

function parseMessages(processHandle) {
  while (true) {
    const text = buffer.toString("utf8");
    const headerEnd = text.indexOf("\r\n\r\n");
    if (headerEnd < 0) return;

    const match = /Content-Length: (\d+)/i.exec(text.slice(0, headerEnd));
    if (!match) {
      throw new Error(`bad-lsp-header:${text.slice(0, headerEnd)}`);
    }

    const length = Number(match[1]);
    const bodyStart = headerEnd + 4;
    if (buffer.length < bodyStart + length) return;

    const message = JSON.parse(buffer.slice(bodyStart, bodyStart + length).toString("utf8"));
    buffer = buffer.slice(bodyStart + length);
    handleMessage(processHandle, message);
  }
}

function findAnchor(filePath, pattern, symbol) {
  const lines = readLines(filePath);
  const regex = new RegExp(pattern);
  for (let index = 0; index < lines.length; index++) {
    if (regex.test(lines[index])) {
      let character = lines[index].indexOf(symbol);
      if (character < 0) character = 0;
      return {
        filePath,
        line: index,
        character,
        displayLine: index + 1,
        text: lines[index].trim(),
      };
    }
  }
  return null;
}

function locationFromLsp(location) {
  const filePath = pathFromUri(location.uri);
  const lines = fs.existsSync(filePath) ? readLines(filePath) : [];
  const line = location.range.start.line + 1;
  return {
    file: filePath,
    line,
    character: location.range.start.character,
    text: lines[line - 1] ? lines[line - 1].trim() : "",
  };
}

function normalizeLocations(result) {
  if (!result) return [];
  const items = Array.isArray(result) ? result : [result];
  return items
    .filter((item) => item && item.uri && item.range)
    .map(locationFromLsp);
}

function flattenDocumentSymbols(symbols, filePath, output = []) {
  for (const symbol of symbols || []) {
    if (symbol.location) {
      output.push({ name: symbol.name, kind: symbol.kind, ...locationFromLsp(symbol.location) });
    } else if (symbol.range) {
      const lines = readLines(filePath);
      const line = symbol.range.start.line + 1;
      output.push({
        name: symbol.name,
        kind: symbol.kind,
        file: filePath,
        line,
        character: symbol.range.start.character,
        text: lines[line - 1] ? lines[line - 1].trim() : "",
      });
    }
    flattenDocumentSymbols(symbol.children || [], filePath, output);
  }
  return output;
}

function classifyActiveReport(location) {
  if (/MapTradeCertReport\s+_activeReport\b/.test(location.text)) return "declaration";
  if (/_activeReport\s*=\s*null\b/.test(location.text)) return "cleared";
  if (/_activeReport\s*=(?!=)/.test(location.text)) return "assigned";
  return "read";
}

function queryResult(question, target, state, note, evidence) {
  return { question, target, state, note, evidence: evidence || [] };
}

async function openDocument(processHandle, filePath) {
  if (opened.has(filePath)) return;
  notify(processHandle, "textDocument/didOpen", {
    textDocument: {
      uri: uriFromPath(filePath),
      languageId: "csharp",
      version: 1,
      text: fs.readFileSync(filePath, "utf8"),
    },
  });
  opened.add(filePath);
}

async function definitionQuery(processHandle, spec) {
  const anchor = findAnchor(spec.file, spec.pattern, spec.symbol);
  if (!anchor) {
    return queryResult(spec.question, spec.target, "symbol_not_found", "Could not locate the source anchor for the LSP request.");
  }
  await openDocument(processHandle, spec.file);
  const response = await request(processHandle, "textDocument/definition", {
    textDocument: { uri: uriFromPath(spec.file) },
    position: { line: anchor.line, character: anchor.character },
  });
  const locations = normalizeLocations(response.result);
  return queryResult(
    spec.question,
    spec.target,
    locations.length > 0 ? "symbol_navigation_ready" : "symbol_not_found",
    locations.length > 0 ? "Direct csharp-ls definition request returned location(s)." : "Direct csharp-ls definition request returned no locations.",
    [
      { source: "repo-anchor", ...anchor },
      { source: "lsp", method: "textDocument/definition", locations },
    ],
  );
}

async function referencesQuery(processHandle, spec) {
  const anchor = findAnchor(spec.file, spec.pattern, spec.symbol);
  if (!anchor) {
    return queryResult(spec.question, spec.target, "symbol_not_found", "Could not locate the source anchor for the LSP request.");
  }
  await openDocument(processHandle, spec.file);
  const response = await request(processHandle, "textDocument/references", {
    textDocument: { uri: uriFromPath(spec.file) },
    position: { line: anchor.line, character: anchor.character },
    context: { includeDeclaration: true },
  });
  const locations = normalizeLocations(response.result).map((location) => (
    spec.classify ? { ...location, usage: spec.classify(location) } : location
  ));
  const nonDeclarationLocations = locations.filter((location) => (
    path.resolve(location.file) !== path.resolve(anchor.filePath) || location.line !== anchor.displayLine
  ));
  const requiredUsage = spec.requiredUsage || [];
  const missingUsage = requiredUsage.filter((usage) => !locations.some((location) => location.usage === usage));
  const hasRequiredCaller = spec.requireCaller ? nonDeclarationLocations.length > 0 : true;
  const isReady = locations.length > 0 && missingUsage.length === 0 && hasRequiredCaller;
  let note = "Direct csharp-ls references request returned location(s).";
  if (locations.length === 0) {
    note = "Direct csharp-ls references request returned no locations.";
  } else if (missingUsage.length > 0) {
    note = `Direct csharp-ls references did not prove usage category/categories: ${missingUsage.join(", ")}.`;
  } else if (!hasRequiredCaller) {
    note = "Direct csharp-ls references did not find a caller beyond the declaration.";
  }
  return queryResult(
    spec.question,
    spec.target,
    isReady ? "symbol_navigation_ready" : "symbol_not_found",
    note,
    [
      { source: "repo-anchor", ...anchor },
      { source: "lsp", method: "textDocument/references", locations },
    ],
  );
}

async function hotkeyQuery(processHandle, repoRootValue) {
  const specs = [
    {
      label: "DevHotkeyHandler.PollHotkeys",
      file: path.join(repoRootValue, "src", "BlacksmithGuild", "DevTools", "DevHotkeyHandler.cs"),
      pattern: "PollHotkeys\\(\\)",
      symbol: "PollHotkeys",
    },
    {
      label: "CommandSurfaceService.BuildHotkeys",
      file: path.join(repoRootValue, "src", "BlacksmithGuild", "DevTools", "CommandSurfaceService.cs"),
      pattern: "BuildHotkeys\\(\\)",
      symbol: "BuildHotkeys",
    },
  ];
  const anchors = [];
  const locations = [];
  for (const spec of specs) {
    const anchor = findAnchor(spec.file, spec.pattern, spec.symbol);
    if (!anchor) continue;
    anchors.push({ label: spec.label, ...anchor });
    await openDocument(processHandle, spec.file);
    const response = await request(processHandle, "textDocument/definition", {
      textDocument: { uri: uriFromPath(spec.file) },
      position: { line: anchor.line, character: anchor.character },
    });
    locations.push(...normalizeLocations(response.result).map((location) => ({ label: spec.label, ...location })));
  }
  return queryResult(
    "Where are hotkeys registered?",
    "DevHotkeyHandler / CommandSurfaceService",
    locations.length > 0 ? "symbol_navigation_ready" : "symbol_not_found",
    locations.length > 0 ? "Direct csharp-ls definition requests identified hotkey registration surfaces." : "Direct csharp-ls definition requests did not locate expected hotkey surfaces.",
    [
      { source: "repo-anchor", anchors },
      { source: "lsp", method: "textDocument/definition", locations },
    ],
  );
}

async function main() {
  if (!fs.existsSync(workspacePath)) {
    throw new Error(`workspace-missing:${workspacePath}`);
  }

  const child = cp.spawn(csharpLsCommand, [], {
    cwd: workspacePath,
    stdio: ["pipe", "pipe", "pipe"],
  });
  let stderr = "";
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => {
    stderr += chunk;
    if (stderr.length > 12000) stderr = stderr.slice(-12000);
  });
  child.stdout.on("data", (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    parseMessages(child);
  });

  const initialize = await request(child, "initialize", {
    processId: process.pid,
    rootUri: uriFromPath(workspacePath),
    rootPath: workspacePath,
    capabilities: {
      workspace: { workspaceFolders: true },
      textDocument: {
        synchronization: { didSave: true },
        definition: {},
        references: {},
        documentSymbol: {},
      },
    },
    workspaceFolders: [{ uri: uriFromPath(workspacePath), name: "BlacksmithGuild" }],
  });

  if (initialize.error) {
    throw new Error(`initialize-failed:${initialize.error.message || JSON.stringify(initialize.error)}`);
  }

  notify(child, "initialized", {});
  await new Promise((resolve) => setTimeout(resolve, 10000));

  const specs = [
    {
      question: "Where is MapTradeAutonomousService defined?",
      target: "MapTradeAutonomousService",
      kind: "definition",
      file: path.join(repoRoot, "src", "BlacksmithGuild", "MapTrade", "MapTradeAutonomousService.cs"),
      pattern: "\\bclass\\s+MapTradeAutonomousService\\b",
      symbol: "MapTradeAutonomousService",
    },
    {
      question: "Where is StartRouteNow defined?",
      target: "StartRouteNow",
      kind: "definition",
      file: path.join(repoRoot, "src", "BlacksmithGuild", "MapTrade", "MapTradeAutonomousService.cs"),
      pattern: "\\bStartRouteNow\\b",
      symbol: "StartRouteNow",
      requireCaller: true,
    },
    {
      question: "Who calls StartRouteNow?",
      target: "StartRouteNow references",
      kind: "references",
      file: path.join(repoRoot, "src", "BlacksmithGuild", "MapTrade", "MapTradeAutonomousService.cs"),
      pattern: "\\bStartRouteNow\\b",
      symbol: "StartRouteNow",
    },
    {
      question: "Where is CampaignMapReadyOrchestrator defined?",
      target: "CampaignMapReadyOrchestrator",
      kind: "definition",
      file: path.join(repoRoot, "src", "BlacksmithGuild", "DevTools", "CampaignMapReadyOrchestrator.cs"),
      pattern: "\\bclass\\s+CampaignMapReadyOrchestrator\\b",
      symbol: "CampaignMapReadyOrchestrator",
    },
    {
      question: "Where is _activeReport assigned, read, and cleared?",
      target: "MapTradeAutonomousService._activeReport references",
      kind: "references",
      file: path.join(repoRoot, "src", "BlacksmithGuild", "MapTrade", "MapTradeAutonomousService.cs"),
      pattern: "MapTradeCertReport\\s+_activeReport\\b",
      symbol: "_activeReport",
      classify: classifyActiveReport,
      requiredUsage: ["assigned", "read", "cleared"],
    },
    {
      question: "Where is command inbox parsing handled?",
      target: "DevCommandFileInbox.TryParseInbox",
      kind: "definition",
      file: path.join(repoRoot, "src", "BlacksmithGuild", "DevTools", "DevCommandFileInbox.cs"),
      pattern: "TryParseInbox\\(",
      symbol: "TryParseInbox",
    },
  ];

  const queries = [];
  for (const spec of specs) {
    queries.push(spec.kind === "references" ? await referencesQuery(child, spec) : await definitionQuery(child, spec));
  }
  queries.splice(5, 0, await hotkeyQuery(child, repoRoot));

  child.kill();
  const states = queries.map((query) => query.state);
  const verdict = states.every((state) => state === "symbol_navigation_ready")
    ? "symbol_navigation_ready"
    : states.includes("lsp_project_not_loaded")
      ? "lsp_project_not_loaded"
      : "symbol_not_found";
  const status = verdict === "symbol_navigation_ready" ? "ready" : "missing_prereqs";

  process.stdout.write(JSON.stringify({
    mode: "lsp_direct_fallback",
    status,
    verdict,
    workspacePath,
    csharpLsCommand,
    serverInfo: initialize.result && initialize.result.serverInfo,
    stderrTail: stderr,
    notifications: notifications.slice(-20),
    queries,
  }));
}

main().catch((error) => {
  process.stdout.write(JSON.stringify({
    mode: "lsp_direct_fallback",
    status: "missing_prereqs",
    verdict: "lsp_project_not_loaded",
    workspacePath,
    error: error.message,
    queries: [],
  }));
  process.exitCode = 0;
});
