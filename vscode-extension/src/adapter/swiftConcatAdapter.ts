import { FileConcatAdapter } from './fileConcatAdapter';

/**
 * SwiftConcatAdapter
 *
 * YoutubeFeeder/YoutubeFeeder/src 配下の .swift ファイルを連結して返す
 */
export class SwiftConcatAdapter {
  private inner: FileConcatAdapter;

  constructor() {
    this.inner = new FileConcatAdapter(
      'YoutubeFeeder/**/*.swift',
      '**/node_modules/**',
      (filePath: string) => `// ===== ${filePath} =====`
    );
  }

  async getLines(): Promise<string[]> {
    return this.inner.getLines();
  }
}
