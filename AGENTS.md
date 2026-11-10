# Green Room: notes for coding agents

Green Room is a macOS menu bar app (Swift 6) that checks the camera, mic, and speakers. It ships with a `greenroom` CLI and a Claude Desktop extension. README.md has the user-facing details.

## Layout

- `GreenRoom/`: the app target. It has no tests.
- `GreenRoomCLI/`: the `greenroom` command line tool.
- `Packages/GreenRoomCore/`: shared logic (readiness, status report, history). Put testable logic here and add Swift Testing tests in `Tests/GreenRoomCoreTests`.
- `mcpb/`: the Claude Desktop extension (TypeScript, Node 20+). It only runs the read-only CLI subcommands.
- `project.yml`: XcodeGen spec. `GreenRoom.xcodeproj` is generated and git-ignored, so edit `project.yml` and run `xcodegen generate`.
- `site/`: the marketing site. Leave it alone unless the task is about the site.

## Build, test, lint

xcodebuild and SwiftLint need the full Xcode. If `xcode-select -p` points at the Command Line Tools, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```sh
cd Packages/GreenRoomCore && swift test
swiftlint --strict          # from the repo root; config in .swiftlint.yml
xcodegen generate -q && xcodebuild -project GreenRoom.xcodeproj -scheme GreenRoom -configuration Debug \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build -quiet
Scripts/run-local.sh        # builds, signs ad-hoc, and opens the app
cd mcpb && npm ci && npm run lint
```

`npm test` in `mcpb/` calls every tool against the real Mac's devices, then against a fake CLI. Run it only when the owner says it's OK.

## Rules

- When the extension changes, bump `version` in all three places: `mcpb/manifest.json`, `mcpb/package.json`, and `VERSION` in `mcpb/src/index.ts`.
- `greenroom status` exits 0 when ready and 2 when something needs fixing (see README, Command line). Scripts and agents rely on this and on the `--json` shape, so don't change either without the owner.
- The extension must stay read-only: `use` is kept out of the allowlist in `mcpb/src/cli.ts` on purpose.
- Keep the privacy promises in README.md (Privacy): no analytics or account in the app, no network except update checks, Hear Yourself audio kept only in memory, and history kept on the Mac. The extension leaves device IDs out of its answers.
- Never run `Scripts/release.sh`, sign, notarize, tag, publish, or touch the Sparkle appcast without the owner. Sparkle pushes each release to every install.
- Branches: work on `cf/feature/<issue>-<name>` or `cf/fix/<issue>-<name>` from `cf/development`, and open PRs into `cf/development`. Don't commit to `main`.
