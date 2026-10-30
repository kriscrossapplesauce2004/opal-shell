import React from 'react';
import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {Backdrop, Caption, Device, Kinetic, Screen, Segmented} from '../components';
import {BAR, BEAT, C} from '../theme';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

// Screen shapes the frame moves between.
const SHAPES = [
  {w: 1280, h: 720, r: 18},  // monitor
  {w: 1120, h: 700, r: 40},  // tablet
  {w: 392, h: 872, r: 58},   // phone
];

// Size of the frame at frame f, springing from shape to shape at the given frames.
function frameShape(f: number, fps: number, changes: number[]) {
  let w = SHAPES[0].w, h = SHAPES[0].h, r = SHAPES[0].r;
  changes.forEach((at, i) => {
    const s = spring({frame: f - at, fps, config: {damping: 20, stiffness: 90}});
    const a = SHAPES[i], b = SHAPES[i + 1];
    w += (b.w - a.w) * s; h += (b.h - a.h) * s; r += (b.r - a.r) * s;
  });
  return {w, h, r};
}

// Bars 17-18: the music drops out; one glowing outline reshapes from monitor to tablet to phone.
export const Breakdown: React.FC = () => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const {w, h, r} = frameShape(f, fps, [BEAT * 2, BEAT * 4]);
  const draw = interpolate(f, [0, 40], [0, 1], clamp);
  return (
    <AbsoluteFill>
      <Backdrop hue={C.blue} hue2={C.primary} pulse={0.2} />
      <div style={{position: 'absolute', left: 960 - w / 2, top: 440 - h / 2, width: w, height: h, borderRadius: r,
        border: `4px solid ${C.primary}`, opacity: draw, boxShadow: `0 0 80px ${C.primary}66, inset 0 0 60px ${C.primary}22`}} />
      <Kinetic text="Every screen." start={BEAT * 5} size={130} y={960} weight={[180, 860]} />
    </AbsoluteFill>
  );
};

// Bars 19-22: the same frame, now a real device, plays each form factor as it reshapes.
export const Morph: React.FC = () => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const changes = [BAR * 1.5, BAR * 3];
  const {w, h, r} = frameShape(f, fps, changes);
  const scale = 1 - 0.12 * spring({frame: f - changes[1], fps, config: {damping: 20, stiffness: 90}}) * 0 ;
  const fade = (at: number) => interpolate(f, [at - 4, at + 16], [0, 1], clamp);
  const desk = 1 - fade(changes[0]);
  const tab = fade(changes[0]) * (1 - fade(changes[1]));
  const phone = fade(changes[1]);
  const stand = 1 - fade(changes[0]);
  const enter = spring({frame: f, fps, config: {damping: 18, stiffness: 100}});
  const selected = f < changes[0] ? 0 : f < changes[1] ? 1 : 2;
  return (
    <AbsoluteFill>
      <Backdrop hue={C.primary} hue2={C.blue} />
      <div style={{position: 'absolute', left: 960, top: 450, transform: `translate(-50%, -50%) scale(${scale * (0.9 + 0.1 * enter)})`}}>
        <div style={{padding: 16, borderRadius: r + 16, background: 'linear-gradient(145deg, #2a2e40, #0d0f18 60%, #23273a)',
          boxShadow: '0 50px 140px rgba(0,0,0,0.6), inset 0 0 0 1.5px rgba(255,255,255,0.12)'}}>
          <div style={{width: w, height: h, borderRadius: r, overflow: 'hidden', position: 'relative', background: '#000'}}>
            {desk > 0 && <div style={{position: 'absolute', inset: 0, opacity: desk}}><Screen src="d01-apps.mp4" from={7.5} w={w} h={h} srcW={2560} srcH={1440} /></div>}
            {tab > 0 && <div style={{position: 'absolute', inset: 0, opacity: tab}}><Screen src="t01-home.mp4" from={1.0} w={w} h={h} srcW={2560} srcH={1600} /></div>}
            {phone > 0 && <div style={{position: 'absolute', inset: 0, opacity: phone}}><Screen src="p01-home.mp4" from={0.6} w={w} h={h} srcW={1236} srcH={2748} /></div>}
          </div>
        </div>
        <div style={{position: 'absolute', left: '50%', bottom: -96, transform: 'translateX(-50%)', width: 220, height: 96, opacity: stand,
          background: 'linear-gradient(#1b1e2c, #10121b)', clipPath: 'polygon(30% 0, 70% 0, 100% 100%, 0 100%)'}} />
      </div>
      <Segmented items={[['desktop_windows', 'Desktop'], ['tablet', 'Tablet'], ['smartphone', 'Phone']]} selected={selected} x={960} y={1000} start={12} />
    </AbsoluteFill>
  );
};

// A phone that rises into place, tilted.
const Phone: React.FC<{src: string; from: number; x: number; rot: number; y?: number; delay: number; scale?: number}> = ({src, from, x, rot, y = 470, delay, scale = 0.86}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: f - delay, fps, config: {damping: 17, stiffness: 95}});
  return (
    <div style={{position: 'absolute', inset: 0, transform: `translateY(${(1 - s) * 700}px) rotate(${rot * s + Math.sin((f + delay) / 60) * 0.6}deg)`, transformOrigin: `${x}px 1400px`}}>
      <Device kind="phone" w={392} h={872} x={x} y={y} scale={scale}>
        <Screen src={src} from={from} w={392} h={872} srcW={1236} srcH={2748} />
      </Device>
    </div>
  );
};

// Bars 23-24: three phones fan out, each doing something different.
export const PhoneFan: React.FC = () => (
  <AbsoluteFill>
    <Backdrop hue={C.pink} hue2={C.primary} />
    <Phone src="p02-shade.mp4" from={0.8} x={560} rot={-8} y={500} delay={0} />
    <Phone src="p03-apps.mp4" from={5.0} x={1360} rot={8} y={500} delay={10} />
    <Phone src="p01-home.mp4" from={1.4} x={960} rot={0} y={460} delay={20} scale={0.92} />
    <Caption text="Quick Settings, recents and a real launcher, in your pocket." start={40} y={985} size={42} color={C.text} maxWidth={1500} />
  </AbsoluteFill>
);
