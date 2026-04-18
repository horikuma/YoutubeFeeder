/****
 * Welcome to Cloudflare Workers! This is your first worker.
 *
 * - Run `npm run dev` in your terminal to start a development server
 * - Open a browser tab at http://localhost:8787/ to see your worker in action
 * - Run `npm run deploy` to publish your worker
 *
 * Bind resources to your worker in `wrangler.toml`. After adding bindings, a type definition for the
 * `Env` object can be regenerated with `npm run cf-typegen`.
 *
 * Learn more at https://developers.cloudflare.com/workers/
 */

export default {
	async fetch(request, env, ctx): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === "PUT" && url.pathname === "/channel-registry") {
			let body: string;
			try {
				body = JSON.stringify(await request.json());
			} catch {
				return new Response(JSON.stringify({ error: "invalid JSON" }), {
					status: 400,
					headers: { "content-type": "application/json; charset=utf-8" },
				});
			}

			await env.KV.put("channel-registry", body);
			return new Response(JSON.stringify({ ok: true }), {
				status: 200,
				headers: { "content-type": "application/json; charset=utf-8" },
			});
		}

		if (request.method === "GET" && url.pathname === "/channel-registry") {
			const val = await env.KV.get("channel-registry");
			return new Response(val ?? "null", {
				status: 200,
				headers: { "content-type": "application/json; charset=utf-8" },
			});
		}

		if (url.pathname === "/put") {
			await env.KV.put("key", "value");
			return new Response("stored");
		}

		if (url.pathname === "/get") {
			const val = await env.KV.get("key");
			return new Response(val ?? "null");
		}

		return new Response("ok");
	},
} satisfies ExportedHandler<Env>;
