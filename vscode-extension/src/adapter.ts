const FIXED_LINES: string[] = Array.from({ length: 1000 }, (_, index) => `line ${index + 1}`);

export interface Adapter {
	lines: readonly string[];
}

export function createAdapter(): Adapter {
	return {
		lines: FIXED_LINES,
	};
}
