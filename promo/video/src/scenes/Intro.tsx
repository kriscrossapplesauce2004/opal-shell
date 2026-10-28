import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame} from 'remotion';
import {Backdrop, Kinetic, Morph} from '../components';
import {BAR, BEAT, C, FONT, emphasized} from '../theme';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

// Bars 1-4: one shape breathing in the dark, two lines of type, then the wordmark on the riser.
export const Intro: React.FC = () => {
  const f = useCurrentFrame();
  const shapeIn = emphasized(interpolate(f, [6, 50], [0, 1], clamp));
  const shapeX = interpolate(f, [0, 2 * BAR, 2 * BAR + 30], [960, 960, 960], clamp);
  const shapeSize = interpolate(f, [0, 2 * BAR, 2 * BAR + 40, 4 * BAR], [0, 300, 520, 640], {...clamp, easing: emphasized}) * shapeIn;
  const markIn = 2 * BAR + 24;
  const mark = emphasized(interpolate(f, [markIn, markIn + 40], [0, 1], clamp));
  const wght = interpolate(f, [markIn, markIn + 70, 4 * BAR - 20], [120, 820, 900], clamp);
  const wdth = interpolate(f, [markIn, markIn + 70], [62, 112], clamp);
  const out = interpolate(f, [4 * BAR - 14, 4 * BAR], [1, 0], clamp);
  return (
    <AbsoluteFill style={{opacity: out}}>
      <Backdrop pulse={f > 2 * BAR ? 1 : 0.3} />
      <Morph size={shapeSize} x={shapeX} y={540} beatKick={0.05} spin={0.2} opacity={f < 2 * BAR + 20 ? 0.95 : 0.22}
        keys={[{at: 0, shape: 'circle'}, {at: BEAT * 2, shape: 'cookie4'}, {at: BEAT * 4, shape: 'cookie9'}, {at: BEAT * 6, shape: 'clover'},
          {at: BEAT * 8, shape: 'burst'}, {at: BEAT * 10, shape: 'flower'}, {at: BEAT * 12, shape: 'sunny'}, {at: BEAT * 14, shape: 'pill'},
          {at: BEAT * 16, shape: 'cookie6'}, {at: BEAT * 20, shape: 'flower'}, {at: BEAT * 24, shape: 'clover'}, {at: BEAT * 28, shape: 'cookie9'}]} />
      {f < BAR + 10 && <Kinetic text="One shell." start={34} size={96} y={830} exit={BAR - 6} weight={[200, 640]} />}
      {f >= BAR - 6 && f < 2 * BAR + 10 && <Kinetic text="Every screen." start={BAR + 4} size={96} y={830} exit={2 * BAR - 4} weight={[200, 640]} />}
      {f >= markIn && (
        <div style={{position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center'}}>
          <div style={{fontFamily: FONT, fontSize: 300, color: C.text, letterSpacing: '-0.05em', lineHeight: 1,
            fontVariationSettings: `'wght' ${wght}, 'wdth' ${wdth}, 'ROND' 100, 'opsz' 144`,
            transform: `scale(${0.86 + 0.14 * mark})`, opacity: mark, filter: `blur(${(1 - mark) * 16}px)`}}>Opal</div>
          <div style={{marginTop: 18, fontFamily: FONT, fontSize: 38, color: C.dim, fontVariationSettings: "'wght' 420, 'ROND' 100",
            opacity: emphasized(interpolate(f, [markIn + 40, markIn + 70], [0, 1], clamp)), letterSpacing: '0.01em'}}>
            A Material 3 Expressive shell for Linux
          </div>
        </div>
      )}
    </AbsoluteFill>
  );
};
