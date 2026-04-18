import * as assert from 'assert';

// You can import and use all API from the 'vscode' module
// as well as import your extension to test it
import * as vscode from 'vscode';

import { runPipeline } from '../pipeline';

suite('Extension Test Suite', () => {
	vscode.window.showInformationMessage('Start all tests.');

	test('Command pipeline renders 1000 fixed virtual text lines', () => {
		let decorations: readonly vscode.DecorationOptions[] | undefined;
		const editor = {
			setDecorations(_decorationType: vscode.TextEditorDecorationType, nextDecorations: readonly vscode.DecorationOptions[]) {
				decorations = nextDecorations;
			},
		} as vscode.TextEditor;

		runPipeline(editor);

		assert.ok(decorations);
		assert.strictEqual(decorations?.length, 1000);
		assert.ok(
			decorations?.every((decoration, index) =>
				decoration.range.start.line === index
				&& decoration.range.end.line === index
				&& decoration.renderOptions?.before?.contentText === `line ${index + 1}`,
			),
		);
	});
});
