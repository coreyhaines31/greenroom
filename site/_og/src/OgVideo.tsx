import {loadFont as loadBarlow} from '@remotion/google-fonts/Barlow';
import {loadFont as loadCondensed} from '@remotion/google-fonts/BarlowSemiCondensed';
import {AbsoluteFill, Img, staticFile} from 'remotion';
import {ChecklistCard} from './ChecklistCard';

// The Brushed family fonts: Barlow for text, Barlow Semi Condensed for display and plates.
loadBarlow('normal', {weights: ['400', '500', '600'], subsets: ['latin']});
loadCondensed('normal', {weights: ['300', '600', '700'], subsets: ['latin']});

export type OgVideoProps = {
  name: string;
  icon: string;
  headline: string;
  headlineAccent: string;
  // Longer headlines can step down from 76 px and let the second phrase wrap.
  headlineSize?: number;
  accentWraps?: boolean;
  sub: string;
  // The app's pilot light. Colour appears only in lights and readings.
  accent: string;
};

export const FONT = '"Barlow", "Helvetica Neue", system-ui, sans-serif';
export const DISPLAY = '"Barlow Semi Condensed", "Helvetica Neue", system-ui, sans-serif';
export const INK = '#161616';
export const INK_2 = '#3d3f41';
export const MUTED = '#66686a';

const BRUSH = [
  'repeating-linear-gradient(0deg, rgba(255,255,255,.22) 0 1px, rgba(0,0,0,.035) 1px 2px, transparent 2px 3px)',
  'repeating-linear-gradient(0deg, rgba(0,0,0,.035) 0 1px, transparent 1px 7px)',
  'linear-gradient(100deg, rgba(255,255,255,0) 18%, rgba(255,255,255,.5) 40%, rgba(255,255,255,0) 64%)',
  'linear-gradient(180deg, #e7e8e9, #c3c5c7)',
].join(', ');

// The Brushed family shell: brushed aluminium, brand and headline on the left, the app on a black mount on the right.
export const OgVideo = (props: OgVideoProps) => (
  <AbsoluteFill style={{background: BRUSH, color: INK, fontFamily: FONT, WebkitFontSmoothing: 'antialiased'}}>
    <div style={{position: 'absolute', left: 96, top: 92, width: 540, height: 446, display: 'flex', flexDirection: 'column', justifyContent: 'space-between'}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 18, fontFamily: DISPLAY, fontSize: 36, fontWeight: 700}}>
        <Img src={staticFile(props.icon)} style={{width: 76, height: 76}} />
        {props.name}
      </div>
      <div>
        <div style={{display: 'inline-flex', alignItems: 'center', gap: 12, fontFamily: DISPLAY, fontSize: 17, fontWeight: 600, letterSpacing: '0.26em',
          textTransform: 'uppercase', background: '#1b1b1b', color: '#d8d9da', padding: '9px 14px 9px 12px', borderRadius: 3}}>
          <span style={{width: 9, height: 9, borderRadius: '50%', background: props.accent, boxShadow: `0 0 8px ${props.accent}`}} />
          Free for Mac
        </div>
        <div style={{marginTop: 20, fontFamily: DISPLAY, fontSize: props.headlineSize ?? 76, lineHeight: 0.98, fontWeight: 600}}>
          {props.headline} <span style={{display: 'block', fontWeight: 300, whiteSpace: props.accentWraps ? 'normal' : 'nowrap'}}>{props.headlineAccent}</span>
        </div>
      </div>
      <div style={{fontSize: 25, color: INK_2}}>{props.sub}</div>
    </div>
    <div style={{position: 'absolute', left: 676, top: 64, width: 460, height: 502, padding: 32, boxSizing: 'border-box', borderRadius: 12,
      background: '#1b1b1b', backgroundImage: 'radial-gradient(rgba(255,255,255,.045) 1px, transparent 1.3px)', backgroundSize: '5px 5px',
      boxShadow: '0 0 0 1px rgba(0,0,0,.5)'}}
    >
      {[[12, 12], [12, null], [null, 12], [null, null]].map(([left, top], i) => (
        <span key={i} style={{position: 'absolute', width: 10, height: 10, borderRadius: '50%',
          left: left ?? undefined, right: left === null ? 12 : undefined, top: top ?? undefined, bottom: top === null ? 12 : undefined,
          background: 'radial-gradient(circle at 40% 35%, #fff, #b9bbbd 45%, #77797b 80%)'}} />
      ))}
      <ChecklistCard />
    </div>
  </AbsoluteFill>
);
