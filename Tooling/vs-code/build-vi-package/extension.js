const vscode = require('vscode');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// 1) Where we store version data. Similar to your previous extension.
const VERSION_FILE_PATH = 'C:\\Users\\Public\\Documents\\BuildVersion\\BuildVI.json';
const LOGS_FOLDER = path.dirname(VERSION_FILE_PATH);

// 2) Name of your primary PowerShell script
const PS_SCRIPT_NAME = 'Build.ps1';

// 3) Default data if the JSON file doesn't exist
const DEFAULT_DATA = {
  // We won't store RelativePath or AbsolutePathScripts permanently—
//   but let's do so anyway, so user changes persist if you want
  RelativePath: "",
  Major: 1,
  Minor: 0,
  Patch: 0,
  Build: 0,
  Commit: "Placeholder"
};

/**
 * Called when your extension is activated
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
  // Create a status bar item labeled "Build VI Package"
  const buildVIPStatusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Left,
    100
  );
  buildVIPStatusBarItem.command = 'extension.buildVIPackage';
  buildVIPStatusBarItem.text = '$(package) Build VI Package';
  buildVIPStatusBarItem.tooltip = 'Build VI Package (auto path discovery)';
  buildVIPStatusBarItem.show();

  // Register the command
  const buildVIPCommand = vscode.commands.registerCommand('extension.buildVIPackage', async () => {
    try {
      // 1) Load or create version data
      let data = await loadVersionData();

      // 2) If the user has a workspace open, auto-set RelativePath 
      //    to the workspace root if not already set
      if (vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0) {
        const workspacePath = vscode.workspace.workspaceFolders[0].uri.fsPath;
        if (!data.RelativePath) {
          data.RelativePath = workspacePath;
        }
        // The same approach we used previously: pipeline/scripts
        data.AbsolutePathScripts = path.join(workspacePath, 'pipeline', 'scripts');
      } else {
        // If no workspace is open, we can't auto-discover
        vscode.window.showWarningMessage("No workspace folder open; paths cannot be auto-discovered!");
        return;
      }

      // 3) Gather user inputs for version fields (Major, Minor, Patch, Build, Commit)
      //    (We won't prompt for RelativePath or AbsolutePathScripts to keep it fully auto.)
      data = await gatherInputs(data);

      // 4) Persist changes
      await saveVersionData(data);

      // 5) Run Build.ps1 with real-time logs
      const psOutput = await runPowerShellScript(data);

      // 6) On success, increment Build
      data.Build = data.Build + 1;
      await saveVersionData(data);

      // 7) Save logs to a timestamped file
      const logFile = await writeLogs(psOutput);

      // 8) Notify user
      const openLogAction = 'Open Log';
      vscode.window.showInformationMessage(
        `Build VI Package succeeded! Version: ${data.Major}.${data.Minor}.${data.Patch}.${data.Build - 1}.`,
        openLogAction
      ).then(selection => {
        if (selection === openLogAction) {
          vscode.workspace.openTextDocument(logFile).then(doc => {
            vscode.window.showTextDocument(doc);
          });
        }
      });
    } catch (err) {
      vscode.window.showErrorMessage(`Build VI Package failed: ${err.message || err}`);
    }
  });

  context.subscriptions.push(buildVIPStatusBarItem);
  context.subscriptions.push(buildVIPCommand);
}

function deactivate() {
  // Cleanup if necessary
}

/**
 * Load or create the version JSON file (like BuildVI.json)
 */
async function loadVersionData() {
  return new Promise((resolve) => {
    if (!fs.existsSync(VERSION_FILE_PATH)) {
      fs.mkdirSync(path.dirname(VERSION_FILE_PATH), { recursive: true });
      fs.writeFileSync(VERSION_FILE_PATH, JSON.stringify(DEFAULT_DATA, null, 2), 'utf-8');
      return resolve(Object.assign({}, DEFAULT_DATA));
    }
    const content = fs.readFileSync(VERSION_FILE_PATH, 'utf-8');
    try {
      const data = JSON.parse(content);
      const merged = { ...DEFAULT_DATA, ...data };
      resolve(merged);
    } catch (e) {
      // If file is corrupted, overwrite with defaults
      fs.writeFileSync(VERSION_FILE_PATH, JSON.stringify(DEFAULT_DATA, null, 2), 'utf-8');
      resolve(Object.assign({}, DEFAULT_DATA));
    }
  });
}

/**
 * Save the version JSON file
 */
