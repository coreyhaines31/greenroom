// Turns the CLI's JSON into short answers for Claude. Only the listed fields pass through, so nothing the
// CLI might add later reaches the conversation by accident. Device IDs (Core Audio UIDs, camera unique IDs,
// and Bluetooth addresses in history) are dropped: names are what people recognize, and IDs identify hardware.

export const NO_HISTORY = "Nothing yet. Green Room records plug-ins, unplugs, and switches while it's running.";
export const NO_SETUPS = "No setups saved yet. Open Green Room and click Save as my setup.";

const KINDS = new Set(["camera", "microphone", "speaker"]);
const TRANSPORTS = new Set([
  "builtIn", "usb", "bluetooth", "airPlay", "thunderbolt", "display", "continuity", "external", "virtual",
  "aggregate", "other",
]);
const CHANGES = new Set(["connected", "disconnected", "selected"]);
const MAX_TEXT = 300;
const MAX_ITEMS = 100;

type Shaped = { ok: boolean; text: string };
type Item = Record<string, unknown>;

function parse(stdout: string): unknown {
  try {
    return JSON.parse(stdout);
  } catch {
    return undefined;
  }
}

function items(value: unknown): Item[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is Item => Boolean(item) && typeof item === "object").slice(0, MAX_ITEMS);
}

function text(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.slice(0, MAX_TEXT) : undefined;
}

function texts(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map(text).filter((item): item is string => item !== undefined).slice(0, MAX_ITEMS);
}

function oneOf(value: unknown, allowed: Set<string>): string | undefined {
  return typeof value === "string" && allowed.has(value) ? value : undefined;
}

// Seconds between 1970 and 2001, the epoch of Swift's default date encoding.
const SWIFT_EPOCH = 978_307_200;

// "2026-10-29T18:14:09Z" -> "2026-10-29T18:14Z": seconds don't matter here. `status --recording` encodes dates
// with Swift's default strategy (seconds since 2001) instead of ISO 8601, so numbers are converted too.
function minute(value: unknown): string | undefined {
  if (typeof value === "number" && Number.isFinite(value) && value > 0 && value < 4e9) {
    value = new Date((value + SWIFT_EPOCH) * 1000).toISOString();
  }
  if (typeof value !== "string") return undefined;
  const match = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2})(?::\d{2}(?:\.\d+)?)?Z$/.exec(value);
  return match ? `${match[1]}Z` : undefined;
}

// Drops undefined fields so the JSON stays short.
function compact(object: Item): Item {
  return Object.fromEntries(Object.entries(object).filter(([, value]) => value !== undefined));
}

const unreadable = (what: string): Shaped => ({ ok: false, text: `Couldn't read Green Room's ${what}.` });

export function shapeStatus(stdout: string, code: 0 | 2): Shaped {
  const parsed = parse(stdout);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return unreadable("status");
  const report = parsed as Item;

  const inUse = items(report.inUse).map((device) => {
    const live = texts(device.liveIn);
    return compact({
      kind: oneOf(device.kind, KINDS),
      name: text(device.name),
      transport: oneOf(device.transport, TRANSPORTS),
      live_in: live.length ? live : undefined,
    });
  });
  const problems = items(report.problems).map((problem) => {
    const message = text(problem.message);
    const advice = text(problem.advice);
    return compact({
      kind: oneOf(problem.kind, KINDS),
      device: text(problem.device),
      message,
      advice: advice === message ? undefined : advice,
      last_seen: minute(problem.lastSeen),
    });
  });
  const missing = texts(report.missing);
  const flaky = texts(report.flaky);

  const answer: Item = compact({
    problem: code === 2,
    ready: report.ready === true,
    setup: text(report.setup),
    in_use: inUse,
    problems,
    missing: missing.length ? missing : undefined,
    flaky: flaky.length ? flaky : undefined,
  });
  if (report.recording && typeof report.recording === "object") {
    const checks = items((report.recording as Item).items).map((item) =>
      compact({ title: text(item.title), detail: text(item.detail), passed: item.passed === true }),
    );
    answer.recording = { ready: checks.every((check) => check.passed === true), checks };
  }
  return { ok: true, text: JSON.stringify(answer) };
}

export function shapeDevices(stdout: string): Shaped {
  const parsed = parse(stdout);
  if (!Array.isArray(parsed)) return unreadable("device list");

  const connected: Record<string, Item[]> = { camera: [], microphone: [], speaker: [] };
  const notConnected: Item[] = [];
  for (const device of items(parsed)) {
    const kind = oneOf(device.kind, KINDS);
    const name = text(device.name);
    if (!kind || !name) continue;
    const transport = oneOf(device.transport, TRANSPORTS);
    if (device.connected === true) {
      connected[kind].push(compact({ name, transport, in_use: device.inUse === true ? true : undefined }));
    } else {
      notConnected.push(compact({
        kind, name, transport, reason: text(device.reason), advice: text(device.advice),
        last_seen: minute(device.lastSeen),
      }));
    }
  }
  const answer: Item = {
    cameras: connected.camera,
    microphones: connected.microphone,
    speakers: connected.speaker,
  };
  if (notConnected.length) answer.not_connected = notConnected;
  return { ok: true, text: JSON.stringify(answer) };
}

export function shapeHistory(stdout: string, limit: number): Shaped {
  const parsed = parse(stdout);
  if (!Array.isArray(parsed)) return unreadable("history");

  const events = items(parsed)
    .map((event) => {
      const device = event.device && typeof event.device === "object" ? (event.device as Item) : {};
      return compact({
        time: minute(event.time),
        change: oneOf(event.change, CHANGES),
        kind: oneOf(device.kind, KINDS),
        name: text(device.name),
        transport: oneOf(device.transport, TRANSPORTS),
      });
    })
    .filter((event) => event.time && event.change && event.name)
    .slice(0, limit);
  const answer: Item = { events };
  if (events.length === 0) answer.note = NO_HISTORY;
  return { ok: true, text: JSON.stringify(answer) };
}

export function shapeSetups(stdout: string): Shaped {
  const parsed = parse(stdout);
  if (!Array.isArray(parsed)) return unreadable("setups");

  const setups = items(parsed)
    .map((setup) => {
      const devices = setup.devices && typeof setup.devices === "object" ? (setup.devices as Item) : {};
      return compact({
        name: text(setup.name),
        fits: setup.fits === true,
        connected: Number.isInteger(setup.connected) ? setup.connected : undefined,
        camera: text(devices.camera),
        microphone: text(devices.microphone),
        speaker: text(devices.speaker),
      });
    })
    .filter((setup) => setup.name);
  const answer: Item = { setups };
  if (setups.length === 0) answer.note = NO_SETUPS;
  return { ok: true, text: JSON.stringify(answer) };
}
