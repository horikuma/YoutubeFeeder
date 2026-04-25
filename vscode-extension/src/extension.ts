// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from 'vscode';

import { runPipeline } from './pipeline';
import { SourceViewAdapter, SOURCE_VIEW_CONFIGS } from './adapter/sourceViewAdapter';

const SOURCE_VIEW_SCHEME = 'sourceview';

class SourceViewProvider implements vscode.TextDocumentContentProvider {
  async provideTextDocumentContent(uri: vscode.Uri): Promise<string> {
    const params = new URLSearchParams(uri.query);
    const folderPath = decodeURIComponent(params.get('path') || '');
    const key = params.get('key') as keyof typeof SOURCE_VIEW_CONFIGS;

    if (!folderPath || !key) {
      return '[Invalid parameters]';
    }

    const adapter = new SourceViewAdapter(folderPath, SOURCE_VIEW_CONFIGS[key]);
    const lines = await adapter.getLines();
    return lines.join('\n');
  }
}

// This method is called when your extension is activated
// Your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {

	// Use the console to output diagnostic information (console.log) and errors (console.error)
	// This line of code will only be executed once when your extension is activated
	console.log('Congratulations, your extension "helloworld" is now active!');

	const provider = new SourceViewProvider();
	context.subscriptions.push(
	  vscode.workspace.registerTextDocumentContentProvider(SOURCE_VIEW_SCHEME, provider)
	);

	// The command has been defined in the package.json file
	// Now provide the implementation of the command with registerCommand
	// The commandId parameter must match the command field in package.json
	const disposable = vscode.commands.registerCommand('helloworld.helloWorld', () => {
		const editor = vscode.window.activeTextEditor;
		if (!editor) {
			vscode.window.showWarningMessage('Open an editor to run HelloWorld.');
			return;
		}

		runPipeline(editor);
	});

	context.subscriptions.push(disposable);

	const openSourceView = async (uri: vscode.Uri | undefined, key: keyof typeof SOURCE_VIEW_CONFIGS) => {
		if (!uri) {
			vscode.window.showErrorMessage('No folder selected');
			return;
		}

		const folderPath = uri.fsPath;

		const uriToOpen = vscode.Uri.parse(
		  `${SOURCE_VIEW_SCHEME}:/view?path=${encodeURIComponent(folderPath)}&key=${key}`
		);

		const doc = await vscode.workspace.openTextDocument(uriToOpen);
		vscode.window.showTextDocument(doc, { preview: false });
	};

	context.subscriptions.push(
		vscode.commands.registerCommand('extension.openSourceView.ts', (uri) => openSourceView(uri, 'ts'))
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('extension.openSourceView.swift', (uri) => openSourceView(uri, 'swift'))
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('extension.openSourceView.c', (uri) => openSourceView(uri, 'c'))
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('extension.openSourceView.md', (uri) => openSourceView(uri, 'md'))
	);
}

// This method is called when your extension is deactivated
export function deactivate() {}
