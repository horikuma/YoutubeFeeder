const FIXED_LINES: string[] = Array.from({ length: 1000 }, (_, index) => `line ${index + 1}`);

export interface Adapter {
	lines: readonly string[];
	getLines(startLine: number, endLine: number): readonly string[];
}

export function createAdapter(): Adapter {
	return {
		lines: FIXED_LINES,
		getLines(startLine: number, endLine: number): readonly string[] {
			return FIXED_LINES.slice(startLine, endLine + 1);
		},
	};
}
