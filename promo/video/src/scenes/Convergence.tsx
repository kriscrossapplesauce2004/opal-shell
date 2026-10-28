import React from 'react';
import {AbsoluteFill, interpolate, Sequence, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {Backdrop, Chip, Device, Footage, Kinetic, Screen} from '../components';
import {BAR, BEAT, C, emphasized} from '../theme';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const PHONE = {w: 1236, h: 2748};
const TABLET = {w: 2560, h: 1600};
const DESK = {w: 3840, h: 2160};

// A device that springs in from below and drifts slowly while it plays.
const Floating: React.FC<{children: React.ReactNode; x: number; y: number; scale: number; tilt?: number; delay?: number}> = ({children, x, y, scale, tilt = 0, delay = 0}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: f - delay, fps, config: {damping: 18, stiffness: 110}});
  return (
    <div style={{position: 'absolute', inset: 0, transform: `translateY(${(1 - s) * 500 + Math.sin(f / 50) * 6}px) rotate(${tilt * (1 - s) + Math.sin(f / 90) * 0.6}deg)`, opacity: s}}>
      <div style={{position: 'absolute', left: x, top: y, transform: `scale(${scale})`}}>{children}</div>
    </div>
  );
};

const PhoneShot: React.FC<{clip: string; from: number; x?: number; scale?: number; delay?: number; tilt?: number}> = ({clip, from, x = 960, scale = 1, delay = 0, tilt = 8}) => (
  <Floating x={x} y={540} scale={scale} delay={delay} tilt={tilt}>
    <Device kind="phone" w={392} h={872} x={0} y={0}>
      <Screen src={clip} from={from} w={392} h={872} srcW={PHONE.w} srcH={PHONE.h} />
    </Device>
  </Floating>
);

const TabletShot: React.FC<{clip: string; from: number; x?: number; scale?: number; delay?: number}> = ({clip, from, x = 960, scale = 1, delay = 0}) => (
  <Floating x={x} y={530} scale={scale} delay={delay} tilt={-6}>
    <Device kind="tablet" w={1280} h={800} x={0} y={0}>
      <Screen src={clip} from={from} w={1280} h={800} srcW={TABLET.w} srcH={TABLET.h} />
    </Device>
  </Floating>
);

const MonitorShot: React.FC<{clip: string; from: number; x?: number; scale?: number; delay?: number}> = ({clip, from, x = 960, scale = 1, delay = 0}) => (
  <Floating x={x} y={500} scale={scale} delay={delay} tilt={4}>
    <Device kind="monitor" w={1280} h={720} x={0} y={0}>
      <Screen src={clip} from={from} w={1280} h={720} srcW={DESK.w} srcH={DESK.h} />
    </Device>
  </Floating>
);

export const Convergence: React.FC = () => {
  const f = useCurrentFrame();
  const consoleStart = 8 * BAR;
  return (
    <AbsoluteFill>
      {f < consoleStart && <Backdrop hue={C.primary} hue2={C.blue} />}
      {/* Bars 19-20: tablet. */}
      <Sequence from={0} durationInFrames={2 * BAR}>
        <TabletShot clip="t01-home.mp4" from={1.0} scale={1.08} />
        <Chip icon="tablet" label="Tablet: widgets and a real launcher" start={BEAT} x={960} y={1010} scale={1.05} exit={2 * BAR - 12} />
      </Sequence>
      {/* Bars 21-22: phone home pages. */}
      <Sequence from={2 * BAR} durationInFrames={2 * BAR}>
        <PhoneShot clip="p01-home.mp4" from={1.0} scale={1.0} />
        <Chip icon="smartphone" label="Phone home" start={BEAT} x={500} y={420} />
        <Chip icon="widgets" label="Widgets that work" start={BEAT * 2} x={1430} y={560} />
        <Chip icon="swipe" label="Pages and folders" start={BEAT * 3} x={520} y={700} exit={2 * BAR - 12} />
      </Sequence>
      {/* Bar 23: shade. Bar 24: recents. */}
      <Sequence from={4 * BAR} durationInFrames={BAR}>
        <PhoneShot clip="p02-shade.mp4" from={0.9} x={1180} tilt={0} />
        <Kinetic text="Same Quick Settings." start={6} size={84} x={180} y={540} align="left" weight={[240, 760]} exit={BAR - 14} />
      </Sequence>
      <Sequence from={5 * BAR} durationInFrames={BAR}>
        <PhoneShot clip="p03-apps.mp4" from={4.6} x={740} tilt={0} />
        <Kinetic text="Same apps." start={6} size={84} x={1080} y={540} align="left" weight={[240, 760]} exit={BAR - 14} />
      </Sequence>
      {/* Bars 25-26: all three at once. */}
      <Sequence from={6 * BAR} durationInFrames={2 * BAR}>
        <MonitorShot clip="d01-apps.mp4" from={8.0} x={560} scale={0.62} />
        <TabletShot clip="t02-app.mp4" from={2.6} x={1240} scale={0.5} delay={BEAT} />
        <PhoneShot clip="p01-home.mp4" from={3.5} x={1640} scale={0.6} delay={BEAT * 2} />
        <Kinetic text="One shell. Every screen." start={BEAT * 3} size={92} y={960} weight={[220, 820]} exit={2 * BAR - 14} />
      </Sequence>
      {/* Bars 27-32: console. */}
      <Sequence from={consoleStart} durationInFrames={3 * BAR}>
        <Footage src="g01-home.mp4" from={1.0} radius={0} shadow={false} cams={[{f: 0, s: 1.25, x: 0.42, y: 0.35}, {f: 3 * BAR, s: 1.05, x: 0.5, y: 0.5}]} />
        <ConsoleTitle />
      </Sequence>
      <Sequence from={consoleStart + 3 * BAR} durationInFrames={3 * BAR}>
        <Footage src="g02-quickaccess.mp4" from={1.0} radius={0} shadow={false} cams={[{f: 0, s: 1.15, x: 0.75, y: 0.5}, {f: 3 * BAR, s: 1.3, x: 0.8, y: 0.5}]} />
        <Chip icon="sports_esports" label="Quick Access, over any game" start={BEAT} x={640} y={980} scale={1.1} exit={3 * BAR - 12} />
      </Sequence>
    </AbsoluteFill>
  );
};

const ConsoleTitle: React.FC = () => {
  const f = useCurrentFrame();
  const o = emphasized(interpolate(f, [0, 20], [0, 1], clamp));
  return (
    <>
      <AbsoluteFill style={{background: 'linear-gradient(90deg, rgba(5,7,15,0.7) 0%, transparent 45%)', opacity: o}} />
      <Kinetic text="Game mode." start={BEAT} size={130} x={120} y={470} align="left" weight={[220, 880]} exit={3 * BAR - 16} />
      <Kinetic text="Your whole library, one controller." start={BEAT * 3} size={46} x={124} y={580} align="left" weight={[300, 560]} color={C.dim} exit={3 * BAR - 16} />
    </>
  );
};
