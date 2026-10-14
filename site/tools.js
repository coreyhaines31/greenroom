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

  micTest();
})();
