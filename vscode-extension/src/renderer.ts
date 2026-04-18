export interface RendererDecoration {
	lineNumber: number;
	virtualText: string;
}

export function render(lines: readonly string[]): readonly RendererDecoration[] {
	return lines.map((line, index) => ({
		lineNumber: index,
		virtualText: line,
	}));
}
