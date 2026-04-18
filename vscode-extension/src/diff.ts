import { RendererDecorations } from './renderer';

export function diff(
	_previous: RendererDecorations | undefined,
	next: RendererDecorations,
): RendererDecorations {
	return next;
}
