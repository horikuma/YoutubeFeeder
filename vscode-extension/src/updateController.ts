// UpdateController は、Viewport の更新順序を制御して下流へ渡す。
// UpdateController は、ログ読取りや装飾生成を扱わない。
import { Viewport } from './viewport';

export interface UpdateController {
	update(viewport: Viewport): Viewport;
}

export function createUpdateController(): UpdateController {
	return {
		update(viewport: Viewport): Viewport {
			return viewport;
		},
	};
}
