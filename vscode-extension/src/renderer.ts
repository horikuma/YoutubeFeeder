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
