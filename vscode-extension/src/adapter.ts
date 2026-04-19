// Adapter は、固定テキストから要求範囲の行を取り出す。
// Adapter は、Viewport 制御や装飾反映を扱わない。
const FIXED_LINES: string[] = Array.from({ length: 1000 }, (_, index) => `line ${index + 1}`);

export interface Adapter {
	getLines(startLine: number, endLine: number): readonly string[];
}

export function createAdapter(): Adapter {
	return {
		getLines(startLine: number, endLine: number): readonly string[] {
			return FIXED_LINES.slice(startLine, endLine + 1);
		},
	};
}
