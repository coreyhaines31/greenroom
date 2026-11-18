// Checks submit_feedback and the bug hint without touching this Mac's devices: submit_feedback never runs
// the CLI, and the hint is checked against a stand-in CLI that crashes.
// Run: npm run test:feedback. SERVER=<path> runs an unpacked .mcpb instead of server/index.mjs.
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const APP = "Green Room";
const REPO = "coreyhaines31/greenroom";
const CLI_ENV = "GREENROOM_CLI";
const CLI_NAME = "greenroom";
const CLI_TOOL = ["list_setups", {}];

const server = process.env.SERVER ?? new URL("../server/index.mjs", import.meta.url).pathname;
const version = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")).version;
const hint = `If this looks like a bug in ${APP}, report it with \`submit_feedback\`.`;
const failures = [];
const check = (label, passed) => {
  console.log(`${passed ? "ok" : "FAIL"}  ${label}`);
  if (!passed) failures.push(label);
};

async function connect(env) {
  const transport = new StdioClientTransport({ command: process.execPath, args: [server], env: { ...process.env, ...env } });
  const client = new Client({ name: `${CLI_NAME}-feedback-test`, version: "0.0.0" });
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

function issue(text) {
  const match = /https:\/\/github\.com\/\S+/.exec(text);
  if (!match) return null;
  const url = new URL(match[0]);
  return {
    href: match[0],
    path: url.pathname,
    title: url.searchParams.get("title") ?? "",
    body: url.searchParams.get("body") ?? "",
    labels: url.searchParams.get("labels"),
  };
}

const scratch = mkdtempSync(join(tmpdir(), `${CLI_NAME}-feedback-`));
const crashingCli = join(scratch, CLI_NAME);
writeFileSync(crashingCli, "#!/bin/sh\nkill -SEGV $$\n");
chmodSync(crashingCli, 0o755);

const client = await connect({ [CLI_ENV]: crashingCli });
const { tools } = await client.listTools();
const tool = tools.find((t) => t.name === "submit_feedback");
check("submit_feedback is listed", Boolean(tool));
check("submit_feedback is read-only", tool?.annotations?.readOnlyHint === true && tool?.annotations?.destructiveHint === false);
for (const phrase of ["at most once per task", "never use it to log progress or to test it", "secrets or personal data", "Nothing is sent"]) {
  check(`description says "${phrase}"`, tool?.description.toLowerCase().includes(phrase.toLowerCase()));
}

const good = {
  task: "Check the mic before a call",
  kind: "broken",
  impact: "worked_around",
  description:
    "Called list_setups and got an error. My token is ghp_abcdefghijklmnopqrstuvwxyz0123456789, key " +
    "sk-ant-api03-abcdefghijklmnop, email jane.doe@example.com, path /Users/jane/Desktop, api_key=hunter22, " +
    "router 192.168.1.1, device 74:3F:8E:B6:C0:6B.",
  toolName: "list_setups",
};
const sent = await call(client, "submit_feedback", good);
const draft = issue(sent.text);
check("valid feedback works", !sent.isError && draft !== null);
check("tells the agent to give the link to the person", /give the person this link/i.test(sent.text) && /nothing has been sent/i.test(sent.text));
check("link opens a new issue in the repo", draft?.path === `/${REPO}/issues/new`);
check("link adds the agent-feedback label", draft?.labels === "agent-feedback");
check("link is under 7000 characters", draft !== null && draft.href.length <= 7000);
check("title names the kind and task", draft?.title === "Agent feedback (broken): Check the mic before a call");
check("body has the impact, tool, and version", Boolean(
  draft?.body.includes("**Impact:** worked around") && draft.body.includes("`list_setups`") && draft.body.includes(`extension ${version}`),
));
for (const secret of ["ghp_abc", "sk-ant", "jane.doe@", "/Users/jane", "hunter22", "192.168.1.1", "74:3F:8E"]) {
  check(`scrubs ${secret}`, draft !== null && !draft.body.includes(secret));
}
check("keeps the rest of the description", Boolean(draft?.body.includes("Called list_setups and got an error.")));

const long = await call(client, "submit_feedback", { ...good, description: "🎙️ mic é ".repeat(400).slice(0, 4000) });
const longDraft = issue(long.text);
check("long description still fits in 7000 characters", !long.isError && longDraft !== null && longDraft.href.length <= 7000);
check("long description says it was cut", Boolean(longDraft?.body.includes("cut short to fit in a link")));

const rejected = [
  ["placeholder description", { ...good, description: "test" }],
  ["placeholder description n/a", { ...good, description: " N/A " }],
  ["placeholder task", { ...good, task: "TODO" }],
  ["empty description", { ...good, description: "   " }],
  ["unknown kind", { ...good, kind: "bug" }],
  ["unknown impact", { ...good, impact: "annoying" }],
  ["task over 200 characters", { ...good, task: "x".repeat(201) }],
  ["description over 4000 characters", { ...good, description: "x".repeat(4001) }],
  ["missing description", { task: good.task, kind: good.kind, impact: good.impact }],
];
for (const [label, args] of rejected) {
  const result = await call(client, "submit_feedback", args);
  check(`rejects ${label}`, result.isError && !result.text.includes("github.com"));
}

await client.close();

rmSync(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`\nFAILED: ${failures.join("; ")}`);
  process.exit(1);
}
console.log("\nsubmit_feedback and the bug hint behaved as expected.");
