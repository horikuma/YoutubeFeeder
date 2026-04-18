export interface ViewportContext {
}

export interface Viewport {
	startLine: number;
	endLine: number;
	version: number;
	context: ViewportContext;
}

export function createViewport(): Viewport {
	return {
		startLine: 0,
		endLine: 999,
		version: 1,
		context: {},
	};
}
