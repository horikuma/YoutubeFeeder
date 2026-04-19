// Diff は、前回結果と今回結果の差分抽出を担当する。
import { RendererDecorations } from './renderer';

export function diff(
	_previous: RendererDecorations | undefined,
	next: RendererDecorations,
): RendererDecorations {
	return next;
}
