# Contributing

This repository includes a Visual Studio Code workspace configuration in the `.vscode` folder.
Importing these settings ensures consistent linting and formatting across contributors.

1. Open the repository in [Visual Studio Code](https://code.visualstudio.com/).
2. When prompted, install the recommended extensions from `.vscode/extensions.json`:
   - C# (`ms-dotnettools.csharp`)
   - EditorConfig (`EditorConfig.EditorConfig`)
   - Prettier (`esbenp.prettier-vscode`)
   - ESLint (`dbaeumer.vscode-eslint`)
3. The workspace settings in `.vscode/settings.json` mirror `.editorconfig` rules:
   4-space indentation, LF line endings, trailing whitespace trimming, and final newlines.
   `editor.formatOnSave` is enabled and Prettier is the default formatter for Markdown and JSON files.
4. Run `pre-commit run --files <changed files>` before committing to verify linting and formatting.

Adopting these settings keeps the codebase aligned with existing style guidelines and automated formatters.
