import assert from "node:assert/strict";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);
  return worker.fetch(new Request("http://localhost/", { headers: { accept: "text/html" } }), {
    ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
  }, { waitUntil() {}, passThroughOnException() {} });
}

test("server-renders the complete AI Limits launch page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>AI Limits — Your AI usage at a glance<\/title>/i);
  assert.match(html, /Know what you can still ask AI today/);
  assert.match(html, /Credentials never leave your Mac/);
  assert.match(html, /Codex/);
  assert.match(html, /Claude/);
  assert.match(html, /Private iCloud sync/);
  assert.match(html, /Open source from the first commit/);
  assert.match(html, /Join the TestFlight/);
  assert.match(html, /Download for Mac/);
  assert.match(html, /releases\/latest\/download\/AI-Limits-Collector-0\.1\.0\.zip/);
  assert.doesNotMatch(html, /Your site is taking shape|react-loading-skeleton|codex-preview/);
});

test("ships essential metadata and semantic sections", async () => {
  const html = await (await render()).text();
  assert.match(html, /name="description"/);
  assert.match(html, /property="og:title"/);
  assert.match(html, /social-card\.png/);
  assert.match(html, /<nav/);
  assert.match(html, /<main/);
  assert.match(html, /<footer/);
  assert.match(html, /id="privacy"/);
  assert.match(html, /id="availability"/);
});
