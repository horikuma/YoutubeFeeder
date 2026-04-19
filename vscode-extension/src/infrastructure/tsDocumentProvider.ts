

import * as vscode from 'vscode';
import { TsConcatAdapter } from '../adapter/tsConcatAdapter';

/**
 * TsDocumentProvider
 *
 * TypeScriptファイル連結ビューを提供する TextDocumentContentProvider
 */
export class TsDocumentProvider implements vscode.TextDocumentContentProvider {
  private adapter = new TsConcatAdapter();

  async provideTextDocumentContent(uri: vscode.Uri): Promise<string> {
    const lines = await this.adapter.getLines();
    return lines.join('\n');
  }
}