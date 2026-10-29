// Starts the built server over stdio, calls every tool against this Mac, and fails
// if a call that should work errors or a call that should fail doesn't.
// Then checks, against a fake CLI, the exact argv each tool sends and how each CLI outcome comes back.
// Run: npm test. SERVER=<path> runs an unpacked .mcpb instead of server/index.mjs.
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const ok = true;
const fails = false;
// [tool, arguments, should work, top-level key the answer must have]
const calls = [
  ["av_status", {}, ok, "in_use"],
  ["av_status", { recording: true }, ok, "recording"],
  ["list_devices", {}, ok, "microphones"],
  ["device_history", {}, ok, "events"],
  ["device_history", { limit: 3 }, ok, "events"],
  ["list_setups", {}, ok, "setups"],
  ["device_history", { limit: 0 }, fails],
  ["device_history", { limit: 101 }, fails],
  ["device_history", { limit: 2.5 }, fails],
  ["device_history", { limit: "5; rm -rf ~" }, fails],
  ["av_status", { recording: "yes" }, fails],
  ["use", { name: "Studio" }, fails],
  ["use_setup", {}, fails],
];

// [fake mode, tool, arguments, should work, argv the CLI must get, exact answer]
const fakeCalls = [
  [
    "ok", "av_status", {}, ok, "status --json",
    {
      problem: false, ready: true, setup: "Desk",
      in_use: [
        { kind: "microphone", name: "Shure MV7", transport: "usb", live_in: ["Zoom"] },
        { kind: "speaker", name: "MacBook Pro Speakers", transport: "builtIn" },
      ],
      problems: [],
    },
  ],
  [
    "problem", "av_status", {}, ok, "status --json",
    {
      problem: true, ready: false, setup: "Desk",
      in_use: [{ kind: "microphone", name: "AirPods Pro", transport: "bluetooth" }],
      problems: [
        {
          kind: "microphone", device: "Shure MV7", message: "AirPods Pro is the mic, not Shure MV7",
          advice: "Switch back in Green Room, or System Settings › Sound.", last_seen: "2026-10-29T17:40Z",
        },
        { kind: "microphone", device: "AirPods Pro", message: "Your mic is muted." },
      ],
      missing: ["Brio: not plugged in. Check the cable."],
      flaky: ["Cam Link 4K disconnected 4 times this week. Try another cable."],
    },
  ],
  [
    "recording", "av_status", { recording: true }, ok, "status --recording --json",
    {
      problem: true, ready: false, in_use: [],
      // The CLI's --recording output encodes dates as seconds since 2001.
      problems: [{ kind: "camera", device: "Brio", message: "Brio is not connected", advice: "Check the cable.", last_seen: "2026-10-29T17:40Z" }],
      recording: {
        ready: false,
        checks: [
          { title: "Camera", detail: "Cam Link 4K · up to 2160p", passed: true },
          { title: "Disk space", detail: "4.2 GB free", passed: false },
        ],
      },
    },
  ],
  [
    "ok", "list_devices", {}, ok, "devices --json",
    {
      cameras: [{ name: "Brio", transport: "external" }],
      microphones: [{ name: "Shure MV7", transport: "usb", in_use: true }],
      speakers: [{ name: "MacBook Pro Speakers", transport: "builtIn", in_use: true }],
      not_connected: [{
        kind: "microphone", name: "Opal C1", transport: "usb", reason: "Used on this Mac before, not plugged in",
        advice: "Check the cable.", last_seen: "2026-10-20T09:00Z",
      }],
    },
  ],
  ["empty", "list_devices", {}, ok, "devices --json", { cameras: [], microphones: [], speakers: [] }],
  [
    "ok", "device_history", {}, ok, "history --limit 20 --json",
    {
      events: [
        { time: "2026-10-29T18:14Z", change: "connected", kind: "speaker", name: "AirPods Pro", transport: "bluetooth" },
        { time: "2026-10-29T18:00Z", change: "selected", kind: "microphone", name: "Shure MV7", transport: "usb" },
      ],
    },
  ],
  [
    "empty", "device_history", { limit: 100 }, ok, "history --limit 100 --json",
    { events: [], note: "Nothing yet. Green Room records plug-ins, unplugs, and switches while it's running." },
  ],
  [
    "ok", "list_setups", {}, ok, "setups --json",
    {
      setups: [
        { name: "Desk", fits: true, connected: 2, camera: "Brio", microphone: "Shure MV7", speaker: "MacBook Pro Speakers" },
        { name: "Studio", fits: false, connected: 0, microphone: "Opal C1" },
      ],
    },
  ],
  [
    "empty", "list_setups", {}, ok, "setups --json",
    { setups: [], note: "No setups saved yet. Open Green Room and click Save as my setup." },
  ],
  ["garbage", "av_status", {}, fails, "status --json", "Couldn't read Green Room's status."],
  ["garbage", "list_devices", {}, fails, "devices --json", "Couldn't read Green Room's device list."],
  ["garbage", "device_history", {}, fails, "history --limit 20 --json", "Couldn't read Green Room's history."],
  ["garbage", "list_setups", {}, fails, "setups --json", "Couldn't read Green Room's setups."],
  ["stderr", "av_status", {}, fails, "status --json", "Unknown command: nope"],
  ["stderr", "device_history", { limit: 7 }, fails, "history --limit 7 --json", "Unknown command: nope"],
  ["crash", "list_setups", {}, fails, "setups --json", "Green Room's command line tool stopped unexpectedly (SIGSEGV)."],
];
const expectedTools = ["av_status", "device_history", "list_devices", "list_setups"];
// Never sent to Claude, whatever the CLI prints.
const forbidden = ["SERIAL123", "74-3F-8E", "0x1234", "uniqueID", "\"id\""];
const server = process.env.SERVER ?? new URL("../server/index.mjs", import.meta.url).pathname;
const fakeCli = new URL("./fake/greenroom", import.meta.url).pathname;
const max = Number(process.env.SMOKE_CHARS ?? 600);
const failures = [];

