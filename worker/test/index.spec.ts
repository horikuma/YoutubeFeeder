import {
	env,
	createExecutionContext,
	waitOnExecutionContext,
	SELF,
} from "cloudflare:test";
import { describe, it, expect } from "vitest";
import worker from "../src/index";

// For now, you'll need to do something like this to get a correctly-typed
// `Request` to pass to `worker.fetch()`.
const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

describe("Worker", () => {
	it("stores channel registry payload on PUT /channel-registry", async () => {
		const request = new IncomingRequest("http://example.com/channel-registry", {
			method: "PUT",
			body: JSON.stringify({
				formatVersion: 1,
				syncedAt: "2026-04-17T00:00:00.000Z",
				channels: [{ channelID: "UC123", addedAt: "2026-04-16T00:00:00.000Z" }],
			}),
		});
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);

		expect(response.status).toBe(200);
		expect(await response.json()).toEqual({ ok: true });
		expect(await env.KV.get("channel-registry")).toBe(
			JSON.stringify({
				formatVersion: 1,
				syncedAt: "2026-04-17T00:00:00.000Z",
				channels: [{ channelID: "UC123", addedAt: "2026-04-16T00:00:00.000Z" }],
			})
		);
	});

	it("rejects invalid JSON on PUT /channel-registry", async () => {
		const request = new IncomingRequest("http://example.com/channel-registry", {
			method: "PUT",
			body: "{\"formatVersion\":1",
		});
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);

		expect(response.status).toBe(400);
		expect(await response.json()).toEqual({ error: "invalid JSON" });
		expect(await env.KV.get("channel-registry")).toBeNull();
	});

	it("responds with ok (unit style)", async () => {
		const request = new IncomingRequest("http://example.com");
		// Create an empty context to pass to `worker.fetch()`.
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		// Wait for all `Promise`s passed to `ctx.waitUntil()` to settle before running test assertions
		await waitOnExecutionContext(ctx);
		expect(await response.text()).toMatchInlineSnapshot(`"ok"`);
	});

	it("responds with ok (integration style)", async () => {
		const response = await SELF.fetch("https://example.com");
		expect(await response.text()).toMatchInlineSnapshot(`"ok"`);
	});
});
