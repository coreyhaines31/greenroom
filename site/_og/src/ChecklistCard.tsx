import {Easing, interpolate, interpolateColors, useCurrentFrame, useVideoConfig} from 'remotion';
import {DISPLAY, INK, MUTED} from './OgVideo';

const GO = '#2f9e4f';

// Green Room's pre-call check, as a Brushed popover card: each row switches to the usual device and its light goes green, "Ready for your call" lands,
// then every row eases back to where it starts, so the loop has no seam.
const ROWS = [
  {label: 'Camera', from: 'FaceTime HD', to: 'Studio Display'},
  {label: 'Microphone', from: 'AirPods Pro', to: 'Shure MV7'},
  {label: 'Speakers', from: 'Studio Display', to: 'Studio Display'},
  {label: 'Recording disk', from: 'Checking…', to: '212 GB free'},
];
const FIRST = 0.5;
const GAP = 0.5;
const RESET = 4.6;
const RESET_GAP = 0.06;

const STANDARD = Easing.bezier(0.4, 0, 0.2, 1);
const IN_OUT = Easing.bezier(0.65, 0, 0.35, 1);
const OUT_EASE = Easing.bezier(0, 0, 0.2, 1);
const NEUTRAL = '#b4b6b6';

export const ChecklistCard = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = frame / fps;
  const ease = (input: number[], output: number[], easing: (n: number) => number) =>
    interpolate(t, input, output, {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing});

  // 0.5–2.4s rows resolve · 2.7–3.05s verdict in · hold to 4.5s · 4.5–4.68s verdict out · 4.6–5.8s rows reset
  // Text swaps overlap only briefly, so two lines never sit on top of each other at half opacity.
  const verdictIn = ease([2.8, 3.05], [0, 1], OUT_EASE);
  const shown = verdictIn * ease([4.5, 4.68], [1, 0], STANDARD);
  const checking = 1 - ease([2.7, 2.88], [0, 1], STANDARD) + ease([4.62, 4.82], [0, 1], STANDARD);

  return (
    <div
      style={{width: '100%', height: '100%', boxSizing: 'border-box', padding: '22px 26px', borderRadius: 12, background: '#eeeeed',
        boxShadow: '0 18px 40px rgba(0,0,0,0.32), 0 2px 6px rgba(0,0,0,0.14), 0 0 0 0.5px rgba(0,0,0,0.35)'}}
    >
      <div style={{fontFamily: DISPLAY, fontSize: 30, fontWeight: 600, color: INK}}>Design review</div>
      <div style={{fontSize: 19, color: MUTED, marginTop: 2}}>Zoom · starts in 2 min</div>
      <div style={{marginTop: 14}}>
        {ROWS.map((row, i) => {
          const at = FIRST + i * GAP;
          const back = RESET + i * RESET_GAP;
          const swapOut = ease([at, at + 0.16], [0, 1], STANDARD);
          const swapIn = ease([at + 0.14, at + 0.38], [0, 1], OUT_EASE);
          const backOut = ease([back, back + 0.18], [0, 1], STANDARD);
          const backIn = ease([back + 0.16, back + 0.42], [0, 1], OUT_EASE);
          const fill = ease([at + 0.1, at + 0.4], [0, 1], STANDARD) * (1 - ease([back, back + 0.9], [0, 1], IN_OUT));
          const tick = ease([at + 0.2, at + 0.5], [0, 1], STANDARD) * (1 - ease([back, back + 0.5], [0, 1], IN_OUT));
          const same = row.from === row.to;
          const fromOpacity = same ? 0 : 1 - swapOut + backIn;
          const fromY = backIn > 0 ? (1 - backIn) * 8 : -6 * swapOut;
          const toOpacity = same ? 1 : swapIn - backOut;
          const toY = same ? 0 : backOut > 0 ? -6 * backOut : (1 - swapIn) * 8;
          const valueColor = interpolateColors(fill, [0, 1], [MUTED, INK]);
          return (
            <div
              key={row.label}
              style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 62,
                borderTop: i === 0 ? 'none' : '1px solid #dcdcdb'}}
            >
              <div>
                <div style={{fontFamily: DISPLAY, fontSize: 14, fontWeight: 600, letterSpacing: '0.2em', textTransform: 'uppercase', color: MUTED}}>{row.label}</div>
                <div style={{position: 'relative', height: 30, fontSize: 24, fontWeight: 600, whiteSpace: 'nowrap'}}>
                  <span style={{position: 'absolute', left: 0, top: 0, color: MUTED, opacity: fromOpacity, transform: `translateY(${fromY}px)`}}>{row.from}</span>
                  <span style={{position: 'absolute', left: 0, top: 0, color: valueColor, opacity: toOpacity, transform: `translateY(${toY}px)`}}>{row.to}</span>
                </div>
              </div>
              <svg width={36} height={36} viewBox="0 0 36 36" style={{flex: 'none'}}>
                <circle cx={18} cy={18} r={15.5} fill="none" stroke={NEUTRAL} strokeWidth={2.5} />
                <circle cx={18} cy={18} r={17 * (0.85 + 0.15 * fill)} fill={GO} opacity={fill} />
                <path d="M11 18.5 L16 23.5 L25.5 13" fill="none" stroke="#fff" strokeWidth={3.2} strokeLinecap="round" strokeLinejoin="round"
                  pathLength={1} strokeDasharray="1 1" strokeDashoffset={1 - tick} opacity={Math.min(1, tick * 4)} />
              </svg>
            </div>
          );
        })}
      </div>
      <div style={{position: 'relative', marginTop: 14, height: 46}}>
        <div style={{position: 'absolute', left: 0, top: 6, fontFamily: DISPLAY, fontSize: 32, fontWeight: 600, color: '#8c8e90', opacity: checking}}>
          Checking your setup…
        </div>
        <div style={{position: 'absolute', left: 0, top: 0, fontFamily: DISPLAY, fontSize: 40, fontWeight: 600, color: INK, whiteSpace: 'nowrap',
          display: 'flex', alignItems: 'center', gap: 12, opacity: shown, transform: `translateY(${(1 - verdictIn) * 8}px)`}}>
          <span style={{width: 12, height: 12, borderRadius: '50%', background: GO, boxShadow: `0 0 8px ${GO}`}} />
          Ready for your call
        </div>
      </div>
    </div>
  );
};
