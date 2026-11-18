// submit_feedback lets an agent report a missing, broken, or confusing tool to the maintainers. The extension
// sends nothing: it returns a prefilled GitHub issue link that the person opens, reviews, and submits.
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

const APP = "Green Room";
const REPO = "coreyhaines31/greenroom";

export const BUG_HINT = `If this looks like a bug in ${APP}, report it with \`submit_feedback\`.`;

// For failures the person can't fix: a crash, a timeout, or output the extension can't read.
export function withBugHint(text: string): string {
  return `${text} ${BUG_HINT}`;
}

// GitHub rejects very long new-issue links, so the description is cut to keep the whole link under this.
const MAX_URL = 7000;

// Filler agents send instead of a real report, compared after lowercasing and dropping all but letters and digits.
const PLACEHOLDERS = new Set([
  "", "na", "none", "nothing", "noop", "null", "undefined", "placeholder", "tbd", "todo", "test", "testing",
  "asdf", "foo", "xxx", "example",
]);

function isPlaceholder(text: string): boolean {
  return PLACEHOLDERS.has(text.toLowerCase().replace(/[^\p{L}\p{N}]/gu, ""));
}

const SECRETS: [RegExp, string][] = [
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(-----END [A-Z ]*PRIVATE KEY-----|$)/g, "[private key]"],
  [/\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})/g, "[token]"],
  [/\bsk-[A-Za-z0-9_-]{16,}/g, "[key]"],
  [/\b[rsp]k_(?:live|test)_[A-Za-z0-9]{10,}/g, "[key]"],
  [/\bxox[abposr]-[A-Za-z0-9-]{10,}/g, "[token]"],
  [/\bAKIA[0-9A-Z]{16}\b/g, "[key]"],
  [/\bAIza[0-9A-Za-z_-]{35}/g, "[key]"],
  [/\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g, "[token]"],
  [/\b(Bearer|Basic|token)\s+[A-Za-z0-9._~+/=-]{16,}/gi, "$1 [redacted]"],
  [
    /\b(api[_-]?key|access[_-]?key|secret|client[_-]?secret|token|password|passwd|pwd|authorization)(["']?\s*[:=]\s*["']?)[^\s"',;]{4,}/gi,
    "$1$2[redacted]",
  ],
  [/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g, "[email]"],
  [/\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b/g, "[hardware address]"],
  [/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, "[ip]"],
  [/\/Users\/[^/\s]+/g, "~"],
];

export function scrub(text: string): string {
  let out = text.replace(/\p{Cs}/gu, "").replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "");
  for (const [pattern, replacement] of SECRETS) out = out.replace(pattern, replacement);
  return out;
}

type Feedback = {
  task: string;
  kind: "missing" | "broken" | "confusing" | "idea";
  impact: "blocked" | "worked_around" | "friction";
  description: string;
  toolName?: string;
};

const IMPACT = { blocked: "blocked", worked_around: "worked around", friction: "friction" } as const;

function issueUrl(title: string, body: string): string {
  const query = `title=${encodeURIComponent(title)}&body=${encodeURIComponent(body)}&labels=agent-feedback`;
  return `https://github.com/${REPO}/issues/new?${query}`;
}

export function feedbackUrl(input: Feedback, version: string): string {
  const task = scrub(input.task);
  const tool = input.toolName ? scrub(input.toolName) : undefined;
  const title = Array.from(`Agent feedback (${input.kind}): ${task}`).slice(0, 120).join("");
  const body = (description: string) =>
    [
      `**Task:** ${task}`,
      `**Kind:** ${input.kind}`,
      `**Impact:** ${IMPACT[input.impact]}`,
      ...(tool ? [`**Tool:** \`${tool}\``] : []),
      "",
      "### What happened",
      description,
      "",
      "---",
      `${APP} Claude Desktop extension ${version}. Drafted by an AI agent with \`submit_feedback\`; ` +
        "review it, and remove anything private, before submitting.",
    ].join("\n");

  let description = Array.from(scrub(input.description));
  let url = issueUrl(title, body(description.join("")));
  while (url.length > MAX_URL && description.length > 0) {
    // Each character can encode to as many as 12 URL characters (a 4-byte UTF-8 character as %XX%XX%XX%XX).
    const cut = Math.max(1, Math.ceil((url.length - MAX_URL) / 12));
    description = description.slice(0, Math.max(0, description.length - cut));
    url = issueUrl(title, body(`${description.join("")}\n\n(cut short to fit in a link)`));
  }
  return url;
}

export function registerFeedbackTool(server: McpServer, version: string): void {
  server.registerTool(
    "submit_feedback",
    {
      title: `Report a problem with ${APP}'s tools`,
      description:
        `Drafts a report to ${APP}'s maintainers (not the person's own files) about a missing tool, a tool that ` +
        "failed or returned something wrong, a confusing tool, or an idea. Use it at most once per task, and only " +
        `when a ${APP} tool was missing, failed, or got in the way; skip it if the task went fine. Never use it ` +
        "to log progress or to test it. Don't include secrets or personal data. Nothing is sent: it returns a " +
        "prefilled GitHub issue link, and nothing reaches the maintainers until the person opens the link, " +
        "reviews it, and submits it.",
      inputSchema: {
        task: z.string().trim().min(1).max(200).describe("A short phrase naming what the person asked you to do."),
        kind: z
          .enum(["missing", "broken", "confusing", "idea"])
          .describe(
            "missing: no tool could do it; broken: a tool failed or returned something wrong; confusing: a tool " +
              "or its description was unclear; idea: a suggestion.",
          ),
        impact: z
          .enum(["blocked", "worked_around", "friction"])
          .describe(
            "blocked: you couldn't finish; worked_around: you finished another way; friction: you finished, " +
              "but it was harder than it should be.",
          ),
        description: z
          .string()
          .trim()
          .min(1)
          .max(4000)
          .describe("What you tried, including the tool calls and any error, and what went wrong."),
        toolName: z.string().trim().max(100).optional().describe(`The ${APP} tool this is about, if any.`),
      },
      annotations: {
        title: `Report a problem with ${APP}'s tools`,
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (input) => {
      if (isPlaceholder(input.task) || isPlaceholder(input.description)) {
        return {
          content: [{
            type: "text" as const,
            text: "task or description is a placeholder. Describe what you tried and what went wrong, or skip " +
              "this tool if there's nothing to report.",
          }],
          isError: true,
        };
      }
      const url = feedbackUrl(input, version);
      return {
        content: [{
          type: "text" as const,
          text: "Nothing has been sent. Give the person this link so they can review the report and submit it " +
            `on GitHub themselves:\n${url}`,
        }],
      };
    },
  );
}
