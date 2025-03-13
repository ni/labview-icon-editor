const vscode = require('vscode');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// PUBLIC JSON FILE LOCATION (Windows)
const VERSION_FILE_PATH = 'C:\\Users\\Public\\Documents\\BuildVersion\\VersionInfo.json';
// We'll also store logs in the same folder
const LOGS_FOLDER = path.dirname(VERSION_FILE_PATH);

// Name of your PowerShell script
const PS_SCRIPT_NAME = 'Build_lvlibp.ps1';

// Default values if version file doesn't exist
const DEFAULT_DATA = {
  MinimumSupportedLVVersion: "2021",
  SupportedBitness: "64",
  RelativePath: "", // We'll discover from workspace
  major: 1,
  minor: 0,
  patch: 0,
  build: 0,
  commit: ""
};

/**
 * Entry point when extension is activated
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
  // 1) Create a status bar item for single-click
  const buildPPLStatusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Left,
    100 // priority
  );
  buildPPLStatusBarItem.command = 'extension.buildPackedProjectLibrary';
  buildPPLStatusBarItem.text = '$(package) Build PPL';
  buildPPLStatusBarItem.tooltip = 'Build Packed "Project Library" with versioning';
  buildPPLStatusBarItem.show();

  // 2) Register the main command
  const buildPPLCommand = vscode.commands.registerCommand('extension.buildPackedProjectLibrary', async () => {
    try {
      // a) Read or create the JSON file
      let data = await loadVersionData();

      // b) Discover the relative path from current workspace (if none stored)
      if (!data.RelativePath && vscode.workspace.workspaceFolders) {
        data.RelativePath = vscode.workspace.workspaceFolders[0].uri.fsPath;
      }

      // c) Gather inputs via multi-step approach
      data = await gatherInputs(data);

      // d) Persist changes to file (if user changed major/minor/patch/commit, etc.)
      await saveVersionData(data);

      // e) Run the PowerShell script with live output
      //    This now streams output to an Output Channel instead of buffering
      const psOutput = await runPowerShellScript(data);

      // f) If success, increment build number and persist
      data.build = data.build + 1; 
      await saveVersionData(data);

      // g) Write logs to a file
      const logFile = await writeLogs(psOutput);

      // h) Optionally show the log file in VS Code
      const openLogAction = 'Open Log';
      vscode.window.showInformationMessage(
        `Build succeeded! Version: ${data.major}.${data.minor}.${data.patch}.${data.build - 1}. Log saved.`,
        openLogAction
      ).then(selection => {
        if (selection === openLogAction) {
          vscode.workspace.openTextDocument(logFile).then(doc => {
            vscode.window.showTextDocument(doc);
          });
        }
      });

    } catch (err) {
      vscode.window.showErrorMessage(`Build PPL failed: ${err.message || err}`);
    }
  });

  context.subscriptions.push(buildPPLStatusBarItem);
  context.subscriptions.push(buildPPLCommand);
}

/**
 * Reads or creates the version info JSON file.
 * @returns {Promise<{
 *   MinimumSupportedLVVersion:string,
 *   SupportedBitness:string,
 *   RelativePath:string,
 *   major:number,
 *   minor:number,
 *   patch:number,
 *   build:number,
 *   commit:string
 * }>}
 */
