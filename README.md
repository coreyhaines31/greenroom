<h1 align="center">Green Room</h1>

<p align="center">Check your camera, mic, and speakers before you go on. A free, source-available menu bar app for macOS.</p>

<p align="center">
  <a href="https://greenroomformac.com">greenroomformac.com</a> ·
  <a href="https://github.com/coreyhaines31/greenroom/releases/latest">Download</a> ·
  <a href="https://github.com/coreyhaines31/greenroom/issues">Report a bug</a>
</p>

---

Two minutes before a call, you want three answers: which camera, which mic, and which speakers your Mac will use, and whether they work. Green Room shows all three in one click, with a live camera preview, a mic level meter, and a left-right speaker test. Save your usual devices as your setup, and it warns you when something changes: AirPods grabbing the sound, a USB mic that isn't plugged in, a capture card that dropped off.

## Install

Requires macOS 14 Sonoma or later.

**Download:** get the DMG from [Releases](https://github.com/coreyhaines31/greenroom/releases/latest), open it, and drag **Green Room** to Applications. It's signed and notarized by Apple, and it updates itself.

**Or with Homebrew:**

```sh
brew install --cask coreyhaines31/tap/greenroom
```

## Using it

1. **A welcome window opens the first time.** It proposes your usual devices from what you've used, so saving your setup is one click, and offers the alerts, Keep my setup, calendar checks, and open at login in one place.
2. **Click the camera icon** in the menu bar, or press **⌃⌥⌘G** from anywhere. The first time, macOS asks for camera and microphone access. Live previews run while the panel is open. Optional microphone startup checks also briefly read audio levels when another app opens a mic. Nothing is saved or sent anywhere.
3. **Pick your devices.** Choosing a mic or speaker makes it the Mac's default, the same as System Settings › Sound. Choosing a camera sets the one macOS suggests to apps; Zoom and Meet keep their own camera setting.
4. **Check them.** Watch the preview, talk and watch the meter move, and click **Test** to hear a tone on the left, then the right.
5. **Click Save as my setup.** From then on the icon turns into a warning when your setup doesn't match, and the panel says what's wrong.

## Setups for each place you work

Save more than one setup, like **Desk**, **Studio**, and **Travel**, from the Setup menu. Green Room checks the one whose devices are plugged in, so docking at your desk switches to Desk on its own. Pick another setup from the menu to apply all of its devices at once.

**Right-click** the menu bar icon (or Control-click) for a quick menu of setups and devices that switches without opening the panel or turning on the camera.

## Which mic hears you

Click **Compare** next to the microphone picker to see a live level for every mic at once. Talk, and the one that's hearing you moves; click it to switch. Bluetooth headsets and iPhone mics say **Switch to test** instead, because just opening their mic drops AirPods to call quality or wakes your phone. The mics are only open while the list is showing.

## Name your devices

In **Settings › Devices**, rename anything from its ⋯ menu ("Lapel mic" instead of "USB Audio Device"), and the name shows everywhere: the panel, alerts, history, setups, and the `greenroom` command. **Hide from Lists** takes devices you never use, like virtual cameras, out of the pickers. A hidden device still shows while it's the one in use.

## Before the call

Turn on **Check before calendar calls** in Settings. Two minutes before an event with a Zoom, Meet, Teams, Webex, or similar link, Green Room checks your setup. If you're ready it says nothing; if not, you get one alert with the fix. It needs calendar access, only reads when events start and whether they have a meeting link, and never changes your calendar.

Click **Hear Yourself** next to the mic meter to record five seconds and hear them played back, so you know how you sound, not just that the mic works. The recording is never saved.

## Hold calls

In **Settings › Hold calls**, click **Install Shortcut…**, add **Green Room Hold Calls** in Shortcuts, then click **Check Setup** and enable **Hold calls and notifications**. Setup verification does not change Focus. The feature is off by default.

Green Room turns on Do Not Disturb when another app opens a mic or camera. **Include calendar calls** also holds notifications during events with video-call links, using the same calendar permission as pre-call checks. All-day, canceled, and declined events are skipped. The two calendar features have independent switches.

Holds last two minutes and renew while activity continues. They expire roughly 75–135 seconds after activity ends, including the 15-second detection interval. Quitting Green Room or disabling Hold calls stops renewal; no global “Focus off” command is sent. An existing Focus is left alone. If you turn Focus off or switch to a different Focus, automation pauses until the call signals have stopped for two minutes. Changing the duration of the same Do Not Disturb mode cannot be distinguished from leaving it alone.

**On your iPhone:** enable **Share Across Devices** in Focus settings. Review Do Not Disturb's allowed people/apps and repeated-call exceptions. Green Room cannot verify these options or guarantee every call is silenced. To stop Continuity calls entirely, turn off **Calls from iPhone** in FaceTime settings where available, or disable this Mac under **Settings › Apps › Phone › Calls on Other Devices** on your iPhone.

Mic detection needs macOS 14.2+. Ignored apps do not trigger mic holds. macOS does not identify camera users, so ignored apps can still trigger camera holds. A camera previewed by Green Room is excluded, including another app sharing that same camera. Recorders and browser mic/camera permissions count as activity even outside meetings. A continuously listening app can keep a hold active; ignore its mic use or turn Hold calls off.

The bundled shortcut is generated by `Scripts/build-hold-shortcut.py`. To rebuild it:

```sh
python3 Scripts/build-hold-shortcut.py
shortcuts sign --mode anyone --input 'build/Hold Calls.unsigned.shortcut' \
  --output 'GreenRoom/Resources/Green Room Hold Calls.shortcut'
```

The shortcut accepts the expected current Focus as `focus:<name>` (`focus:` means no Focus), compares it immediately before enabling a two-minute Do Not Disturb hold, and returns the resulting Focus token. A mismatch returns `blocked`. A `check` input verifies installation without changing Focus. Keep the installed name exactly **Green Room Hold Calls**. When testing a replacement, close its editor before reimporting to avoid duplicate names in Shortcuts.

## Keep my setup

Turn on **Switch back when AirPods take over** in Settings (gear menu › Settings…). When a device that just connected, like AirPods coming out of the case or an iPhone nearby, takes over your mic or sound, Green Room switches back to your setup's device and tells you. If you meant it, click **Use AirPods** in the alert and Green Room leaves them alone until they disconnect. Anything you pick yourself is never switched back.

## Before you dictate

Enable **Settings › Microphone check › Warn when an app starts with a silent mic**. Green Room checks the microphone an app actually opens, including dictation apps such as Monologue, Codex, and Claude. It samples audio levels for up to four seconds (ten for Bluetooth), stopping early if sound arrives. A camera-connected mic can still appear connected when the camera is off; this checks for audio, not just a connection.

If no sound arrives, a small warning appears without taking keyboard focus, even during Do Not Disturb. It suggests checking the camera's power, mute switch, and gain, and offers your Mac's built-in microphone as the default when available. Restart dictation after switching; apps with their own mic setting may need that changed too. If Green Room cannot read the device, it reports that instead of declaring it ready.

This is an opt-in startup check, not continuous monitoring. It requires macOS 14.2+ and microphone permission. A quiet pause can trigger a warning. An app that keeps its mic open gets one check until it releases it; restarting dictation inside such an app may not trigger another check. Ignored apps are skipped. Sound detection cannot verify transcription, the app's selected channel, or an app's internal mute. No audio is saved or sent anywhere.

## Before you record

When a recording app like Loom, OBS, Screen Studio, QuickTime, or Riverside turns on your mic, Green Room runs this check on its own and alerts you only if something would spoil the take.

Open **Ready to record?** at the bottom of the panel, or run `greenroom status --recording`, for the things that ruin a take but don't matter on a call: the camera's resolution and frame rate (and whether an app picked a smaller size or the camera can't do better), the mic's quality, free disk space, and whether you're on battery or in Low Power Mode.

Under the camera preview, Green Room also tells you about light and framing in one line: a covered lens, a dark room, a backlit face, or being off-center, too close, or too far. It looks at about one frame a second on your Mac and never keeps any.

## During a call

Your Mac's default devices and what a call is really using can differ: Zoom and Meet keep their own device choices. Green Room shows the truth:

- **Live now:** a green dot under each device an app has open, with the app's name ("Live in Google Chrome"). On macOS 14.2 and later it names the app; cameras just say another app is using them.
- **Wrong device in a call:** "zoom.us is using MacBook Pro Microphone, not Shure MV7", with a button to switch your Mac's default and a tip to pick the device in the app if it keeps its own setting.
- **Headset call mode:** when a Bluetooth headset's mic turns on, it drops to phone-call sound both ways. Green Room explains it and offers a better mic, like your Mac's own, with one click.

Every problem has a button that fixes it, in the panel and right in the notification. If an app always listens (a recorder, for example), click **Ignore** on its warning; undo it in Settings (gear menu › Settings…).

The first time you open Green Room, it proposes your setup from the devices you've used most, so saving it is one click.

## When a device is missing

Green Room keeps a history of every camera, mic, and speaker it sees. A device that's been connected on most recent days counts as usual, and when one goes missing the panel tells you why:

| You see | It means | Try |
| --- | --- | --- |
| Not plugged in | Your Mac doesn't see it on USB at all | The cable, the hub, or another port |
| Plugged in, but not working | It's on USB, but not working as a camera or mic | Unplug it and plug it back in |
| Not connected (Bluetooth) | It's off or not paired right now | Turn it on, or connect it in Bluetooth settings |

It also uses macOS's own memory of USB audio devices, so a mic you've used before shows up from the first day, before Green Room has any history of its own.

Under the mic meter you'll see a warning if macOS has the mic muted, its input volume is at zero, or no sound has come in for five seconds (usually the mic's own mute button or gain knob).

**Alerts:** a notification when your setup stops matching or a usual device disconnects. Turn them off in Settings (gear menu › Settings…).

**Keeps disconnecting:** a device that drops five or more times in a week gets a note with what to try, like another cable or port.

**History:** every device, connected or not, and a timeline of plug-ins, unplugs, and switches.

## Command line

The `greenroom` command reads your devices from Terminal, so you, a script, or an AI agent can check them without clicking anything.

```sh
greenroom status           # the camera, mic, and speaker in use, and whether your setup matches
greenroom devices          # everything connected, and usual devices that are missing
greenroom history          # recent plug-ins, unplugs, and switches
greenroom setups           # your setups, and which one fits what's plugged in
greenroom use Studio       # switch the mic and speaker to a setup
greenroom status --recording   # adds camera format, mic quality, disk space, and power
```

Add `--json` to any of them. `status` exits with 2 when something doesn't match your setup or a usual device is missing. Homebrew links the command for you; from the DMG, link it once:

```sh
sudo mkdir -p /usr/local/bin
sudo ln -sf "/Applications/Green Room.app/Contents/MacOS/greenroom" /usr/local/bin/greenroom
```

**Shortcuts and Siri:** Green Room adds **Check My Setup** (returns true or false, and says what to fix) and **Use Setup** to the Shortcuts app, so you can run them from Siri, a Focus, or an automation.

**For AI agents**, add a line like this to your `CLAUDE.md` or `AGENTS.md`:

```text
Before I record or join a call, or when I say my mic or camera isn't working, run `greenroom status --json` and tell me anything that doesn't match my setup, and why.
```

### Use Green Room from Claude Desktop

Download [`greenroom.mcpb`](https://github.com/coreyhaines31/greenroom/releases/latest/download/greenroom.mcpb) and double-click it (or drag it onto Claude Desktop) to install the Green Room extension. Then ask Claude things like *is my mic working?*, *am I ready for my call?*, *what cameras are plugged in?*, or *did my mic disconnect?*

The extension runs the `greenroom` tool from your installed Green Room app, so install Green Room first. It only reads (`status`, `devices`, `history`, and `setups`); it can't switch devices, so `use` isn't available. It never turns on your camera or listens to your mic, so macOS doesn't ask Claude for camera or microphone access. Device IDs (including Bluetooth addresses) are left out of its answers.

## Privacy

- **No analytics, no account, no network.** Green Room never connects to the internet except to check for updates.
- **Camera and mic previews** run while the panel or Record Preview is open. Opt-in microphone startup checks briefly read audio levels when another app opens a mic. Hear Yourself holds its short playback recording only in memory; nothing is saved.
- **History** stays on your Mac, in `~/Library/Application Support/Green Room/`.

## Build it yourself

You need Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen). No Apple Developer account required.

```sh
git clone https://github.com/coreyhaines31/greenroom.git
cd greenroom
brew install xcodegen swiftlint
Scripts/run-local.sh        # builds, signs to run locally, and opens the app
cd Packages/GreenRoomCore && swift test
```

`swift run greenroom-dev` in the package prints your devices and why any are missing, without the app.

The Claude Desktop extension is in [`mcpb/`](mcpb/) (Node 20+): `cd mcpb && npm ci && npm run lint && npm test` checks it (the test calls every tool on your Mac, then checks each tool's exact arguments against a fake CLI), and `npm run pack` builds `mcpb/dist/greenroom.mcpb`. `Scripts/release.sh` attaches it to every release. To attach it to an existing release without cutting a new one:

```sh
cd mcpb && npm ci && npm run pack
gh release upload v<version> dist/greenroom.mcpb --repo coreyhaines31/greenroom --clobber
```

Bump `version` in `mcpb/manifest.json`, `mcpb/package.json`, and `mcpb/src/index.ts` when the extension changes.

## License

Green Room is source available under the [Functional Source License, Version 1.1, MIT Future License](LICENSE) (FSL-1.1-MIT): use it, change it, and run it for anything except a competing product. Each version becomes MIT two years after it's released. The name and icon are covered by the [trademark policy](TRADEMARK.md).
