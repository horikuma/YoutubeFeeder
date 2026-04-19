// Renderer は、入力行を VS Code の仮想装飾へ変換する。
// Renderer は、ファイル I/O や差分比較を扱わない。
export interface RendererDecoration {
	lineNumber: number;
	virtualText: string;
}

export type RendererDecorations = readonly RendererDecoration[];

export function render(lines: readonly string[]): RendererDecorations {
	return lines.map((line, index) => ({
		lineNumber: index,
		virtualText: line,
	}));
}
