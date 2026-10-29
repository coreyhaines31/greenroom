import { execFile } from "node:child_process";
import { accessSync, constants } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";

export const INSTALL_MESSAGE =
  "Green Room isn't installed on this Mac, so there's nothing to check yet. " +
  "Install the free Green Room app from https://greenroomformac.com (or `brew install --cask coreyhaines31/tap/greenroom`), " +
  "then try again.";

const BUNDLE_ID = "com.greenroomformac.GreenRoom";
const APP_BINARY = "Contents/MacOS/greenroom";
// The CLI reads Core Audio and the camera list without opening either, so it answers in about a second.
const TIMEOUT_MS = 30_000;

// Only these subcommands can ever be spawned. `use NAME` switches the Mac's mic and speaker, so it stays out.
const ALLOWED_COMMANDS = new Set(["status", "devices", "history", "setups"]);

// The CLI exits 0 on success, 2 when `status` finds something to fix (or, with --recording, something that
// would spoil a recording), and 1 on an unknown command, with the message on stderr. Exit 2 still prints the report.
export type RunResult = { ok: true; code: 0 | 2; stdout: string } | { ok: false; text: string };

function isExecutable(path: string): boolean {
  try {
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function spotlightAppPaths(): Promise<string[]> {
  return new Promise((resolve) => {
    try {
      execFile(
        "/usr/bin/mdfind",
        [`kMDItemCFBundleIdentifier == '${BUNDLE_ID}'`],
        { timeout: 5_000 },
        (error, stdout) => {
          if (error) return resolve([]);
          const apps = stdout.split("\n").map((line) => line.trim()).filter(Boolean);
          resolve(apps.filter((app) => !app.includes("/.Trash/")));
        },
      );
    } catch {
      resolve([]);
    }
  });
}

export async function locateCli(): Promise<string | null> {
  // The override must still be a file named greenroom, so it can't point the extension at another program.
  const fromEnv = process.env.GREENROOM_CLI?.trim();
  if (fromEnv && basename(fromEnv) === "greenroom" && isExecutable(fromEnv)) return fromEnv;

  const candidates = [
    join("/Applications/Green Room.app", APP_BINARY),
    join(homedir(), "Applications/Green Room.app", APP_BINARY),
    "/opt/homebrew/bin/greenroom",
    "/usr/local/bin/greenroom",
  ];
  for (const path of candidates) {
    if (isExecutable(path)) return path;
  }

  for (const app of await spotlightAppPaths()) {
    const path = join(app, APP_BINARY);
    if (isExecutable(path)) return path;
  }
  return null;
}

export async function runGreenRoom(args: string[]): Promise<RunResult> {
  if (!ALLOWED_COMMANDS.has(args[0])) {
    return { ok: false, text: `Not allowed: ${args[0]}` };
  }
  if (process.platform !== "darwin") {
    return { ok: false, text: "Green Room only runs on macOS." };
  }
  const cli = await locateCli();
  if (!cli) return { ok: false, text: INSTALL_MESSAGE };

  return new Promise((resolve) => {
    try {
      execFile(
        cli,
        [...args, "--json"],
        { timeout: TIMEOUT_MS, maxBuffer: 20 * 1024 * 1024 },
        (error, stdout, stderr) => {
          const code = error ? (typeof error.code === "number" ? error.code : null) : 0;
          if (code === 0 || code === 2) return resolve({ ok: true, code, stdout });

          const message = stderr.trim().split("\n")[0];
          if (message) return resolve({ ok: false, text: message.slice(0, 300) });
          if (error?.signal && !error.killed) {
            return resolve({ ok: false, text: `Green Room's command line tool stopped unexpectedly (${error.signal}).` });
          }
          if (error?.killed) {
            return resolve({ ok: false, text: `Green Room didn't answer within ${TIMEOUT_MS / 1000} seconds.` });
          }
          resolve({ ok: false, text: `Green Room's command line tool failed: ${error?.message ?? "unknown error"}` });
        },
      );
    } catch (error) {
      resolve({ ok: false, text: `Couldn't start Green Room's command line tool at ${cli}: ${(error as Error).message}` });
    }
  });
}
