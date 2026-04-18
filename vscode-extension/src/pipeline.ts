import * as vscode from 'vscode';

import { apply } from './apply';
import { createAdapter } from './adapter';
import { diff } from './diff';
import { render } from './renderer';
import { createUpdateController } from './updateController';
import { createViewport } from './viewport';

export function runPipeline(editor: vscode.TextEditor): vscode.TextEditorDecorationType {
	const viewport = createViewport();
	const updateController = createUpdateController();
	const adapter = createAdapter();
	const updatedViewport = updateController.update(viewport);
	const lines = adapter.getLines(updatedViewport.startLine, updatedViewport.endLine);
	const decorations = render(lines);
	const replacement = diff(undefined, decorations);
	return apply(editor, replacement);
}
