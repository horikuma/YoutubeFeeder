

import { FileConcatAdapter } from './fileConcatAdapter';

/**
 * TsConcatAdapter
 *
 * ワークスペース配下の src ディレクトリにある .ts ファイルを連結して返す
 */
export class TsConcatAdapter {
  private inner: FileConcatAdapter;

  constructor() {
    this.inner = new FileConcatAdapter(
      '**/src/**/*.ts',
      '**/node_modules/**',
      (filePath: string) => `// ===== ${filePath} =====`
    );
  }

  async getLines(): Promise<string[]> {
    return this.inner.getLines();
  }
}