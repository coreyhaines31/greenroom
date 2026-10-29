import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { runGreenRoom } from "./cli.js";
import { shapeDevices, shapeHistory, shapeSetups, shapeStatus } from "./shape.js";

const VERSION = "0.1.0";

const server = new McpServer(
  { name: "greenroom", version: VERSION },
  {
    instructions:
      "Green Room checks this Mac's camera, microphone, and speakers: which ones are in use, whether they match " +
      "the person's saved setup, and why a device is missing. These tools only read device settings. They never " +
      "turn on the camera or listen to the mic, so they can't tell whether a mic is picking up sound or what the " +
      "camera sees; for that, the person opens Green Room's panel. Times are UTC. For CPU and memory, use Spare; " +
      "for disk space, Disk Forecast; for AI usage limits, Fuel Gauge.",
  },
);

const readOnly = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
} as const;

function reply(result: { ok: boolean; text: string }) {
  return {
    content: [{ type: "text" as const, text: result.text }],
    ...(result.ok ? {} : { isError: true }),
  };
}

server.registerTool(
  "av_status",
  {
    title: "Camera, mic, and speaker check",
    description:
      "Which camera, mic, and speaker are in use, which apps are using them (live_in), and anything to fix: " +
      "the wrong mic or speaker selected, a setup device not connected, the mic muted or at zero volume, or " +
      "AirPods stuck in low-quality call mode. problem is true when something needs fixing; then tell the person " +
      "each problem's message and advice. Use for 'is my mic working?', 'am I ready for my call?', or 'why can't " +
      "they hear me?'. Set recording to true before recording a video or podcast: it adds camera resolution, mic " +
      "sample rate, free disk space, and power, and problem is also true if any of those would spoil a recording. " +
      "Reads settings only; it can't hear the mic or see the camera picture. For disk space in general, use Disk " +
      "Forecast; for CPU and memory, Spare.",
    inputSchema: {
      recording: z.boolean().default(false).describe("Also check camera format, mic quality, disk, and power."),
    },
    annotations: { ...readOnly, title: "Camera, mic, and speaker check" },
  },
  async ({ recording }) => {
    const result = await runGreenRoom(recording ? ["status", "--recording"] : ["status"]);
    return reply(result.ok ? shapeStatus(result.stdout, result.code) : result);
  },
);

server.registerTool(
  "list_devices",
  {
    title: "Connected cameras, mics, and speakers",
    description:
      "Every camera, mic, and speaker connected to this Mac, grouped by kind, with in_use on the selected mic " +
      "and speaker. not_connected lists devices that are usually here or were used on this Mac before but are " +
      "missing now, with why (not on USB at all, or on USB but not working) and what to try. Use for 'what mics " +
      "do I have?', 'is my webcam plugged in?', or 'why isn't my USB mic showing up?'.",
    inputSchema: {},
    annotations: { ...readOnly, title: "Connected cameras, mics, and speakers" },
  },
  async () => {
    const result = await runGreenRoom(["devices"]);
    return reply(result.ok ? shapeDevices(result.stdout) : result);
  },
);

server.registerTool(
  "device_history",
  {
    title: "Device history",
    description:
      "Recent plug-ins, unplugs, and switches of cameras, mics, and speakers, newest first (change is connected, " +
      "disconnected, or selected). Green Room records these while it's running. Use for 'did my mic disconnect " +
      "during the call?', 'when did my AirPods take over?', or 'what changed?'.",
    inputSchema: {
      limit: z.number().int().min(1).max(100).default(20).describe("How many events, 1-100. Default 20."),
    },
    annotations: { ...readOnly, title: "Device history" },
  },
  async ({ limit }) => {
    const result = await runGreenRoom(["history", "--limit", String(limit)]);
    return reply(result.ok ? shapeHistory(result.stdout, limit) : result);
  },
);

server.registerTool(
  "list_setups",
  {
    title: "Saved setups",
    description:
      "The person's saved setups (the camera, mic, and speaker they use in each place, like Desk or Studio), " +
      "how many of each setup's devices are connected, and which one fits what's plugged in now (fits). Use " +
      "for 'which setup am I on?' or 'what's in my Studio setup?'. Switching setups isn't available here: the " +
      "person can pick one in Green Room's menu.",
    inputSchema: {},
    annotations: { ...readOnly, title: "Saved setups" },
  },
  async () => {
    const result = await runGreenRoom(["setups"]);
    return reply(result.ok ? shapeSetups(result.stdout) : result);
  },
);

await server.connect(new StdioServerTransport());
