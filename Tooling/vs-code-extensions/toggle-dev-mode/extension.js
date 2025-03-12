const vscode = require('vscode');
const { exec } = require('child_process');

// We'll store the status bar item here so we can update it when toggled
let devModeStatusBarItem;

// For brevity, let's define a key for workspaceState:
const DEV_MODE_STATE_KEY = 'devModeEnabled';

/**
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
  // 1) Initialize devModeEnabled from stored workspaceState, defaulting to false if not set
  let devModeEnabled = context.workspaceState.get(DEV_MODE_STATE_KEY, false);

  // 2) Create a status bar item (aligned to the left, with priority 100)
  devModeStatusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Left,
    100
  );

  devModeStatusBarItem.tooltip = 'Toggle Dev Mode';
  // Assign the command that will be invoked on click
  devModeStatusBarItem.command = 'extension.toggleDevMode';
  
  // 3) Define a function to update the status bar text and color
  function updateStatusBar() {
    if (devModeEnabled) {
      devModeStatusBarItem.text = '$(play) Dev Mode: ON';
      devModeStatusBarItem.color = new vscode.ThemeColor('statusBar.foreground');
    } else {
      devModeStatusBarItem.text = '$(debug-stop) Dev Mode: OFF';
      devModeStatusBarItem.color = new vscode.ThemeColor('statusBar.foreground');
    }
  }

  // Initialize the status bar text on extension load
  updateStatusBar();
  devModeStatusBarItem.show();

  // 4) Register the toggle command
  let toggleCommand = vscode.commands.registerCommand('extension.toggleDevMode', async () => {
    try {
      // Decide which script to run based on current state
      let scriptToRun = devModeEnabled
        ? 'RevertDevelopmentMode.ps1'
        : 'Set_Development_Mode.ps1';

      // Construct the PowerShell command
      // We'll assume your scripts live in 'pipeline/scripts' inside the workspace
      // and rely on 'pwsh' for cross-platform usage.
      let scriptDir = `${vscode.workspace.rootPath}/pipeline/scripts`;
      let command = `pwsh -NoProfile -Command "cd '${scriptDir}'; ./${scriptToRun} -RelativePath '${vscode.workspace.rootPath}'"`;

      // Execute the command
      exec(command, (error, stdout, stderr) => {
        if (error) {
          vscode.window.showErrorMessage(`Error toggling dev mode: ${error.message}`);
          console.error(error);
          return;
        }
        if (stderr && stderr.trim().length > 0) {
          // If there's a warning or non-critical error, show it
          vscode.window.showWarningMessage(`Script warning: ${stderr}`);
          console.warn(stderr);
        }

        // Toggle the in-memory state
        devModeEnabled = !devModeEnabled;
        // Persist the new state
        context.workspaceState.update(DEV_MODE_STATE_KEY, devModeEnabled);

        // Update status bar
        updateStatusBar();

        // Show success message
        vscode.window.showInformationMessage(
          `Dev Mode is now ${devModeEnabled ? 'ENABLED' : 'DISABLED'}`
        );
      });
    } catch (err) {
      vscode.window.showErrorMessage(`Failed to toggle dev mode: ${err}`);
    }
  });

  // 5) Push the command and status bar item to subscriptions so they are cleaned up properly
  context.subscriptions.push(toggleCommand);
  context.subscriptions.push(devModeStatusBarItem);
}

function deactivate() {
  // Cleanup if needed (not strictly necessary in this simple example)
}

module.exports = {
  activate,
  deactivate
};
