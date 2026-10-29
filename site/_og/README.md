# Link preview video

Remotion source for `images/og.mp4` (the `og:video` iMessage and Discord autoplay) and `images/og-video.png` (the `og:image` still, frame 225 of the 6-second, 60 fps loop). Needs Node and ffmpeg.

```sh
cd site/_og && npm install && npm run render
```

`npm run studio` opens a live preview. `OgVideo.tsx` is the shared shell (color field, glass card, brand, headline) and takes its text and colors as props in `Root.tsx`; `ChecklistCard.tsx` is the Green Room pre-call checklist on the right. The loop ends on its first frame, so keep the first and last frames identical when changing the timing.

This folder is in `.vercelignore`, so none of it is deployed.
