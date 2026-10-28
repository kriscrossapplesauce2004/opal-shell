import React from 'react';
import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {Backdrop, Kinetic, Morph} from '../components';
import {BAR, BEAT, C} from '../theme';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

// Bars 17-18: the drums drop out; three screen outlines (monitor, tablet, phone) draw in on the beats under "Every screen."
export const Breakdown: React.FC = () => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const frames = [
    {w: 620, h: 360, x: 520, at: 0},
    {w: 420, h: 300, x: 1110, at: BEAT * 2},
    {w: 170, h: 340, x: 1470, at: BEAT * 4},
  ];
  return (
    <AbsoluteFill>
      <Backdrop hue={C.blue} hue2={C.primary} pulse={0.2} />
      <Morph size={interpolate(f, [0, 2 * BAR], [180, 900], clamp)} opacity={0.12} beatKick={0}
        keys={[{at: 0, shape: 'cookie9'}, {at: BAR, shape: 'flower'}, {at: BAR + BEAT * 2, shape: 'burst'}]} />
      {frames.map((d, i) => {
        const s = spring({frame: f - d.at, fps, config: {damping: 16, stiffness: 140}});
        return (
          <div key={i} style={{position: 'absolute', left: d.x - d.w / 2, top: 420 - d.h / 2, width: d.w, height: d.h,
            borderRadius: i === 2 ? 34 : i === 1 ? 26 : 16, border: `3px solid ${C.primary}`, opacity: s * 0.9,
            transform: `translateY(${(1 - s) * 60}px) scale(${0.9 + 0.1 * s})`,
            boxShadow: `0 0 60px ${C.primary}55, inset 0 0 40px ${C.primary}22`}} />
        );
      })}
      <Kinetic text="Every screen." start={BEAT * 6} size={150} y={820} weight={[180, 860]} />
    </AbsoluteFill>
  );
};
