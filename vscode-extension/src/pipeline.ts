// Pipeline は、Viewport から Apply までを 1 回つなぐ。
// Pipeline は、各層の内部責務を実装しない。
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
