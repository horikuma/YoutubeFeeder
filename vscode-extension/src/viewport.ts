export interface ViewportContext {
}

export interface Viewport {
	startLine: number;
	endLine: number;
	version: number;
	context: ViewportContext;
}

export const VIEWPORT_VERSION = 1;
export const EMPTY_VIEWPORT_CONTEXT: ViewportContext = {};

export function createViewport(): Viewport {
	return {
		startLine: 0,
		endLine: 999,
		version: VIEWPORT_VERSION,
		context: EMPTY_VIEWPORT_CONTEXT,
	};
}
