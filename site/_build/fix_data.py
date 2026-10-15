"""Data for the /fix pages: one entry per app, one per app and device.

Every settings path here was checked against the app maker's own help pages in October 2026
(support.zoom.com, support.microsoft.com, support.google.com, support.discord.com,
support.apple.com, slack.com/help, help.webex.com, obsproject.com). Keep copy free of em and
en dashes.
"""

# proc: the name Green Room shows for the app's process.
# perm: how the app appears in System Settings › Privacy & Security, "browser" for web apps,
#   None for FaceTime (Apple's own app, covered by Screen Time instead).
# shared_cam: the maker's help says to close other apps that use the camera.
APPS = {
    "zoom": {"name": "Zoom", "proc": "zoom.us", "perm": "zoom.us", "shared_cam": True},
    "teams": {"name": "Microsoft Teams", "short": "Teams", "proc": "Microsoft Teams", "perm": "Microsoft Teams",
              "perm_note": "Microsoft's help names it Microsoft Teams (work or school).", "shared_cam": True},
    "google-meet": {"name": "Google Meet", "short": "Meet", "proc": "Google Chrome", "perm": "browser", "shared_cam": True},
    "discord": {"name": "Discord", "proc": "Discord", "perm": "Discord"},
    "facetime": {"name": "FaceTime", "proc": "FaceTime", "perm": None},
    "slack": {"name": "Slack", "proc": "Slack", "perm": "Slack"},
    "webex": {"name": "Webex", "proc": "Webex", "perm": "Webex", "shared_cam": True},
    "obs": {"name": "OBS Studio", "short": "OBS", "proc": "OBS", "perm": "OBS"},
}

# Combinations left out on purpose (reported, and listed on the hub for nobody):
#   slack camera: huddle video uses the same Preferences › Audio & video picker as the mic page,
#     and the search shows no demand for it.
#   obs sound: OBS doesn't play a call through your speakers; "OBS audio" problems are about
#     capturing desktop audio, a different job from the speaker checks these pages cover.

