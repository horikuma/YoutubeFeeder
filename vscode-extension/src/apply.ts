import * as vscode from 'vscode';

import { RendererDecoration } from './renderer';

export function apply(
	editor: vscode.TextEditor,
	decorations: readonly RendererDecoration[],
): vscode.TextEditorDecorationType {
	const decorationType = vscode.window.createTextEditorDecorationType({});
	editor.setDecorations(
		decorationType,
		decorations.map((decoration) => ({
			range: new vscode.Range(decoration.lineNumber, 0, decoration.lineNumber, 0),
			renderOptions: {
				before: {
					contentText: decoration.virtualText,
				},
			},
		})),
	);
	return decorationType;
}