async function connect(env) {
  const transport = new StdioClientTransport({ command: process.execPath, args: [server], env: { ...process.env, ...env } });
  const client = new Client({ name: "greenroom-smoke", version: "0.0.0" });
  await client.connect(transport);
  return client;
}

async function call(client, name, args) {
  let result;
  try {
    result = await client.callTool({ name, arguments: args });
  } catch (error) {
    result = { isError: true, content: [{ type: "text", text: `protocol error: ${error.message}` }] };
  }
  return { isError: Boolean(result.isError), text: result.content.map((c) => c.text).join("\n") };
}

function show(label, { isError, text }) {
  const shown = text.length > max ? `${text.slice(0, max)}\n… (${text.length} chars)` : text;
  console.log(`\n### ${label}${isError ? " [isError]" : ""}\n${shown}`);
}

const client = await connect({ GREENROOM_CLI: process.env.GREENROOM_CLI ?? "" });
const { tools } = await client.listTools();
console.log(`tools: ${tools.map((t) => t.name).join(", ")}`);
if (tools.map((t) => t.name).sort().join() !== expectedTools.join()) {
  throw new Error(`expected exactly these tools: ${expectedTools.join(", ")}`);
}
for (const tool of tools) {
  if (!tool.annotations?.readOnlyHint || tool.annotations?.destructiveHint !== false) {
    throw new Error(`${tool.name} is not annotated read-only`);
  }
}

for (const [name, args, shouldWork, key] of calls) {
  const label = `${name} ${JSON.stringify(args)}`;
  const result = await call(client, name, args);
  show(label, result);
  if (result.isError === shouldWork) failures.push(label);
  else if (shouldWork) {
    let parsed;
    try {
      parsed = JSON.parse(result.text);
    } catch {
      parsed = null;
    }
    if (!parsed?.[key]) failures.push(`${label} (no "${key}" in the output)`);
    if (name === "device_history" && parsed?.events?.length > (args.limit ?? 20)) failures.push(`${label} (over limit)`);
  }
}
await client.close();

const scratch = mkdtempSync(join(tmpdir(), "greenroom-smoke-"));
const argvLog = join(scratch, "argv");
for (const [mode, name, args, shouldWork, argv, expected] of fakeCalls) {
  const label = `fake CLI (${mode}) ${name} ${JSON.stringify(args)}`;
  rmSync(argvLog, { force: true });
  const fake = await connect({ GREENROOM_CLI: fakeCli, FAKE_MODE: mode, FAKE_ARGV_LOG: argvLog });
  const result = await call(fake, name, args);
  await fake.close();
  show(label, result);
  const sent = readFileSync(argvLog, "utf8");
  if (sent !== argv) failures.push(`${label} (sent "${sent}", expected "${argv}")`);
  if (result.isError === shouldWork) failures.push(label);
  else if (typeof expected === "function") {
    if (!expected(result.text)) failures.push(label);
  } else if (result.text !== (shouldWork ? JSON.stringify(expected) : expected)) failures.push(label);
  for (const secret of forbidden) {
    if (result.text.includes(secret)) failures.push(`${label} (leaked ${secret})`);
  }
}

// An override that isn't named greenroom is ignored, so the server falls back to the installed app.
rmSync(argvLog, { force: true });
const renamed = await connect({ GREENROOM_CLI: "/bin/echo", FAKE_ARGV_LOG: argvLog });
const fallback = await call(renamed, "list_setups", {});
await renamed.close();
show("override not named greenroom", fallback);
// /bin/echo would print "setups --json", which reads as unreadable setups.
if (fallback.text === "Couldn't read Green Room's setups.") failures.push("override not named greenroom ran");

rmSync(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`\nFAILED: ${failures.join("; ")}`);
  process.exit(1);
}
console.log(`\nAll ${calls.length + fakeCalls.length + 1} calls behaved as expected.`);
