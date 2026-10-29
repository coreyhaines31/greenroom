import {loadFont} from '@remotion/google-fonts/Inter';
import {AbsoluteFill, Img, staticFile} from 'remotion';
import {ChecklistCard} from './ChecklistCard';

// Inter stands in for SF Pro when rendering off a Mac.
loadFont('normal', {weights: ['500', '600', '700'], subsets: ['latin']});

export type OgVideoProps = {
  name: string;
  icon: string;
  headline: string;
  headlineAccent: string;
  // Longer headlines can step down from 76 px and let the accent phrase wrap.
  headlineSize?: number;
  accentWraps?: boolean;
  sub: string;
  accent: string;
  accentInk: string;
  accentFill: string;
  field: [string, string, string, string];
};

export const FONT = '-apple-system, BlinkMacSystemFont, "SF Pro Display", Inter, system-ui, sans-serif';
export const INK = '#1d1d1f';
export const INK_2 = '#636368';

// The family shell: daylight color field, one glass card, brand and headline on the left. The right slot is per site.
export const OgVideo = (props: OgVideoProps) => {
  const blobs = [
    {size: 760, left: -220, top: -260},
    {size: 640, left: 720, top: -240},
    {size: 600, left: 380, top: 250},
    {size: 520, left: 740, top: 230},
  ];
  return (
    <AbsoluteFill style={{background: '#f5f6f8', color: INK, fontFamily: FONT, letterSpacing: '-0.012em', WebkitFontSmoothing: 'antialiased'}}>
      {blobs.map((b, i) => (
        <div
          key={i}
          style={{position: 'absolute', width: b.size, height: b.size, left: b.left, top: b.top, borderRadius: '50%', opacity: 0.85,
            background: `radial-gradient(circle, ${props.field[i]}, transparent 68%)`}}
        />
      ))}
      <div
        style={{position: 'absolute', inset: '44px 52px', borderRadius: 44, background: 'rgba(255,255,255,0.58)',
          boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.9), inset 0 -1px 0 rgba(0,0,0,0.04), 0 1px 2px rgba(55,30,15,0.05), 0 14px 40px rgba(55,30,15,0.10)'}}
      />
      <div style={{position: 'absolute', left: 116, top: 92, width: 520, height: 446, display: 'flex', flexDirection: 'column', justifyContent: 'space-between'}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 18, fontSize: 34, fontWeight: 600, letterSpacing: '-0.025em'}}>
          <Img src={staticFile(props.icon)} style={{width: 76, height: 76, filter: 'drop-shadow(0 8px 16px rgba(120,50,10,0.22))'}} />
          {props.name}
        </div>
        <div style={{fontSize: props.headlineSize ?? 76, lineHeight: 1.0, fontWeight: 700, letterSpacing: '-0.045em'}}>
          {props.headline} <span style={{color: props.accent, whiteSpace: props.accentWraps ? 'normal' : 'nowrap'}}>{props.headlineAccent}</span>
        </div>
        <div style={{fontSize: 26, color: INK_2, letterSpacing: '-0.015em'}}>{props.sub}</div>
      </div>
      <div style={{position: 'absolute', left: 664, top: 92, width: 436, height: 446}}>
        <ChecklistCard accentInk={props.accentInk} accentFill={props.accentFill} />
      </div>
    </AbsoluteFill>
  );
};
