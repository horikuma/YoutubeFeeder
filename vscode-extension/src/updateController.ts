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
