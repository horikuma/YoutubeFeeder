// Diff は、前回結果と今回結果の差分抽出を担当する。
// Diff は、Viewport 更新や Decoration 反映を扱わない。
import { RendererDecorations } from './renderer';

export function diff(
	_previous: RendererDecorations | undefined,
	next: RendererDecorations,
): RendererDecorations {
	return next;
}
