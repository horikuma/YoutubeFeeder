

import * as vscode from 'vscode';

/**
 * SourceViewConfig
 *
 * 言語ごとの設定（拡張子 / ヘッダフォーマット）
 */
export type SourceViewConfig = {
  extensions: string[];
  header: (filePath: string) => string;
};

/**
 * SourceViewAdapter
 *
 * フォルダ配下の指定拡張子ファイルをすべて収集し、
 * 連結した lines[] を返す
 */
export class SourceViewAdapter {
  private rootPath: string;
  private config: SourceViewConfig;

  constructor(rootPath: string, config: SourceViewConfig) {
    this.rootPath = rootPath;
    this.config = config;
  }

  async getLines(): Promise<string[]> {
    const { extensions, header } = this.config;

    const extGlob = extensions.length === 1
      ? `**/*.${extensions[0]}`
      : `**/*.{${extensions.join(',')}}`;

    const workspaceRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? '';

    const normalizedRoot = this.rootPath.replace(/\\/g, '/');
    const normalizedWs = workspaceRoot.replace(/\\/g, '/');

    let relativeRoot = normalizedRoot.startsWith(normalizedWs)
      ? normalizedRoot.slice(normalizedWs.length)
      : normalizedRoot;

    relativeRoot = relativeRoot.replace(/^\/+/, '');

    const includeGlob = relativeRoot
      ? `${relativeRoot}/${extGlob}`
      : extGlob;
    const excludeGlob = '**/{node_modules,.git,DerivedData}/**';

    const files = await vscode.workspace.findFiles(includeGlob, excludeGlob);
    files.sort((a, b) => a.fsPath.toLowerCase().localeCompare(b.fsPath.toLowerCase()));

    if (files.length === 0) {
      const debug: string[] = [];
      debug.push('[No files matched]');
      debug.push(`includeGlob: ${includeGlob}`);
      debug.push(`excludeGlob: ${excludeGlob}`);
      debug.push(`rootPath: ${this.rootPath}`);
      debug.push(`extensions: ${extensions.join(',')}`);
      return debug;
    }

    const lines: string[] = [];

    for (const file of files) {
      try {
        lines.push(header(file.fsPath));

        const data = await vscode.workspace.fs.readFile(file);
        const text = Buffer.from(data).toString('utf8');

        const fileLines = text.split(/\r?\n/);
        lines.push(...fileLines);

        lines.push('');
      } catch {
        lines.push(`[Error reading file: ${file.fsPath}]`);
      }
    }

    return lines;
  }
}

/**
 * 共通設定
 */
export const SOURCE_VIEW_CONFIGS = {
  ts: {
    extensions: ['ts'],
    header: (p: string) => `// ===== ${p} =====`
  },
  swift: {
    extensions: ['swift'],
    header: (p: string) => `// ===== ${p} =====`
  },
  c: {
    extensions: ['c', 'h'],
    header: (p: string) => `// ===== ${p} =====`
  }
};