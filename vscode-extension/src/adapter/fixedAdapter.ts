

/**
 * FixedAdapter
 *
 * テスト用の固定データを返すAdapter
 * PipelineやProviderの動作確認用
 */
export class FixedAdapter {
  async getLines(): Promise<string[]> {
    return [
      '// ===== FixedAdapter =====',
      'line 1: hello',
      'line 2: world',
      '',
      'line 4: fixed data end'
    ];
  }
}