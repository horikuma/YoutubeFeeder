// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from 'vscode';

import { runPipeline } from './pipeline';
import { TsDocumentProvider } from './infrastructure/tsDocumentProvider';
import { SwiftDocumentProvider } from './infrastructure/swiftDocumentProvider';

// This method is called when your extension is activated
// Your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {

	// Use the console to output diagnostic information (console.log) and errors (console.error)
	// This line of code will only be executed once when your extension is activated
	console.log('Congratulations, your extension "helloworld" is now active!');

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

	const tsProvider = new TsDocumentProvider();
	const tsScheme = 'tsconcat';

	context.subscriptions.push(
		vscode.workspace.registerTextDocumentContentProvider(tsScheme, tsProvider)
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('extension.openTsConcat', async () => {
			const uri = vscode.Uri.parse(`${tsScheme}:/all-ts.ts`);
			const doc = await vscode.workspace.openTextDocument(uri);
			vscode.window.showTextDocument(doc, { preview: false });
		})
	);

	const swiftProvider = new SwiftDocumentProvider();
	const swiftScheme = 'swiftconcat';

	context.subscriptions.push(
		vscode.workspace.registerTextDocumentContentProvider(swiftScheme, swiftProvider)
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('extension.openSwiftConcat', async () => {
			const uri = vscode.Uri.parse(`${swiftScheme}:/all-swift.swift`);
			const doc = await vscode.workspace.openTextDocument(uri);
			vscode.window.showTextDocument(doc, { preview: false });
		})
	);
}

// This method is called when your extension is deactivated
export function deactivate() {}
