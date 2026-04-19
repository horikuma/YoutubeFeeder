

import * as vscode from 'vscode';

/**
 * FileConcatAdapter
 *
 * 指定されたglobに従ってファイルを列挙し、
 * 各ファイルの内容を連結して lines[] として返す
 */
export class FileConcatAdapter {
  private includeGlob: string;
  private excludeGlob: string;
  private headerFormatter: (filePath: string) => string;

  constructor(
    includeGlob: string,
    excludeGlob: string,
    headerFormatter: (filePath: string) => string
  ) {
    this.includeGlob = includeGlob;
    this.excludeGlob = excludeGlob;
    this.headerFormatter = headerFormatter;
  }

  async getLines(): Promise<string[]> {
    const workspaceFolders = vscode.workspace.workspaceFolders;

    if (!workspaceFolders || workspaceFolders.length === 0) {
      return ['[No workspace]'];
    }

    const files = await vscode.workspace.findFiles(
      this.includeGlob,
      this.excludeGlob
    );

    if (files.length === 0) {
      const workspaceFolders = vscode.workspace.workspaceFolders ?? [];
      const roots = workspaceFolders.map(f => f.uri.fsPath);

      const debug: string[] = [];
      debug.push('[No files matched]');
      debug.push('');
      debug.push(`includeGlob: ${this.includeGlob}`);
      debug.push(`excludeGlob: ${this.excludeGlob}`);
      debug.push('');

      if (roots.length === 0) {
        debug.push('workspaceRoots: [none]');
      } else {
        debug.push('workspaceRoots:');
        for (const r of roots) {
          debug.push(`  - ${r}`);
        }
      }

      // Absolute-like hints for how the glob might expand from each root
      for (const r of roots) {
        debug.push(`hint: ${r}/${this.includeGlob}`);
      }

      // Additional context
      debug.push('');
      debug.push(`cwd: ${process.cwd?.() ?? '[unknown]'}`);
      debug.push(`workspace.name: ${vscode.workspace.name ?? '[none]'}`);

      return debug;
    }

    const lines: string[] = [];

    for (const file of files) {
      try {
        const header = this.headerFormatter(file.fsPath);
        lines.push(header);

        const data = await vscode.workspace.fs.readFile(file);
        const text = Buffer.from(data).toString('utf8');

        const fileLines = text.split(/\r?\n/);
        lines.push(...fileLines);

        lines.push(''); // separator
      } catch (e) {
        lines.push(`[Error reading file: ${file.fsPath}]`);
      }
    }

    return lines;
  }
}