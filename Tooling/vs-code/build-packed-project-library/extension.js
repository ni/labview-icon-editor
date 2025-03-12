const vscode = require('vscode');

/**
 * Called when your extension is activated
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
  let disposable = vscode.commands.registerCommand('myExtension.run', function () {
    vscode.window.showInformationMessage('My brand-new extension is running!');
  });

  context.subscriptions.push(disposable);
}

/**
 * Called when your extension is deactivated
 */
function deactivate() {}

module.exports = {
  activate,
  deactivate
};