PAGES = [
    # ---------------------------------------------------------------- Zoom
    {
        "slug": "zoom-camera-not-working", "app": "zoom", "device": "camera",
        "title": "Zoom Camera Not Working on Mac? Fix It in Order",
        "h1": "Zoom camera not working?", "em": "Fix it on your Mac.",
        "desc": "Zoom showing a black box or no camera on your Mac? Pick the camera in Video & effects, allow zoom.us in Privacy & Security, and check what else has it open.",
        "lede": "Most of the time Zoom is pointed at the wrong camera, or macOS hasn't given zoom.us permission. Start at the top.",
        "quick": "Open the <a href=\"/webcam-test\">free webcam test</a>. If you see yourself there, the camera works and the fix is inside Zoom (steps 1 to 3). If it stays black there too, jump to the Mac checks.",
        "steps": [
            ("Pick the camera in Zoom's settings.", "Click your profile picture, then Settings › Video & effects (older versions say Video). The preview shows the camera Zoom is using. If it's black, choose another one from the Camera menu. A built-in camera is usually called FaceTime HD Camera or MacBook Pro Camera."),
            ("Switch cameras during a meeting.", "Click the arrow next to the video button in the meeting controls and pick a camera, or choose Video settings for the full list."),
            ("Start your video.", "If the button still says Start Video, Zoom joined with your camera off. Click it. Zoom can also be set to turn your video off every time you join, so check that setting in Video & effects too."),
            ("Skip virtual cameras.", "Apps like OBS add a virtual camera that shows up in Zoom's list. If you picked one and its app isn't running, you get a black or frozen picture. Choose your real camera instead."),
        ],
        "extra": [
            ("\"Zoom is unable to detect a camera\"", "This message means Zoom sees no camera at all. On a Mac that's almost always the zoom.us permission below, a cable, or a hub. Zoom's own help also says to close other apps that might be using the camera, like Photo Booth or FaceTime."),
            ("Allowed it, still black?", "Zoom says macOS asks you to restart Zoom after you turn on a permission. Quit Zoom completely with Command-Q, not just the meeting window, then open it again."),
        ],
        "faqs": [
            ("Why is my camera black in Zoom but works in FaceTime?", "Zoom keeps its own camera choice. Open Settings › Video & effects and pick the camera that works in FaceTime. If Zoom isn't allowed under System Settings › Privacy & Security › Camera, turn on zoom.us and restart Zoom."),
            ("How do I test my Zoom camera before a meeting?", "Open Zoom, click your profile picture, then Settings › Video & effects. The preview at the top shows the selected camera. You can also join Zoom's test meeting from zoom.us/test."),
            ("Do I need to restart Zoom after allowing the camera?", "Yes. Zoom says macOS asks you to restart the app after you change a permission. Quit Zoom completely and open it again."),
            ("Why does Zoom show my iPhone's camera?", "That's Continuity Camera. When your iPhone is nearby, it can show up as a camera on your Mac. Pick your Mac's camera in Zoom's Video & effects settings."),
        ],
    },
    {
        "slug": "zoom-microphone-not-working", "app": "zoom", "device": "microphone",
        "title": "Zoom Microphone Not Working on Mac? Fix It in Order",
        "h1": "Zoom microphone not working?", "em": "Fix it on your Mac.",
        "desc": "People can't hear you on Zoom? Join computer audio, pick the right mic in Settings › Audio, check Automatically adjust microphone volume, and allow zoom.us.",
        "lede": "When nobody can hear you, it's usually one of four things: Zoom never joined audio, it's using the wrong mic, you're muted, or macOS is blocking zoom.us.",
        "quick": "Try the <a href=\"/mic-test\">free mic test</a>. If the meter moves there, your mic works and the fix is in Zoom (steps 1 to 4). If it stays flat, start with the Mac checks.",
        "steps": [
            ("Join computer audio.", "If the meeting controls show Join Audio instead of Mute, Zoom isn't using your mic or speakers yet. Click Join Audio and choose Join with Computer Audio. To skip this next time, turn on Automatically connect to computer audio under Settings › Meetings & webinars."),
            ("Pick the mic in Zoom.", "Click your profile picture, then Settings › Audio. Under Microphone, choose your mic from the menu and click Test microphone. The Input volume bar should move when you talk."),
            ("Check Automatically adjust microphone volume.", "With it on, Zoom sets your level for you and the Input volume slider is unavailable. If you sound too quiet, turn it off and raise the slider yourself."),
            ("Switch mics during a meeting.", "Click the arrow next to Mute in the meeting controls and pick another microphone. Also make sure the mic button isn't crossed out, and that the host hasn't muted you."),
        ],
        "extra": [
            ("Echo or choppy voice", "Zoom has an Echo cancellation setting under Settings › Audio › Advanced, with Auto, Low, and High. Zoom marks it for technical users, so leave it on Auto unless someone tells you your voice cuts out."),
            ("The mute switch on the mic itself", "Zoom's help says to check for a physical mute switch on the mic or headset. A headset boom flipped up, or a button on a USB mic, mutes it before Zoom ever hears you."),
        ],
        "faqs": [
            ("Why can't anyone hear me on Zoom when my mic works?", "Usually Zoom hasn't joined computer audio, or it picked a different mic. Click Join Audio if you see it, then click the arrow next to Mute and choose your mic."),
            ("Why is the Input volume slider grayed out in Zoom?", "Automatically adjust microphone volume is on. Turn it off in Settings › Audio and the slider works again."),
            ("Does Zoom need permission to use my mic on a Mac?", "Yes. Open System Settings › Privacy & Security › Microphone and turn on zoom.us. Zoom asks you to restart it after the change."),
            ("How do I test my mic in Zoom?", "Open Settings › Audio and click Test microphone. Zoom records a few seconds and plays them back. You can also choose Test speaker and microphone when you join a meeting."),
        ],
    },
    {
        "slug": "zoom-audio-not-working", "app": "zoom", "device": "audio",
        "title": "Zoom Audio Not Working on Mac? Hear Your Call Again",
        "h1": "Zoom audio not working?", "em": "Hear your call again.",
        "desc": "Can't hear anyone on Zoom on your Mac? Join computer audio, pick the right speaker in Settings › Audio, test it, then check where your Mac is sending sound.",
        "lede": "If the meeting is silent, Zoom either hasn't joined audio or is playing it somewhere you aren't listening, like a monitor or AirPods in another room.",
        "quick": "Play a tone on the <a href=\"/speaker-test\">free speaker test</a>. If you hear it, your speakers work and the fix is in Zoom (steps 1 to 3). If you don't, start with the Mac checks.",
        "steps": [
            ("Join computer audio.", "If you see Join Audio in the meeting controls, you aren't connected to the meeting's sound yet. Click it and choose Join with Computer Audio."),
            ("Pick the speaker in Zoom.", "Click your profile picture, then Settings › Audio. Under Speaker, choose where you want sound and click Test speaker. If you don't hear the tone, pick another speaker or raise the Output volume."),
            ("Switch speakers during a meeting.", "Click the arrow next to Mute. The same menu lists speakers as well as mics, so you can move sound to your headphones without leaving."),
        ],
        "extra": [
            ("Sound goes to your monitor", "Displays with speakers show up as outputs. If you picked one in Zoom, or your Mac switched to it when you plugged in, the call plays from a screen you may have muted. Pick your headphones or Mac speakers instead."),
            ("Everyone sounds like a phone call", "On AirPods or another Bluetooth headset, Zoom turning on the headset's mic drops the sound you hear to phone quality. Use your Mac's mic for your voice and the headset just for listening."),
        ],
        "faqs": [
            ("Why can't I hear anyone on Zoom?", "Check for a Join Audio button first. If you've joined, click the arrow next to Mute and make sure the speaker is the one you're listening on, then check your Mac's volume."),
            ("Zoom's test tone works but the meeting is silent. Why?", "The meeting may be using a different speaker than the one you tested, or you haven't joined computer audio. Pick the speaker again from the arrow next to Mute."),
            ("Why does Zoom sound bad on my AirPods?", "When Zoom uses the AirPods' mic, they switch to call mode and everything you hear drops to phone quality. Pick your Mac's mic in Zoom and keep the AirPods as the speaker."),
        ],
    },
    # ---------------------------------------------------------------- Teams
    {
        "slug": "teams-camera-not-working", "app": "teams", "device": "camera",
        "title": "Teams Camera Not Working on Mac? Fix It in Order",
        "h1": "Teams camera not working?", "em": "Fix it on your Mac.",
        "desc": "Microsoft Teams can't find your camera on a Mac? Update to new Teams, pick the camera in Settings › Devices, and allow Microsoft Teams in Privacy & Security.",
        "lede": "Teams camera problems on a Mac come down to the Teams version, the camera Teams picked, or a permission macOS never got. Start at the top.",
        "quick": "Open the <a href=\"/webcam-test\">free webcam test</a>. If you see yourself there, the camera works and the fix is in Teams (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Make sure you're on new Teams.", "Microsoft says classic Teams stopped working on July 1, 2025. If you still have an old copy, install the current Teams app from Microsoft and use that."),
            ("Pick the camera in Teams.", "Select Settings and more (the three dots next to your profile picture), then Settings › Devices. Choose your camera from the Camera menu and check the preview."),
            ("Turn the camera on in the meeting.", "If the camera button in the meeting controls has a line through it, select it to turn video on. Teams can join with video off."),
        ],
        "extra": [
            ("Teams in the browser", "Teams on the web needs your browser's camera permission as well as the Mac's. In Safari, Microsoft says to open Safari › Settings › Websites › Camera and set the site to Ask or Allow."),
            ("Microsoft's own fix", "Microsoft's help for Mac is to turn on the Teams permission, then close all apps and restart. It also says to make sure no other app, like FaceTime, is using the camera, and to unplug and reconnect an external camera."),
        ],
        "faqs": [
            ("Why does Teams say no camera is available on my Mac?", "macOS is usually blocking it. Open System Settings › Privacy & Security › Camera, turn on Microsoft Teams, then quit everything and restart, as Microsoft recommends."),
            ("Does classic Teams still work on a Mac?", "No. Microsoft says classic Teams stopped working on July 1, 2025. Install the current Teams app."),
            ("How do I check my camera in Teams before a meeting?", "Open Settings and more › Settings › Devices. The camera preview there shows what people will see."),
            ("My camera works in Zoom but not Teams. Why?", "Each app keeps its own camera choice and its own permission. Pick the camera in Teams under Settings › Devices, and check that Microsoft Teams is on under Privacy & Security › Camera."),
        ],
    },
    {
        "slug": "teams-microphone-not-working", "app": "teams", "device": "microphone",
        "title": "Teams Microphone Not Working on Mac? Fix It in Order",
        "h1": "Teams microphone not working?", "em": "Fix it on your Mac.",
        "desc": "People can't hear you in Microsoft Teams? Pick the mic in Settings › Devices, make a test call, check Sync device buttons, and allow Microsoft Teams on your Mac.",
        "lede": "Teams can be muted in three places at once: the meeting, your headset, and macOS. Check each, then make a test call.",
        "quick": "Try the <a href=\"/mic-test\">free mic test</a>. If the meter moves, your mic works and the fix is in Teams (steps 1 to 4). If it doesn't, start with the Mac checks.",
        "steps": [
            ("Pick the mic in Teams.", "Select Settings and more, then Settings › Devices. Under Audio settings, choose your mic from the Microphone menu."),
            ("Make a test call.", "On the same page, select Make a test call. The Test Call Bot records a short message and plays it back, then shows which devices worked. It's only in the desktop app, not Teams on the web."),
            ("Switch mics during a meeting.", "Select the arrow next to Mic, then More audio settings, and make sure the right mic is selected. If the Mic button has a line through it, select Unmute mic."),
            ("Check the mic sensitivity and noise settings.", "In Settings › Devices, Automatically adjust mic sensitivity sets your level for you, and Noise suppression filters background sound. If your voice cuts out, try changing them one at a time."),
        ],
        "extra": [
            ("Your headset's mute button", "Teams has a Sync device buttons setting so a headset's own mute button controls Teams. Microsoft's help also says to check that a headset boom isn't in the mute position and that an external mic's mute button is off."),
            ("New Teams after an update", "After Teams updates, macOS can ask for microphone access again. If you clicked Don't Allow, turn Microsoft Teams back on in Privacy & Security."),
        ],
        "faqs": [
            ("Why can't people hear me in Teams on my Mac?", "Check the meeting first: if the Mic button has a line through it, unmute. Then select the arrow next to Mic, open More audio settings, and pick the mic you're using. If it's still silent, turn on Microsoft Teams under System Settings › Privacy & Security › Microphone."),
            ("How do I test my mic in Teams?", "Open Settings and more › Settings › Devices and select Make a test call. A bot records you and plays it back. It works in the desktop app, not on the web."),
            ("Does Teams need permission to use my mic?", "Yes. Turn on Microsoft Teams in System Settings › Privacy & Security › Microphone, then close your apps and restart, as Microsoft suggests."),
            ("Why does my voice cut out in Teams?", "Noise suppression or automatic mic sensitivity can clip a quiet voice. Try turning them off in Settings › Devices, and keep a Bluetooth headset close to your Mac."),
        ],
    },
    {
        "slug": "teams-audio-not-working", "app": "teams", "device": "audio",
        "title": "Teams Audio Not Working on Mac? Hear Your Meeting Again",
        "h1": "Teams audio not working?", "em": "Hear your meeting again.",
        "desc": "Can't hear anyone in Microsoft Teams on your Mac? Pick the speaker in Settings › Devices, check Audio settings in the meeting, and make a test call.",
        "lede": "Silence in a Teams meeting usually means Teams is playing to a different speaker than the one you're listening on.",
        "quick": "Play a tone on the <a href=\"/speaker-test\">free speaker test</a>. If you hear it, your speakers work and the fix is in Teams (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Pick the speaker in Teams.", "Select Settings and more, then Settings › Devices. Under Audio settings, choose where you want sound from the Speaker menu."),
            ("Check it during the meeting.", "Select the arrow next to Mic, then More actions › Audio settings. Under Speaker, make sure your device is selected and unmuted."),
            ("Make a test call.", "In Settings › Devices, select Make a test call. If you hear the Test Call Bot, your speaker works in Teams."),
        ],
        "extra": [
            ("Bluetooth headset not listed", "Microsoft's help says a Bluetooth device that doesn't appear in Teams should be charged and reconnected. Connect it in your Mac's Bluetooth settings first, then pick it in Teams."),
            ("Update Teams and macOS", "Microsoft's help for sound problems starts with the latest Teams version and the latest macOS update. In Teams, use Check for updates from Settings and more."),
        ],
        "faqs": [
            ("Why can't I hear anyone in Teams?", "Teams may be playing to another speaker. In the meeting, select the arrow next to Mic, then More actions › Audio settings, and pick the speaker you're listening on."),
            ("Can I test my speaker in Teams?", "Yes. Make a test call from Settings › Devices. It's only in the desktop app."),
            ("Why does Teams sound muffled on AirPods?", "When Teams uses the AirPods' mic, they switch to call mode and sound drops to phone quality. Use your Mac's mic in Teams and keep the AirPods for listening."),
        ],
    },
    # ---------------------------------------------------------------- Google Meet
    {
        "slug": "google-meet-camera-not-working", "app": "google-meet", "device": "camera",
        "title": "Google Meet Camera Not Working on Mac? Fix It in Order",
        "h1": "Google Meet camera not working?", "em": "Fix it on your Mac.",
        "desc": "Meet says your camera is blocked or shows black? Allow the camera for meet.google.com in Chrome or Safari, allow your browser in Privacy & Security, and pick the camera.",
        "lede": "Meet runs in your browser, so the camera has to get past two gates: the browser's permission for meet.google.com, and macOS's permission for the browser.",
        "quick": "Open the <a href=\"/webcam-test\">free webcam test</a> in the same browser. If you see yourself there, the browser and Mac are fine and the fix is in Meet's settings (step 4). If not, work down from step 1.",
        "steps": [
            ("Allow the camera for Meet.", "In a meeting, click the camera icon in Chrome's address bar, turn on Camera, and choose Allow on every visit."),
            ("Check Chrome's camera settings.", "Go to chrome://settings/content/camera. Under Default behavior, choose Sites can ask to use your camera. If meet.google.com is listed under blocked sites, remove it and allow it again."),
            ("Using Safari?", "Choose Safari › Settings, click Websites, then Camera, and set meet.google.com to Allow."),
            ("Pick the camera in Meet.", "On the preview screen, click the arrow on the camera button and choose a camera. In a meeting, click the arrow next to the camera button, or open More options › Settings › Video."),
        ],
        "extra": [
            ("Restart the browser the right way", "Google's help says closing Chrome after an update may not reset what's holding the camera. Type chrome://restart in the address bar, then rejoin."),
            ("Works in Photo Booth, not in Meet", "Google says that if the camera shows you in Photo Booth but not in Meet, the browser or Mac permission is the problem, not the camera. Close other apps that use the camera, then reload Meet."),
        ],
        "faqs": [
            ("Why does Google Meet say my camera is blocked?", "Meet doesn't have the browser's permission. Click the camera icon in the address bar, turn on Camera, and choose Allow on every visit."),
            ("How do I allow the camera for Meet in Safari?", "Choose Safari › Settings › Websites › Camera and set meet.google.com to Allow."),
            ("Meet works in Chrome but not in another browser. Why?", "Each browser has its own permission, both for the site and in System Settings › Privacy & Security › Camera. Allow both in the browser you're using."),
            ("Do I need to restart Chrome?", "Often, yes. Google suggests typing chrome://restart in the address bar so Chrome fully restarts, then rejoining the meeting."),
        ],
    },
    {
        "slug": "google-meet-microphone-not-working", "app": "google-meet", "device": "microphone",
        "title": "Google Meet Microphone Not Working on Mac? Fix It",
        "h1": "Google Meet mic not working?", "em": "Fix it on your Mac.",
        "desc": "People can't hear you on Google Meet? Allow the mic for meet.google.com, allow your browser in Privacy & Security, and pick the mic in Meet's Audio settings.",
        "lede": "Meet hears your mic only if the site, the browser, and your Mac all allow it. Then it has to pick the right mic.",
        "quick": "Try the <a href=\"/mic-test\">free mic test</a> in the same browser. If the meter moves, the browser and Mac are fine and the fix is in Meet (steps 3 and 4). If not, start at step 1.",
        "steps": [
            ("Allow the mic for Meet.", "In the address bar, click View site information and turn on Microphone."),
            ("Check Chrome's mic settings.", "Go to chrome://settings/content/microphone and under Default behavior choose Sites can ask to use your microphone. In Safari, use Safari › Settings › Websites › Microphone."),
            ("Pick the mic in Meet.", "Click the arrow next to the mic button and choose your mic, or open More options › Settings › Audio. Talk and watch the bar move."),
            ("Unmute.", "If the mic button at the bottom is red, click it to turn on your microphone."),
        ],
        "extra": [
            ("Mic still dead? Reset Core Audio", "Google's help gives a Mac fix that needs an admin password: open Terminal, type <code>sudo killall coreaudiod</code>, enter your password, and rejoin. It restarts the Mac's sound service."),
            ("Echo", "Google notes that a mic and a separate external speaker can cause echo. Headphones fix it."),
        ],
        "faqs": [
            ("Why can't anyone hear me on Google Meet?", "Check the mic button isn't red, then click the arrow next to it and pick the mic you're using. If Meet shows no mics, allow the microphone for meet.google.com and for your browser in Privacy & Security."),
            ("How do I allow the mic for Meet in Safari?", "Choose Safari › Settings › Websites › Microphone and set meet.google.com to Allow."),
            ("Where are Meet's audio settings?", "On the preview screen, or in a meeting under More options › Settings › Audio."),
            ("Does my browser need permission on a Mac?", "Yes. Open System Settings › Privacy & Security › Microphone and turn on the browser you use for Meet."),
        ],
    },
    {
        "slug": "google-meet-audio-not-working", "app": "google-meet", "device": "audio",
        "title": "Google Meet Audio Not Working on Mac? Hear It Again",
        "h1": "Google Meet audio not working?", "em": "Hear your call again.",
        "desc": "Can't hear people on Google Meet on your Mac? Pick the speaker in More options › Settings › Audio, use Test speakers, and check your monitor isn't the output.",
        "lede": "If Meet is quiet, the sound is usually going to a speaker you aren't using, or the browser tab is muted.",
        "quick": "Play a tone on the <a href=\"/speaker-test\">free speaker test</a> in the same browser. If you hear it, your speakers work and the fix is in Meet (steps 1 and 2). If not, start with the Mac checks.",
        "steps": [
            ("Pick the speaker in Meet.", "Click More options › Settings › Audio and choose a speaker. Before you join, use the speaker button on the preview screen."),
            ("Test it.", "Click the speaker control and choose Test speakers. If you hear the sound, Meet is playing to the right place."),
            ("Unmute the tab.", "If the Meet tab is muted in your browser, you won't hear anything. In Chrome, right click the tab and choose Unmute site."),
        ],
        "extra": [
            ("Your monitor is the speaker", "Google's help calls this out: if you use a monitor, make sure it isn't your selected audio output."),
            ("Bluetooth", "Google says to turn on Bluetooth and connect to the right audio device. AirPods can quietly connect to your phone instead of your Mac."),
        ],
        "faqs": [
            ("Why can't I hear anyone on Google Meet?", "Meet may be playing to another speaker, often a monitor. Open More options › Settings › Audio and pick the speaker you're listening on."),
            ("How do I test my speakers in Meet?", "Click the speaker control and choose Test speakers, on the preview screen or during a meeting."),
            ("Meet sound is fine in one browser but not another. Why?", "The tab or site may be muted in that browser. In Chrome, right click the tab and choose Unmute site."),
        ],
    },
    # ---------------------------------------------------------------- Discord
    {
        "slug": "discord-mic-not-working", "app": "discord", "device": "microphone",
        "title": "Discord Mic Not Working on Mac? Fix It in Order",
        "h1": "Discord mic not working?", "em": "Fix it on your Mac.",
        "desc": "Mic works in the Discord test but nobody hears you? Check Input Device, Input Mode, input sensitivity, Krisp, and Discord's mic permission on your Mac.",
        "lede": "Discord's mic can pass its own test and still send nothing, because Push to Talk or input sensitivity decides when you're heard.",
        "quick": "Try the <a href=\"/mic-test\">free mic test</a>. If the meter moves, your mic works and the fix is in Discord (steps 1 to 4). If not, start with the Mac checks.",
        "steps": [
            ("Pick your mic, not Default.", "Click the gear next to your name at the bottom left to open User Settings, then Voice & Video. Set Input Device to your mic by name and run the Mic Test."),
            ("Check Input Mode.", "Push to Talk only sends your voice while you hold the key. For calls, choose Voice Activity."),
            ("Set input sensitivity.", "Discord says automatic sensitivity can clip the ends of sentences or miss you with background noise. Turn off Automatically determine input sensitivity and drag the marker so it lights up when you talk, not when you're quiet."),
            ("Toggle the voice processing.", "Discord's troubleshooting guide says to try Noise Suppression, Echo Cancellation, and Automatic Gain Control off and on. Its Krisp FAQ warns that in a quiet room with a good mic, noise suppression can make you sound worse."),
        ],
        "extra": [
            ("Server muted", "If a red mic icon shows next to your name in a server and you didn't mute yourself, a moderator muted you in that server. Your settings can't override it."),
            ("Start over", "If nothing helps, Discord suggests Reset Voice and Video Settings, found on the Debugging tab of Voice & Video."),
        ],
        "faqs": [
            ("Why does the Discord mic test work but no one hears me?", "Check Input Mode. On Push to Talk you're only heard while holding the key. On Voice Activity, lower the sensitivity marker so your normal voice crosses it."),
            ("Does Discord need mic permission on a Mac?", "Yes. Open System Settings › Privacy & Security › Microphone and turn on Discord, then quit and reopen it."),
            ("Should I turn off Krisp noise suppression?", "Try it. Discord's own FAQ says that in a quiet room with a high quality mic, noise suppression can lower your voice quality."),
            ("Why does my voice cut out on Discord?", "Usually the input sensitivity is set too high. Turn off automatic sensitivity and set the marker by hand."),
        ],
    },
    {
        "slug": "discord-camera-not-working", "app": "discord", "device": "camera",
        "title": "Discord Camera Not Working on Mac? Fix It in Order",
        "h1": "Discord camera not working?", "em": "Fix it on your Mac.",
        "desc": "Discord camera black or missing on your Mac? Pick it in Voice & Video › Camera, use Test Video, and allow Discord in Privacy & Security › Camera.",
        "lede": "Discord needs the Mac's camera permission and the right camera picked. Test Video tells you which one is the problem.",
        "quick": "Open the <a href=\"/webcam-test\">free webcam test</a>. If you see yourself there, the camera works and the fix is in Discord (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Pick the camera.", "Open User Settings with the gear at the bottom left, then Voice & Video. Under Video Settings, choose your camera from the Camera menu."),
            ("Use Test Video.", "Click Test Video in the same section. If you see yourself, Discord can use the camera and the problem is in the call."),
            ("Turn your camera on in the call.", "In a voice channel or call, click the camera button to start video."),
        ],
        "extra": [
            ("Video backgrounds", "Discord's video backgrounds are set in the same Video Settings section. If your picture looks wrong, set the background to none and test again."),
            ("Discord in a browser", "In a browser, Discord needs the browser's camera permission for the site, and the browser needs the Mac's permission too."),
            ("Start over", "Discord suggests Reset Voice and Video Settings on the Debugging tab of Voice & Video when settings get tangled."),
        ],
        "faqs": [
            ("Why is my Discord camera black?", "Check System Settings › Privacy & Security › Camera and turn on Discord, then quit and reopen it. Then pick the camera in Voice & Video and click Test Video."),
            ("How do I test my camera in Discord?", "Open User Settings › Voice & Video and click Test Video under Video Settings."),
            ("Discord doesn't list my camera. What now?", "Unplug and reconnect it, try a different port, and skip the hub. If your Mac doesn't see it in System Information, Discord can't either."),
        ],
    },
    {
        "slug": "discord-audio-not-working", "app": "discord", "device": "audio",
        "title": "Discord Audio Not Working on Mac? Hear People Again",
        "h1": "Discord audio not working?", "em": "Hear people again.",
        "desc": "Can't hear people on Discord on your Mac? Check Output Device and Output Volume, undeafen, check each person's User Volume, then where your Mac sends sound.",
        "lede": "When Discord goes quiet, check whether you're deafened, which Output Device it's using, and whether one person is turned down.",
        "quick": "Play a tone on the <a href=\"/speaker-test\">free speaker test</a>. If you hear it, your speakers work and the fix is in Discord (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Undeafen.", "If the headphones icon next to your name at the bottom left has a line through it, you're deafened and hear nothing. Click it."),
            ("Pick the Output Device.", "Open User Settings › Voice & Video and set Output Device to your headphones or speakers by name. Raise Output Volume."),
            ("Check one person's volume.", "If you can't hear just one person, right click their name and check User Volume. It may be at zero, or you may have muted them."),
        ],
        "extra": [
            ("Start over", "If audio still won't play, Discord suggests Reset Voice and Video Settings on the Debugging tab of Voice & Video."),
            ("Muffled on AirPods", "When Discord turns on the AirPods' mic, they switch to call mode and everything sounds like a phone call. Use your Mac's mic as Discord's Input Device and keep the AirPods for listening."),
        ],
        "faqs": [
            ("Why can't I hear anyone on Discord?", "Check you aren't deafened (the headphones icon), then make sure Output Device in Voice & Video is the one you're listening on."),
            ("Why can't I hear just one person on Discord?", "Right click their name and check User Volume, or whether you muted them. It may also be their mic."),
            ("Why does Discord sound bad on Bluetooth headphones?", "Using the headset's mic switches it to call mode. Pick another mic as Input Device and the sound returns to full quality."),
        ],
    },
    # ---------------------------------------------------------------- FaceTime
    {
        "slug": "facetime-camera-not-working", "app": "facetime", "device": "camera",
        "title": "FaceTime Camera Not Working on Mac? Fix It in Order",
        "h1": "FaceTime camera not working?", "em": "Fix it on your Mac.",
        "desc": "FaceTime camera black or showing the wrong view on your Mac? Pick it from the Video menu, check Continuity Camera and video effects, and check Screen Time.",
        "lede": "FaceTime picks a camera for you. When it picks your iPhone, an old webcam, or nothing at all, the Video menu is where to fix it.",
        "quick": "Open the <a href=\"/webcam-test\">free webcam test</a>. If you see yourself there, the camera works and the fix is in FaceTime (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Pick the camera from the Video menu.", "In FaceTime, open the Video menu in the menu bar and choose your camera. Automatic Camera Selection lets FaceTime choose based on what's connected and what you used last; pick one by name if it keeps choosing wrong."),
            ("Check for your iPhone.", "With Continuity Camera, your iPhone's camera can show up in the Video menu. If the call shows your phone's view, choose your Mac's camera."),
            ("Check video effects.", "During a call, click the Video button in the menu bar. Background, Portrait, and Studio Light change your picture. Turn them off to see if the camera itself is fine."),
        ],
        "extra": [
            ("Screen Time", "If Screen Time restricts apps on this Mac, FaceTime or the camera can be turned off there. See the Screen Time step below."),
            ("No cameras in the Video menu", "Apple says that if no other devices appear in the Video menu, FaceTime uses the built-in camera. If that's black too, the Mac checks below apply."),
        ],
        "faqs": [
            ("How do I change the camera in FaceTime on a Mac?", "Open FaceTime, click the Video menu, and choose a camera, or Automatic Camera Selection."),
            ("Why does FaceTime use my iPhone camera?", "Continuity Camera can switch to your iPhone when it's nearby. Choose your Mac's camera in FaceTime's Video menu."),
            ("Why does my FaceTime picture look strange?", "A video effect may be on. During a call, click the Video button in the menu bar and turn off Background, Portrait, or Studio Light."),
        ],
    },
    {
        "slug": "facetime-microphone-not-working", "app": "facetime", "device": "microphone",
        "title": "FaceTime Microphone Not Working on Mac? Fix It",
        "h1": "FaceTime microphone not working?", "em": "Fix it on your Mac.",
        "desc": "People can't hear you on FaceTime on your Mac? Pick the mic in the Video menu, check Mic Mode, unmute, and check your Mac's Sound input.",
        "lede": "FaceTime has its own mic choice and its own Mic Mode. If either is off, people hear nothing, or hear the room instead of you.",
        "quick": "Try the <a href=\"/mic-test\">free mic test</a>. If the meter moves, your mic works and the fix is in FaceTime (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Pick the mic from the Video menu.", "In FaceTime, open the Video menu and choose your microphone. Use System Setting follows whatever is set in System Settings › Sound."),
            ("Unmute.", "During a call, check the mute button in the FaceTime window. A muted call sends no sound at all."),
            ("Check Mic Mode.", "During a call, click the Video button in the menu bar, then the arrow next to Mic Mode. Voice Isolation keeps your voice and cuts the room. Wide Spectrum lets everything in. Standard is the normal setting."),
        ],
        "extra": [
            ("Mic Mode needs a 2018 or later Mac", "Apple says Mic Modes are on Mac models from 2018 and later, and only show up in apps that support them."),
        ],
        "faqs": [
            ("How do I change the mic in FaceTime on a Mac?", "Open FaceTime, click the Video menu, and choose a microphone, or Use System Setting."),
            ("Why do people hear background noise on my FaceTime calls?", "Mic Mode may be on Wide Spectrum. During a call, click the Video button in the menu bar and choose Voice Isolation under Mic Mode."),
            ("Where is Mic Mode on a Mac?", "During a FaceTime call, click the Video button in the menu bar, then the arrow next to Mic Mode."),
        ],
    },
    {
        "slug": "facetime-audio-not-working", "app": "facetime", "device": "audio",
        "title": "FaceTime Audio Not Working on Mac? Hear Your Call Again",
        "h1": "FaceTime audio not working?", "em": "Hear your call again.",
        "desc": "Can't hear the other person on FaceTime on your Mac? Pick the output in FaceTime's Video menu, check your Mac's Sound output, and reconnect AirPods.",
        "lede": "FaceTime can play to its own output, separate from the rest of your Mac. Check that first.",
        "quick": "Play a tone on the <a href=\"/speaker-test\">free speaker test</a>. If you hear it, your speakers work and the fix is in FaceTime (steps 1 and 2). If not, start with the Mac checks.",
        "steps": [
            ("Pick the output from the Video menu.", "In FaceTime, open the Video menu and choose the speakers or headphones you want. Use System Setting follows the output in System Settings › Sound."),
            ("Check the volume during the call.", "Raise your Mac's volume while the call is going. If the other person's mic is muted, you won't hear them either; ask them to check."),
        ],
        "extra": [
            ("AirPods jumped to your iPhone", "AirPods can connect to whichever Apple device you used last. If the call is silent, check that your AirPods are connected to this Mac."),
        ],
        "faqs": [
            ("How do I change the speaker in FaceTime on a Mac?", "Open FaceTime, click the Video menu, and choose an audio output, or Use System Setting."),
            ("Why can't I hear FaceTime on my AirPods?", "They may be connected to your iPhone or iPad. Connect them to your Mac from the Sound or Bluetooth menu, then pick them in FaceTime's Video menu."),
            ("FaceTime is silent but other apps play sound. Why?", "FaceTime may be set to a different output. Choose Use System Setting in the Video menu."),
        ],
    },
    # ---------------------------------------------------------------- Slack
    {
        "slug": "slack-huddle-microphone-not-working", "app": "slack", "device": "microphone",
        "title": "Slack Huddle Microphone Not Working on Mac? Fix It",
        "h1": "Slack huddle mic not working?", "em": "Fix it on your Mac.",
        "desc": "People can't hear you in a Slack huddle? Pick the mic in Preferences › Audio & video, run Slack's test, and turn Slack back on in Privacy & Security › Microphone.",
        "lede": "Slack huddles use their own mic choice, and another calling app can take away Slack's mic access without telling you.",
        "quick": "Try the <a href=\"/mic-test\">free mic test</a>. If the meter moves, your mic works and the fix is in Slack (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Pick the mic in Slack.", "Click your profile picture, then Preferences › Audio & video. Under Microphone, choose your mic, say a few words, and watch the level move."),
            ("Run Slack's test.", "On the same page, under Troubleshooting, click Run test. It works in the desktop app and in Slack in Chrome."),
            ("Use the huddle troubleshooter.", "During a huddle, click the troubleshooting icon at the bottom left. A warning icon there marks the problem."),
        ],
        "extra": [
            ("Another calling app took the mic", "Slack's help says other calling apps can revoke Slack's microphone access. Turn Slack off and on again in Privacy & Security › Microphone, then quit and reopen Slack."),
            ("Slack in the browser", "If the desktop app won't work, Slack suggests trying your workspace in Chrome, or the other way around. In Chrome, make sure your workspace isn't blocked under Settings › Privacy and security › Site settings › Microphone."),
        ],
        "faqs": [
            ("Why can't anyone hear me in a Slack huddle?", "Open Preferences › Audio & video and pick the mic you're using, then click Run test. If Slack shows no level, turn on Slack in System Settings › Privacy & Security › Microphone."),
            ("How do I test my mic in Slack?", "Open Preferences › Audio & video and click Run test under Troubleshooting."),
            ("My Slack mic stopped working after I used another call app. Why?", "Slack says other calling apps can revoke its mic access. Turn Slack off and back on under Privacy & Security › Microphone, then reopen Slack."),
        ],
    },
    {
        "slug": "slack-huddle-audio-not-working", "app": "slack", "device": "audio",
        "title": "Slack Huddle Audio Not Working on Mac? Hear It Again",
        "h1": "Slack huddle audio not working?", "em": "Hear your huddle again.",
        "desc": "Can't hear anyone in a Slack huddle on your Mac? Pick the speaker in Preferences › Audio & video, use Test Speaker in the huddle, and try Audio-only mode.",
        "lede": "If a huddle is silent, Slack is likely playing to a different speaker, or your connection is dropping the sound.",
        "quick": "Play a tone on the <a href=\"/speaker-test\">free speaker test</a>. If you hear it, your speakers work and the fix is in Slack (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Pick the speaker in Slack.", "Click your profile picture, then Preferences › Audio & video. Under Speaker, choose where you want sound and click Test to hear a chime."),
            ("Test it during the huddle.", "Click the three dots in the huddle and choose Test Speaker."),
            ("Try Audio-only mode.", "If sound cuts in and out, click the troubleshooting icon at the bottom left of the huddle and turn on Audio-only mode."),
        ],
        "extra": [
            ("Run the full test", "Preferences › Audio & video › Troubleshooting › Run test checks your devices and connection. It works in the desktop app and in Slack in Chrome."),
        ],
        "faqs": [
            ("Why can't I hear anyone in a Slack huddle?", "Slack may be playing to another speaker. Click the three dots in the huddle, choose Test Speaker, and change the speaker in Preferences › Audio & video if you don't hear it."),
            ("Why does huddle audio keep cutting out?", "Usually the connection. Turn on Audio-only mode from the troubleshooting icon at the bottom left of the huddle."),
            ("Does Slack need permission to play sound?", "No. Speakers don't need a privacy permission on a Mac. Only the mic and camera do."),
        ],
    },
    # ---------------------------------------------------------------- Webex
    {
        "slug": "webex-camera-not-working", "app": "webex", "device": "camera",
        "title": "Webex Camera Not Working on Mac? Fix It in Order",
        "h1": "Webex camera not working?", "em": "Fix it on your Mac.",
        "desc": "Webex can't connect to your webcam on a Mac? Pick the camera in Settings › Video, allow Webex in Privacy & Security, and close other apps using it.",
        "lede": "Webex shows a black picture when it's pointed at the wrong camera, when a virtual camera gets in the way, or when macOS blocks it.",
        "quick": "Open the <a href=\"/webcam-test\">free webcam test</a>. If you see yourself there, the camera works and the fix is in Webex (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Pick the camera in Webex.", "Outside a meeting, click Settings in the sidebar, then Video, and choose your camera from the Camera menu."),
            ("Switch during a meeting.", "Hover over your own video, click More options › Video Settings, and pick the camera."),
            ("Turn off virtual camera software.", "Webex's help says virtual webcam software can cause problems. Pick your real camera, or turn the virtual camera off and try again."),
        ],
        "extra": [
            ("Default camera for meetings", "Under Settings › Meetings › Join & Leave, Webex lets you choose default audio and video for meetings. Check you aren't joining with video off by default."),
            ("Test outside Webex", "Webex suggests checking whether Photo Booth sees the camera. If it doesn't, the problem is the camera or the Mac, not Webex."),
        ],
        "faqs": [
            ("Why does Webex say it can't connect to my webcam?", "Close other apps using the camera, like Teams, and make sure Webex is on under System Settings › Privacy & Security › Camera. Then pick the camera in Settings › Video."),
            ("How do I change cameras in a Webex meeting?", "Hover over your own video, click More options › Video Settings, and choose a camera."),
            ("Can a virtual camera break Webex video?", "Yes. Webex's help says to turn off virtual webcam software and see if that fixes it."),
        ],
    },
    {
        "slug": "webex-microphone-not-working", "app": "webex", "device": "microphone",
        "title": "Webex Microphone Not Working on Mac? Fix It in Order",
        "h1": "Webex microphone not working?", "em": "Fix it on your Mac.",
        "desc": "People can't hear you on Webex? Pick the mic in Settings › Audio, test it, check Smart audio, and set macOS Mic Mode to Standard as Webex recommends.",
        "lede": "Webex and macOS both try to clean up your voice. When they fight, you can sound cut off or far away.",
        "quick": "Try the <a href=\"/mic-test\">free mic test</a>. If the meter moves, your mic works and the fix is in Webex (steps 1 to 4). If not, start with the Mac checks.",
        "steps": [
            ("Pick the mic in Webex.", "Click Settings in the sidebar, then Audio, and choose your microphone. Follow system setting uses whatever your Mac's Sound settings pick."),
            ("Test it.", "Click Test next to the microphone and say a few words. Webex plays them back. In a meeting, open Audio options › Audio Settings to do the same."),
            ("Check Automatically adjust volume.", "In Settings › Audio, this lets Webex set your mic level. Turn it off if you sound too quiet and set the level yourself."),
            ("Check Smart audio.", "Under Settings › Smart audio, Noise removal, Optimize for my voice, Optimize for all voices, and Music mode change how your voice is processed. Try Noise removal first."),
        ],
        "extra": [
            ("macOS Mic Mode fights Webex", "Webex's help says macOS Mic Modes can conflict with its Smart audio, and recommends the Standard mic mode with Webex. During a meeting, open Control Center, click Mic Mode, and choose Standard."),
            ("Muted by the host", "Webex's help notes the host may have muted you. If your mic icon shows muted and you didn't do it, ask the host."),
        ],
        "faqs": [
            ("Why can't people hear me on Webex?", "Pick your mic in Settings › Audio and click Test. If you aren't muted and it still fails, turn on Webex in System Settings › Privacy & Security › Microphone."),
            ("Which Mic Mode should I use with Webex?", "Standard. Webex says other macOS Mic Modes can conflict with its own Smart audio settings."),
            ("How do I test my mic in Webex?", "Open Settings › Audio, or Audio options › Audio Settings in a meeting, and click Test next to the microphone."),
        ],
    },
    {
        "slug": "webex-audio-not-working", "app": "webex", "device": "audio",
        "title": "Webex Audio Not Working on Mac? Hear Your Meeting Again",
        "h1": "Webex audio not working?", "em": "Hear your meeting again.",
        "desc": "Can't hear anyone on Webex on your Mac? Pick the speaker in Settings › Audio, test it, check the ringer device, and check your Mac's volume.",
        "lede": "Webex picks separate devices for the speaker and the ringer, so one can work while the other is silent.",
        "quick": "Play a tone on the <a href=\"/speaker-test\">free speaker test</a>. If you hear it, your speakers work and the fix is in Webex (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Pick the speaker in Webex.", "Click Settings in the sidebar, then Audio, and choose your speaker. Raise its volume there too."),
            ("Test it.", "Click Test next to Speaker. In a meeting, use Audio options › Audio Settings."),
            ("Check the ringer.", "Webex has its own ringer device. If calls don't ring but meetings play fine, set the ringer to the speaker you're near."),
        ],
        "extra": [
            ("Webex in a browser", "Webex's help says to check that your browser tab isn't muted, and that speakers or headphones are connected and on."),
        ],
        "faqs": [
            ("Why can't I hear anyone in Webex?", "Open Settings › Audio, pick the speaker you're listening on, and click Test. Then check your Mac's volume."),
            ("What is the ringer setting in Webex?", "It's the device Webex rings on for incoming calls. It can be different from your meeting speaker."),
            ("Webex is silent in my browser. Why?", "The tab may be muted. Unmute the site in your browser and check Webex's speaker setting."),
        ],
    },
    # ---------------------------------------------------------------- OBS
    {
        "slug": "obs-camera-not-working", "app": "obs", "device": "camera",
        "title": "OBS Camera Not Working on Mac? Fix the Black Screen",
        "h1": "OBS camera not working?", "em": "Fix the black screen.",
        "desc": "OBS Video Capture Device black or empty on your Mac? Allow OBS under Privacy & Security › Camera, pick the device in the source's properties, and check the scene.",
        "lede": "On a Mac, OBS needs the Camera permission before a Video Capture Device shows anything. After that, it's the source's own settings.",
        "quick": "Open the <a href=\"/webcam-test\">free webcam test</a>. If you see yourself there, the camera works and the fix is in OBS (steps 1 to 3). If not, start with the Mac checks.",
        "steps": [
            ("Add the camera as a source.", "In the Sources box, click +, choose Video Capture Device, and pick your camera from the Device menu in its properties."),
            ("Check the source is visible.", "Make sure the eye icon next to the source is on, and that the source is in the scene you're looking at."),
            ("Check the camera's format.", "If you set a resolution or frame rate the camera or capture card can't do, the source can stay black. Go back to the camera's default in the source properties."),
        ],
        "extra": [
            ("The permission prompt never showed up", "If you dismissed the first prompt, macOS may not ask again. Turn on OBS by hand in Privacy & Security › Camera, then quit and reopen OBS. If you started OBS from Terminal, macOS may have given the permission to Terminal instead."),
            ("OBS Virtual Camera in other apps", "OBS can also show up as a camera in Zoom or Meet. That's OBS's output, not your webcam, and it's black until you start the virtual camera in OBS."),
        ],
        "faqs": [
            ("Why is my OBS Video Capture Device black on a Mac?", "OBS likely doesn't have camera access. Turn on OBS in System Settings › Privacy & Security › Camera, quit OBS fully, and open it again."),
            ("Why doesn't OBS list my camera?", "Check it's connected and the Mac sees it in System Information › Camera. Then remove and add the Video Capture Device source again."),
            ("Why does Zoom show OBS as a camera?", "That's OBS Virtual Camera. It sends OBS's output to other apps and only works while you start it in OBS."),
        ],
    },
    {
        "slug": "obs-mic-not-working", "app": "obs", "device": "microphone",
        "title": "OBS Mic Not Working on Mac? Get Your Voice in the Mix",
        "h1": "OBS mic not working?", "em": "Get your voice in the mix.",
        "desc": "OBS mic not picking up on your Mac? Allow OBS under Privacy & Security › Microphone, set Mic/Auxiliary Audio, unmute it in the Audio Mixer, and check monitoring.",
        "lede": "OBS only records a mic it's been given, has permission for, and isn't muted in the mixer. Check all three.",
        "quick": "Try the <a href=\"/mic-test\">free mic test</a>. If the meter moves, your mic works and the fix is in OBS (steps 1 to 4). If not, start with the Mac checks.",
        "steps": [
            ("Set the mic in OBS.", "Open Settings › Audio. Under Global Audio Devices, set Mic/Auxiliary Audio to your mic. Or add an Audio Input Capture source to a scene instead, but not both for the same mic."),
            ("Unmute it in the Audio Mixer.", "Find your mic in the Audio Mixer. If the speaker icon is crossed out, click it. Talk and watch the meter move."),
            ("Raise the fader.", "A fader pulled all the way down sends nothing. Drag it up until your voice peaks well below the red."),
            ("Hear yourself, if you need to.", "OBS doesn't play your mic back by default. To listen, open Edit › Advanced Audio Properties and set Audio Monitoring for the mic to Monitor and Output."),
        ],
        "extra": [
            ("Mic shows up but is silent", "If the mixer shows the mic with no movement at all, the Mac permission is the usual cause. Turn on OBS under Privacy & Security › Microphone and restart OBS."),
            ("Desktop audio is a separate job", "Capturing your Mac's own sound in OBS is a different setup from your mic. This page covers the mic only."),
        ],
        "faqs": [
            ("Why isn't OBS picking up my mic on a Mac?", "Turn on OBS under System Settings › Privacy & Security › Microphone, restart OBS, then set Mic/Auxiliary Audio in Settings › Audio."),
            ("Why can't I hear my mic in OBS?", "OBS doesn't monitor your mic unless you ask. Set Audio Monitoring to Monitor and Output in Edit › Advanced Audio Properties."),
            ("Should I use Mic/Auxiliary Audio or Audio Input Capture?", "Either works. Use one, not both, for the same mic, or you'll record it twice."),
        ],
    },
]
