export interface ViewportContext {
}

export interface Viewport {
	startLine: number;
	endLine: number;
	version: number;
	context: ViewportContext;
}
