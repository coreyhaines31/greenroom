// In-browser device tests for the mic, webcam, and speaker pages.
// Everything runs locally: no audio or video ever leaves the page.
(() => {
  const $ = (id) => document.getElementById(id);
  const media = navigator.mediaDevices;
  const AudioCtx = window.AudioContext || window.webkitAudioContext;

  function setVerdict(el, state, title, detail) {
    el.dataset.state = state;
    el.innerHTML = "";
    const b = document.createElement("b");
    b.textContent = title;
    const span = document.createElement("span");
    span.textContent = detail;
    const wrap = document.createElement("div");
    wrap.append(b, span);
    el.append(wrap);
  }

  // Explain a getUserMedia failure in plain words.
  function permissionHelp(error, kind) {
    const thing = kind === "audio" ? "microphone" : "camera";
    const pane = kind === "audio" ? "Microphone" : "Camera";
    switch (error && error.name) {
      case "NotAllowedError":
      case "SecurityError":
        return [`Your browser isn't allowed to use the ${thing}`, `Allow it for this site (the icon in the address bar), then check System Settings › Privacy & Security › ${pane} and make sure your browser is turned on there.`];
      case "NotFoundError":
      case "OverconstrainedError":
        return [`No ${thing} found`, `Your Mac doesn't see one right now. If it's external, unplug it, plug it back in, and try another port.`];
      case "NotReadableError":
      case "AbortError":
        return [`The ${thing} couldn't start`, `Another app may be holding it, or macOS blocked your browser. Quit apps that use the ${thing}, then try again.`];
      default:
        return [`The ${thing} test couldn't start`, error && error.message ? error.message : "Try reloading the page."];
    }
  }

  function unsupported(verdict, kind) {
    if (media && media.getUserMedia && window.isSecureContext !== false) return false;
    setVerdict(verdict, "bad", "This browser can't run the test", `It doesn't give web pages access to the ${kind}. Try a current version of Safari, Chrome, or Firefox.`);
    return true;
  }

  // Fill a <select> with devices of one kind. Labels only appear after permission.
  async function fillDevices(select, kind, currentId, fallback) {
    const devices = (await media.enumerateDevices()).filter((d) => d.kind === kind && d.deviceId !== "communications");
    select.innerHTML = "";
    devices.forEach((d, i) => {
      const option = document.createElement("option");
      option.value = d.deviceId;
      option.textContent = d.label || `${fallback} ${i + 1}`;
      select.append(option);
    });
    if (!devices.length) {
      const option = document.createElement("option");
      option.textContent = `No ${fallback.toLowerCase()} found`;
      select.append(option);
    }
    if (currentId && devices.some((d) => d.deviceId === currentId)) select.value = currentId;
    return devices;
  }

  const stopStream = (stream) => stream && stream.getTracks().forEach((t) => t.stop());

  // ---------- Microphone test ----------
  function micTest() {
    const ui = {
      start: $("mic-start"), select: $("mic-device"), level: $("mic-level"), peakMark: $("mic-peak-mark"),
      now: $("mic-now"), peak: $("mic-peak"), verdict: $("mic-verdict"),
      record: $("mic-record"), countdown: $("mic-countdown"), audio: $("mic-playback"), recordNote: $("mic-record-note"),
    };
    if (!ui.start) return;
    if (unsupported(ui.verdict, "microphone")) { ui.start.disabled = true; return; }

    const FLOOR = -70; // dBFS shown as an empty meter
    let stream = null, ctx = null, source = null, analyser = null, raf = 0;
    let peakDb = -Infinity, peakAt = 0, startedAt = 0, loudest = -Infinity, history = [], shown = -Infinity;

    const toDb = (x) => (x > 0 ? Math.min(0, 20 * Math.log10(x)) : -Infinity);
    const pct = (db) => Math.max(0, Math.min(100, ((db - FLOOR) / -FLOOR) * 100));
    const fmt = (db) => (db === -Infinity || db < -99 ? "silent" : `${Math.round(db)} dB`);

    async function start(deviceId) {
      stopStream(stream);
      cancelAnimationFrame(raf);
      try {
        stream = await media.getUserMedia({
          audio: {
            deviceId: deviceId ? { exact: deviceId } : undefined,
            echoCancellation: false, noiseSuppression: false, autoGainControl: false,
          },
        });
      } catch (error) {
        const [title, detail] = permissionHelp(error, "audio");
        setVerdict(ui.verdict, "bad", title, detail);
        return;
      }
      const track = stream.getAudioTracks()[0];
      const settings = track.getSettings ? track.getSettings() : {};
      await fillDevices(ui.select, "audioinput", settings.deviceId || deviceId, "Microphone");
      ui.select.disabled = false;
      ui.start.textContent = "Restart";
      ui.record.disabled = !window.MediaRecorder;
      if (!window.MediaRecorder) ui.recordNote.textContent = "This browser can't record audio. Try a current version of Safari, Chrome, or Firefox.";

      ctx = ctx || new AudioCtx();
      if (ctx.state === "suspended") await ctx.resume();
      if (source) source.disconnect();
      source = ctx.createMediaStreamSource(stream);
      analyser = ctx.createAnalyser();
      analyser.fftSize = 2048;
      source.connect(analyser);

      peakDb = -Infinity; loudest = -Infinity; history = []; startedAt = performance.now();
      setVerdict(ui.verdict, "idle", "Listening…", "Say a few words at your normal volume.");
      track.addEventListener("ended", () => setVerdict(ui.verdict, "bad", "The microphone stopped", "It may have been unplugged. Pick it again or try another one."));
      loop();
    }

    const buf = new Float32Array(2048);
    function loop() {
      raf = requestAnimationFrame(loop);
      if (analyser.getFloatTimeDomainData) analyser.getFloatTimeDomainData(buf);
      else {
        const bytes = new Uint8Array(2048);
        analyser.getByteTimeDomainData(bytes);
        for (let i = 0; i < bytes.length; i++) buf[i] = (bytes[i] - 128) / 128;
      }
      let sum = 0, max = 0;
      for (let i = 0; i < buf.length; i++) { sum += buf[i] * buf[i]; max = Math.max(max, Math.abs(buf[i])); }
      const rms = toDb(Math.sqrt(sum / buf.length));
      const sample = toDb(max);
      const now = performance.now();

      if (sample > peakDb || now - peakAt > 2500) { peakDb = sample; peakAt = now; }
      loudest = Math.max(loudest, rms);
      history.push({ t: now, rms, peak: sample });
      while (history.length && now - history[0].t > 5000) history.shift();

      shown = Math.max(rms, shown - 1.2); // fall back gently, like a hardware meter
      ui.level.firstElementChild.style.width = `${pct(shown)}%`;
      ui.level.classList.toggle("hot", sample > -1);
      ui.peakMark.style.left = `calc(${pct(peakDb)}% - 3px)`;
      ui.peakMark.style.opacity = peakDb > FLOOR ? 1 : 0;
      ui.now.textContent = fmt(shown);
      ui.peak.textContent = fmt(peakDb);

      if (now - startedAt > 2500) judge();
    }

    function judge() {
      const recentLoud = Math.max(...history.map((h) => h.rms));
      const clipped = history.filter((h) => h.peak > -0.5).length;
      if (loudest < -75) {
        setVerdict(ui.verdict, "bad", "No sound is coming in", "The mic is connected but sends silence. Check its mute button or gain knob, and the input volume in System Settings › Sound › Input.");
      } else if (recentLoud < -60) {
        setVerdict(ui.verdict, "warn", "Very quiet", "Only a trace of sound is getting through. Speak up, move closer, turn up the mic's gain, or check its mute button.");
      } else if (clipped > 8) {
        setVerdict(ui.verdict, "warn", "Too loud", "Your voice is hitting the top and will sound distorted. Turn the gain or input volume down a little.");
      } else if (recentLoud < -45) {
        setVerdict(ui.verdict, "warn", "A little quiet", "It works, but others may need to turn you up. Move closer or raise the gain.");
      } else {
        setVerdict(ui.verdict, "ok", "Your mic works", "Sound is coming in at a good level. Record 5 seconds below to hear how you sound.");
      }
    }

    function pickMime() {
      const types = ["audio/webm;codecs=opus", "audio/mp4", "audio/ogg;codecs=opus", "audio/webm"];
      return types.find((t) => MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(t)) || "";
    }

    function record() {
      if (!stream || !window.MediaRecorder) return;
      const mimeType = pickMime();
      const recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined);
      const chunks = [];
      recorder.ondataavailable = (e) => e.data && e.data.size && chunks.push(e.data);
      recorder.onstop = () => {
        const blob = new Blob(chunks, { type: recorder.mimeType || mimeType || "audio/webm" });
        if (ui.audio.src) URL.revokeObjectURL(ui.audio.src);
        ui.audio.src = URL.createObjectURL(blob);
        ui.audio.hidden = false;
        ui.audio.dataset.bytes = blob.size;
        ui.countdown.textContent = "Playing back";
        ui.audio.play().catch(() => (ui.countdown.textContent = "Press play to hear it"));
        ui.record.disabled = false;
      };
      ui.record.disabled = true;
      ui.audio.pause();
      recorder.start();
      let left = 5;
      ui.countdown.textContent = `Recording… ${left}`;
      const tick = setInterval(() => {
        left -= 1;
        if (left > 0) ui.countdown.textContent = `Recording… ${left}`;
        else { clearInterval(tick); recorder.stop(); }
      }, 1000);
    }

    ui.audio.addEventListener("ended", () => (ui.countdown.textContent = "Done. Record again any time."));
    ui.start.addEventListener("click", () => start(ui.select.disabled ? undefined : ui.select.value));
    ui.select.addEventListener("change", () => start(ui.select.value));
    ui.record.addEventListener("click", record);
    media.addEventListener && media.addEventListener("devicechange", () => {
      if (stream) fillDevices(ui.select, "audioinput", ui.select.value, "Microphone");
    });
  }

  // ---------- Webcam test ----------
  function camTest() {
    const ui = {
      start: $("cam-start"), select: $("cam-device"), video: $("cam-video"), preview: $("cam-preview"), empty: $("cam-empty"),
      flip: $("cam-flip"), res: $("cam-res"), resNote: $("cam-res-note"), fps: $("cam-fps"), fpsNote: $("cam-fps-note"),
      light: $("cam-light"), verdict: $("cam-verdict"), faceRow: $("cam-face-row"), face: $("cam-face"),
    };
    if (!ui.start) return;
    if (unsupported(ui.verdict, "camera")) { ui.start.disabled = true; return; }

    let stream = null, timer = 0, faceTimer = 0, run = 0;
    const canvas = document.createElement("canvas");
    canvas.width = 64; canvas.height = 36;
    const g = canvas.getContext("2d", { willReadFrequently: true });
    const detector = "FaceDetector" in window ? (() => { try { return new window.FaceDetector({ fastMode: true, maxDetectedFaces: 1 }); } catch { return null; } })() : null;

    ui.flip.addEventListener("change", () => ui.preview.classList.toggle("flip", ui.flip.checked));

    async function start(deviceId) {
      stopStream(stream);
      clearInterval(timer); clearInterval(faceTimer);
      const myRun = ++run;
      try {
        stream = await media.getUserMedia({
          audio: false,
          video: {
            deviceId: deviceId ? { exact: deviceId } : undefined,
            width: { ideal: 1920 }, height: { ideal: 1080 }, frameRate: { ideal: 30 },
          },
        });
      } catch (error) {
        const [title, detail] = permissionHelp(error, "video");
        setVerdict(ui.verdict, "bad", title, detail);
        return;
      }
      const track = stream.getVideoTracks()[0];
      ui.video.srcObject = stream;
      await ui.video.play().catch(() => {});
      ui.empty.hidden = true;
      const settings = track.getSettings ? track.getSettings() : {};
      await fillDevices(ui.select, "videoinput", settings.deviceId || deviceId, "Camera");
      ui.select.disabled = false;
      ui.start.textContent = "Restart";
      setVerdict(ui.verdict, "idle", "Checking the picture…", "Hold still for a second.");
      track.addEventListener("ended", () => setVerdict(ui.verdict, "bad", "The camera stopped", "It may have been unplugged, or another app took it. Pick it again or try another one."));

      showResolution(track);
      measureFps(track, myRun);
      timer = setInterval(() => checkLight(track), 700);
      if (detector) { ui.faceRow.hidden = false; faceTimer = setInterval(checkFace, 1000); }
    }

    function showResolution(track) {
      const s = track.getSettings ? track.getSettings() : {};
      const w = s.width || ui.video.videoWidth, h = s.height || ui.video.videoHeight;
      ui.res.textContent = w && h ? `${w}×${h}` : "Unknown";
      ui.res.dataset.width = w || 0; ui.res.dataset.height = h || 0;
      const caps = track.getCapabilities ? track.getCapabilities() : null;
      if (caps && caps.width && caps.height && caps.width.max && caps.height.max) ui.resNote.textContent = `Can do up to ${caps.width.max}×${caps.height.max}`;
      else ui.resNote.textContent = h >= 1080 ? "Full HD" : h >= 720 ? "HD" : "Below HD";
    }

    function measureFps(track, myRun) {
      const reported = track.getSettings ? track.getSettings().frameRate : null;
      if (reported) ui.fpsNote.textContent = `Camera reports ${Math.round(reported)}`;
      if (!ui.video.requestVideoFrameCallback) {
        ui.fps.textContent = reported ? `${Math.round(reported)} fps` : "Unknown";
        return;
      }
      let frames = 0, first = 0;
      const onFrame = (now) => {
        if (myRun !== run) return;
        if (!first) first = now;
        frames += 1;
        if (now - first >= 2000) {
          const fps = ((frames - 1) * 1000) / (now - first);
          ui.fps.textContent = `${Math.round(fps)} fps`;
          ui.fps.dataset.value = fps.toFixed(1);
          frames = 0; first = 0;
        }
        ui.video.requestVideoFrameCallback(onFrame);
      };
      ui.video.requestVideoFrameCallback(onFrame);
    }

    function checkLight(track) {
      if (ui.video.readyState < 2) return;
      showResolution(track);
      g.drawImage(ui.video, 0, 0, canvas.width, canvas.height);
      const { data } = g.getImageData(0, 0, canvas.width, canvas.height);
      let sum = 0, sq = 0, center = 0, cn = 0, edge = 0, en = 0;
      for (let y = 0; y < canvas.height; y++) {
        for (let x = 0; x < canvas.width; x++) {
          const i = (y * canvas.width + x) * 4;
          const l = 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2];
          sum += l; sq += l * l;
          const inCenter = x > canvas.width / 3 && x < (canvas.width * 2) / 3 && y > canvas.height / 4 && y < (canvas.height * 3) / 4;
          if (inCenter) { center += l; cn++; } else { edge += l; en++; }
        }
      }
      const n = canvas.width * canvas.height;
      const mean = sum / n;
      const sd = Math.sqrt(Math.max(0, sq / n - mean * mean));
      center /= cn; edge /= en;
      ui.light.textContent = `${Math.round((mean / 255) * 100)}%`;
      ui.light.dataset.mean = mean.toFixed(1);

      const h = Number(ui.res.dataset.height);
      if (mean < 10 && sd < 6) {
        setVerdict(ui.verdict, "bad", "Lens covered?", "The picture is almost black. Check for a privacy cover or shutter, or something over the lens.");
      } else if (mean < 45) {
        setVerdict(ui.verdict, "warn", "Too dark", "Others will see a dim, grainy picture. Turn on a light in front of you, or face a window.");
      } else if (edge > 120 && center < edge - 40) {
        setVerdict(ui.verdict, "warn", "You look backlit", "The light behind you is brighter than you are, so your face goes dark. Face the window or a lamp instead.");
      } else if (mean > 225) {
        setVerdict(ui.verdict, "warn", "Very bright", "The picture is washed out. Move out of direct light or away from a bright window.");
      } else if (h && h < 720) {
        setVerdict(ui.verdict, "warn", "Your camera works, at low resolution", `It's sending ${ui.res.textContent}. Check the camera's own settings, or try another camera or port.`);
      } else {
        setVerdict(ui.verdict, "ok", "Your camera works", `The picture is coming through at ${ui.res.textContent} with good light.`);
      }
    }

    async function checkFace() {
      if (ui.video.readyState < 2) return;
      try {
        const faces = await detector.detect(ui.video);
        if (!faces.length) { ui.face.textContent = "No face found. Move into the frame."; return; }
        const box = faces[0].boundingBox;
        const vw = ui.video.videoWidth, vh = ui.video.videoHeight;
        let cx = (box.x + box.width / 2) / vw;
        if (ui.flip.checked) cx = 1 - cx;
        const top = box.y / vh, cy = (box.y + box.height / 2) / vh;
        if (cx < 0.38) ui.face.textContent = "You're left of center in the preview.";
        else if (cx > 0.62) ui.face.textContent = "You're right of center in the preview.";
        else if (top < 0.05) ui.face.textContent = "Your head is at the top edge. Tilt the camera up a little or sit lower.";
        else if (cy > 0.6) ui.face.textContent = "You're low in the frame. Raise the camera to eye level.";
        else ui.face.textContent = "Nicely centered.";
      } catch {
        ui.faceRow.hidden = true;
        clearInterval(faceTimer);
      }
    }

    ui.start.addEventListener("click", () => start(ui.select.disabled ? undefined : ui.select.value));
    ui.select.addEventListener("change", () => start(ui.select.value));
    media.addEventListener && media.addEventListener("devicechange", () => {
      if (stream) fillDevices(ui.select, "videoinput", ui.select.value, "Camera");
    });
  }

  micTest();
  camTest();
})();