async function saveVersionData(data) {
  return new Promise((resolve, reject) => {
    const jsonString = JSON.stringify(data, null, 2);
    fs.writeFile(VERSION_FILE_PATH, jsonString, 'utf-8', (err) => {
      if (err) return reject(err);
      resolve();
    });
  });
}

/**
 * Gathers user inputs for Major, Minor, Patch, Build, Commit
 * (Leaving paths auto-discovered from the workspace.)
 */
async function gatherInputs(data) {
  // Track old major/minor
  const oldMajor = data.Major;
  const oldMinor = data.Minor;

  // Prompt for Major
  data.Major = await promptNumber("Major version:", data.Major);
  if (data.Major !== oldMajor) {
    data.Minor = 0;
    data.Patch = 0;
  }

  // Prompt for Minor
  data.Minor = await promptNumber("Minor version:", data.Minor);
  if (data.Minor !== oldMinor) {
    data.Patch = 0;
  }

  // Prompt for Patch
  data.Patch = await promptNumber("Patch version:", data.Patch);

  // Prompt for Build
  data.Build = await promptNumber("Build number (auto-increment on success):", data.Build);

  // Prompt for Commit
  data.Commit = await promptString("Commit string:", data.Commit);

  // Basic validations
  if (data.Major < 0) data.Major = 0;
  if (data.Minor < 0) data.Minor = 0;
  if (data.Patch < 0) data.Patch = 0;
  if (data.Build < 0) data.Build = 0;

  return data;
}

/**
 * Prompt for a string with default value
 */
async function promptString(promptMsg, defaultVal) {
  const result = await vscode.window.showInputBox({
    prompt: promptMsg,
    value: defaultVal || ""
  });
  if (result === undefined) {
    return defaultVal; // user canceled
  }
  return result;
}

/**
 * Prompt for a number with default value
 */
async function promptNumber(promptMsg, defaultVal) {
  const result = await vscode.window.showInputBox({
    prompt: promptMsg,
    value: defaultVal != null ? defaultVal.toString() : "0",
    validateInput: (val) => {
      if (/^\d+$/.test(val)) return null; // valid
      return "Please enter a non-negative integer.";
    }
  });
  if (result === undefined) {
    return defaultVal; // user canceled
  }
  return parseInt(result, 10);
}

/**
 * Run Build.ps1 in real time with spawn, streaming logs to an Output Channel
 */
async function runPowerShellScript(data) {
  return new Promise((resolve, reject) => {
    const outputChannel = vscode.window.createOutputChannel("Build VI Package (Live Logs)");
    outputChannel.show(true);

    // We discovered these automatically:
    const relativePath = data.RelativePath;
    const absoluteScripts = data.AbsolutePathScripts;

    // Build the full path to Build.ps1
    const scriptFullPath = path.join(absoluteScripts, PS_SCRIPT_NAME);

    // Construct the arguments needed by Build.ps1
    const psArgs = [
      '-NoProfile',
      scriptFullPath,
      '-RelativePath', relativePath,
      '-AbsolutePathScripts', absoluteScripts,
      '-Major', data.Major.toString(),
      '-Minor', data.Minor.toString(),
      '-Patch', data.Patch.toString(),
      '-Build', data.Build.toString(),
      '-Commit', data.Commit
    ];

    // We'll spawn from the scripts folder
    const proc = spawn("pwsh", psArgs, { cwd: absoluteScripts });
    let combinedOutput = "";

    proc.stdout.on("data", chunk => {
      const text = chunk.toString();
      combinedOutput += text;
      outputChannel.append(text);
    });

    proc.stderr.on("data", chunk => {
      const text = chunk.toString();
      combinedOutput += text;
      outputChannel.append(text);
    });

    proc.on("close", code => {
      if (code === 0) {
        resolve(combinedOutput);
      } else {
        reject(new Error(`Build.ps1 exited with code ${code}\n${combinedOutput}`));
      }
    });

    proc.on("error", err => {
      reject(err);
    });
  });
}

/**
 * Write logs to a timestamped file
 */
async function writeLogs(content) {
  return new Promise((resolve, reject) => {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const fileName = `BuildVIPLog-${timestamp}.txt`;
    const fullPath = path.join(LOGS_FOLDER, fileName);

    fs.writeFile(fullPath, content, 'utf-8', (err) => {
      if (err) return reject(err);
      resolve(fullPath);
    });
  });
}

module.exports = {
  activate,
  deactivate
};
