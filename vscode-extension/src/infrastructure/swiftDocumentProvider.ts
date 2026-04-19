

import * as vscode from 'vscode';
import { SwiftConcatAdapter } from '../adapter/swiftConcatAdapter';

/**
 * SwiftDocumentProvider
 *
 * Swiftファイル連結ビューを提供する TextDocumentContentProvider
 */
export class SwiftDocumentProvider implements vscode.TextDocumentContentProvider {
  private adapter = new SwiftConcatAdapter();

  async provideTextDocumentContent(uri: vscode.Uri): Promise<string> {
    const lines = await this.adapter.getLines();
    return lines.join('\n');
  }
}