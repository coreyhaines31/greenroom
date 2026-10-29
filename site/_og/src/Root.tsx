import {Composition} from 'remotion';
import {OgVideo, type OgVideoProps} from './OgVideo';

// 6 s at 60 fps. Frame 225 (3.75 s) is the resting frame, rendered as the og:image still.
export const RemotionRoot = () => (
  <Composition
    id="OgVideo"
    component={OgVideo}
    durationInFrames={360}
    fps={60}
    width={1200}
    height={630}
    defaultProps={
      {
        name: 'Green Room',
        icon: 'icon.png',
        headline: 'Camera, mic, speakers.',
        headlineAccent: 'Ready before you go on.',
        headlineSize: 64,
        accentWraps: true,
        sub: 'Free for macOS · greenroomformac.com',
        accent: '#1fa35f',
        accentInk: '#0f7a44',
        accentFill: '#1fa35f',
        field: ['#a8ecc0', '#d4f5c4', '#c9e6ff', '#c8f0e0'],
      } satisfies OgVideoProps
    }
  />
);