async function loadVersionData() {
  return new Promise((resolve) => {
    if (!fs.existsSync(VERSION_FILE_PATH)) {
      // If file doesn't exist, create it with defaults
      fs.mkdirSync(path.dirname(VERSION_FILE_PATH), { recursive: true });
      fs.writeFileSync(VERSION_FILE_PATH, JSON.stringify(DEFAULT_DATA, null, 2), 'utf-8');
      return resolve(Object.assign({}, DEFAULT_DATA));
    }

    // If it exists, read and parse
    const content = fs.readFileSync(VERSION_FILE_PATH, 'utf-8');
    try {
      const data = JSON.parse(content);
      // Merge any missing fields from DEFAULT_DATA
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
 * Saves the version info JSON file with updated data
 * @param {*} data
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
 * Gathers user inputs for:
 * MinimumSupportedLVVersion, SupportedBitness, Major, Minor, Patch, Build, Commit
 * using multiple "showInputBox" calls.
 * Applies auto-reset logic for major/minor changes (never resets build).
 * @param {*} data
 */
async function gatherInputs(data) {
  const oldMajor = data.major;
  const oldMinor = data.minor;
  const oldPatch = data.patch;

  // 1) MinimumSupportedLVVersion
  data.MinimumSupportedLVVersion = await promptString(
    "Enter MinimumSupportedLVVersion:",
    data.MinimumSupportedLVVersion
  );

  // 2) SupportedBitness
  data.SupportedBitness = await promptString(
    "Enter SupportedBitness (32 or 64):",
    data.SupportedBitness
  );

  // 3) Major
  data.major = await promptNumber("Enter Major version:", data.major);
  if (data.major !== oldMajor) {
    // Reset minor & patch if major changed
    data.minor = 0;
    data.patch = 0;
  }

  // 4) Minor
  data.minor = await promptNumber("Enter Minor version:", data.minor);
  if (data.minor !== oldMinor) {
    // Reset patch if minor changed
    data.patch = 0;
  }

  // 5) Patch
  data.patch = await promptNumber("Enter Patch version:", data.patch);

  // 6) Build (we won't reset it automatically, but let user change if needed)
  data.build = await promptNumber("Enter Build number (will auto-increment on success):", data.build);

  // 7) Commit
  data.commit = await promptString("Enter Commit string (optional):", data.commit);

  // Negative check or any other validations
  if (data.major < 0) data.major = 0;
  if (data.minor < 0) data.minor = 0;
  if (data.patch < 0) data.patch = 0;
  if (data.build < 0) data.build = 0;

  return data;
}

/**
 * Utility: Prompt for a string with default value
 * @param {string} prompt
 * @param {string} defaultVal
 */
async function promptString(prompt, defaultVal) {
  const result = await vscode.window.showInputBox({
    prompt,
    value: defaultVal || ""
  });
  // If user cancels, result is undefined; just return the old default
  if (result === undefined) {
    return defaultVal;
  }
  return result;
}

/**
 * Utility: Prompt for a number with default value
 * @param {string} prompt
 * @param {number} defaultVal
 */
async function promptNumber(prompt, defaultVal) {
  const result = await vscode.window.showInputBox({
    prompt,
    value: defaultVal != null ? defaultVal.toString() : "0",
    validateInput: (val) => {
      if (/^\d+$/.test(val)) {
        return null; // valid
      } else {
        return "Please enter a non-negative integer.";
      }
    }
  });
  if (result === undefined) {
    // user canceled => return old value
    return defaultVal;
  }
  return parseInt(result, 10);
}

/**
 * Runs the Build_lvlibp.ps1 script via pwsh with all parameters from data,
 * streaming output in real time to a VS Code Output Channel.
 * Returns the combined output (stdout+stderr) so we can also log it.
 */
async function runPowerShellScript(data) {
  return new Promise((resolve, reject) => {
    // 1) Ensure we have an open workspace
    if (!vscode.workspace.workspaceFolders || vscode.workspace.workspaceFolders.length === 0) {
      return reject(new Error("No workspace folder is open in VS Code."));
    }

    // 2) Build the path to your scripts folder, e.g. <workspace>/pipeline/scripts
    const workspacePath = vscode.workspace.workspaceFolders[0].uri.fsPath;
    const scriptDir = path.join(workspacePath, 'pipeline', 'scripts');

    // 3) Create an Output Channel so we see real-time logs
    const outputChannel = vscode.window.createOutputChannel("Build PPL Live");
    outputChannel.show(true); // show it immediately

    // 4) Construct arguments for the PowerShell script
    // We'll pass them as separate items in an array to spawn:
    const psArgs = [
      "-NoProfile",
      "./" + PS_SCRIPT_NAME,
      "-MinimumSupportedLVVersion", data.MinimumSupportedLVVersion,
      "-SupportedBitness", data.SupportedBitness,
      "-RelativePath", data.RelativePath,
      "-Major", data.major.toString(),
      "-Minor", data.minor.toString(),
      "-Patch", data.patch.toString(),
      "-Build", data.build.toString(),
      "-Commit", data.commit
    ];

    // 5) Spawn pwsh so we can read stdout/stderr in real time
    const ps = spawn("pwsh", psArgs, { cwd: scriptDir });

    let combinedOutput = "";

    // 6) On each chunk of stdout, append to the channel and our combined logs
    ps.stdout.on("data", (chunk) => {
      const text = chunk.toString();
      combinedOutput += text;
      outputChannel.append(text);
    });

    // 7) Same for stderr
    ps.stderr.on("data", (chunk) => {
      const text = chunk.toString();
      combinedOutput += text;
      // We can color it differently or just append the same
      outputChannel.append(text);
    });

    // 8) Listen for when the process closes
    ps.on("close", (code) => {
      if (code === 0) {
        resolve(combinedOutput); // success
      } else {
        reject(new Error(`PowerShell script exited with code ${code}\n${combinedOutput}`));
      }
    });

    // 9) Catch spawn errors (e.g., pwsh not found)
    ps.on("error", (err) => {
      reject(err);
    });
  });
}

/**
 * Writes the PowerShell output to a timestamped log file in LOGS_FOLDER
 * Returns the path to the log file.
 * @param {string} content
 */
async function writeLogs(content) {
  return new Promise((resolve, reject) => {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const fileName = `BuildLog-${timestamp}.txt`;
    const fullPath = path.join(LOGS_FOLDER, fileName);

    fs.writeFile(fullPath, content, 'utf-8', (err) => {
      if (err) return reject(err);
      resolve(fullPath);
    });
  });
}

function deactivate() {
  // Cleanup if needed
}

module.exports = {
  activate,
  deactivate
};
