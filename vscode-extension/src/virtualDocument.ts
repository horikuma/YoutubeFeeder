import * as vscode from 'vscode';

export class TsConcatProvider implements vscode.TextDocumentContentProvider {
  async provideTextDocumentContent(uri: vscode.Uri): Promise<string> {
    if (!vscode.workspace.workspaceFolders || vscode.workspace.workspaceFolders.length === 0) {
      const workspaceFile = vscode.workspace.workspaceFile?.fsPath ?? 'undefined';
      const openedEditors = vscode.window.visibleTextEditors.map(e => e.document.uri.fsPath).join('\n') || 'none';
      const cwd = process.cwd();

      return [
        'No workspace (workspaceFolders empty)',
        `process.cwd(): ${cwd}`,
        `workspaceFile: ${workspaceFile}`,
        'visibleTextEditors:',
        openedEditors
      ].join('\n');
    }
  
    const root = vscode.workspace.workspaceFolders[0].uri;

    let result = `Workspace root: ${root.fsPath}\n`;

    const files = await vscode.workspace.findFiles(
      '**/src/**/*.ts',
      '**/node_modules/**'
    );

    for (const file of files) {
      const content = await vscode.workspace.fs.readFile(file);
      const text = Buffer.from(content).toString('utf8');

      result += `\n===== ${file.fsPath} =====\n`;
      result += text + '\n';
    }

    return result;
  }
}