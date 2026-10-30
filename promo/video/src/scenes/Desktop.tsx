import React from 'react';
import {AbsoluteFill, interpolate, OffthreadVideo, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {Backdrop, Caption, Chip, Crop, Keycap, Kinetic} from '../components';
import {R, Region} from '../regions';
import {BAR, BEAT, C, FONT, ICON, emphasized} from '../theme';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const SRC_W = 2560, SRC_H = 1440;

// The whole desktop on a card in 3D space.
const ScreenCard: React.FC<{src: string; from: number; width: number; rate?: number; dim?: number; children?: React.ReactNode}> = ({src, from, width, rate = 1, dim = 0, children}) => {
  const {fps} = useVideoConfig();
  const k = width / SRC_W;
  return (
    <div style={{position: 'relative', width, height: SRC_H * k, borderRadius: 22, transformStyle: 'preserve-3d'}}>
      <div style={{position: 'absolute', inset: 0, borderRadius: 22, overflow: 'hidden', boxShadow: '0 60px 160px rgba(0,0,0,0.6), 0 0 0 1.5px rgba(255,255,255,0.12)'}}>
        <OffthreadVideo src={staticFile(`clips/${src}`)} startFrom={Math.round(from * fps)} playbackRate={rate} muted style={{width: '100%', height: '100%'}} />
        <div style={{position: 'absolute', inset: 0, background: '#04060d', opacity: dim}} />
      </div>
      {children}
    </div>
  );
};

// A panel copied out of its clip at its exact place on the screen card, then lifted toward the camera.
const Lift: React.FC<{src: string; from: number; region: Region; k: number; start: number; z: number; dx?: number; dy?: number; rate?: number}> = ({src, from, region, k, start, z, dx = 0, dy = 0, rate = 1}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: f - start, fps, config: {damping: 17, stiffness: 90}});
  if (f < start - 1) return null;
  return (
    <div style={{position: 'absolute', left: region[0] * k, top: region[1] * k, transform: `translate3d(${dx * s}px, ${dy * s}px, ${z * s}px)`, opacity: Math.min(1, s * 3)}}>
      <Crop src={src} from={from} region={region} width={region[2] * k} rate={rate} radius={18}
        style={{boxShadow: `0 ${30 + 60 * s}px ${60 + 120 * s}px rgba(0,0,0,${0.3 + 0.35 * s}), 0 0 0 1.5px rgba(255,255,255,0.14)`}} />
    </div>
  );
};

// Bars 5-6: the desktop swings in from a steep angle and settles almost flat while apps tile in.
export const Hero: React.FC = () => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: f, fps, config: {damping: 22, stiffness: 55, mass: 1.2}});
  const ry = interpolate(s, [0, 1], [-38, -6]);
  const rx = interpolate(s, [0, 1], [26, 6]);
  const tz = interpolate(s, [0, 1], [-900, 0]);
  return (
    <AbsoluteFill>
      <Backdrop />
      <AbsoluteFill style={{perspective: 2200, perspectiveOrigin: '50% 40%'}}>
        <div style={{position: 'absolute', left: 960 - 700, top: 120, transformStyle: 'preserve-3d', transform: `translateZ(${tz}px) rotateX(${rx}deg) rotateY(${ry}deg)`}}>
          <ScreenCard src="d01-apps.mp4" from={1.6} width={1400} rate={1.55} />
        </div>
      </AbsoluteFill>
      <Kinetic text="Real tiling. Real apps." start={BAR - 10} size={76} y={1000} weight={[260, 760]} exit={2 * BAR - 14} />
    </AbsoluteFill>
  );
};

// Bars 7-8: the desktop tilts away and Quick Settings, Start and a live activity lift off it.
export const Exploded: React.FC = () => {
  const f = useCurrentFrame();
  const width = 1340, k = width / SRC_W;
  const ry = interpolate(f, [0, 2 * BAR], [20, -12], clamp);
  const rx = interpolate(f, [0, 2 * BAR], [14, 8], clamp);
  const dim = interpolate(f, [8, 40], [0, 0.45], clamp);
  return (
    <AbsoluteFill>
      <Backdrop hue={C.blue} hue2={C.primary} />
      <AbsoluteFill style={{perspective: 2000}}>
        <div style={{position: 'absolute', left: 960 - width / 2, top: 150, transformStyle: 'preserve-3d', transform: `rotateX(${rx}deg) rotateY(${ry}deg)`}}>
          <ScreenCard src="d01-apps.mp4" from={10.6} width={width} rate={0.25} dim={dim}>
            <Lift src="d03-quick-settings.mp4" from={2.2} region={R.quickSettings} k={k} start={12} z={340} dx={60} />
            <Lift src="d02-launcher.mp4" from={2.0} region={R.launcher} k={k} start={BEAT * 2} z={260} dx={-50} />
            <Lift src="d04-activity.mp4" from={1.6} region={R.toast} k={k} start={BEAT * 4} z={460} dx={-160} dy={-60} />
          </ScreenCard>
        </div>
      </AbsoluteFill>
      <Chip icon="tune" label="Quick Settings" start={30} x={1560} y={130} />
      <Chip icon="search" label="Start and search" start={BEAT * 2 + 20} x={330} y={130} />
      <Chip icon="bolt" label="Live activities" start={BEAT * 4 + 20} x={960} y={1010} />
    </AbsoluteFill>
  );
};

// Bars 9-10: Alt+Tab, with keycaps pressed in time with the real recording.
export const AltTab: React.FC = () => {
  // Clip d05 from 1.7 s: Alt goes down at 2.0 s and Tab at 2.12, 2.8 and 3.5 s; Alt comes up at 4.4 s.
  const at = (clipSec: number) => Math.round((clipSec - 1.7) * 60);
  const alt: [number, number][] = [[at(2.0), at(4.4)]];
  const tab: [number, number][] = [[at(2.12), at(2.2)], [at(2.8), at(2.88)], [at(3.5), at(3.58)]];
  return (
    <AbsoluteFill>
      <Backdrop hue={C.primary} hue2={C.pink} />
      <div style={{position: 'absolute', left: 960 - 590, top: 170}}>
        <Crop src="d05-switcher.mp4" from={1.7} region={R.switcher} width={1180} radius={34} />
      </div>
      <Keycap label="Alt" width={190} down={alt} x={830} y={790} delay={0} />
      <Keycap label="Tab" width={210} down={tab} x={1060} y={790} delay={6} />
      <Caption text="Hold Alt, tap Tab, let go. Every window, most recent first." start={20} y={890} size={44} color={C.text} maxWidth={1500} />
    </AbsoluteFill>
  );
};

// A bento tile: glass card with a live crop in it and a label.
const Tile: React.FC<{x: number; y: number; w: number; h: number; start: number; icon: string; label: string; children: React.ReactNode}> = ({x, y, w, h, start, icon, label, children}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: f - start, fps, config: {damping: 16, stiffness: 120}});
  const reveal = emphasized(interpolate(f, [start, start + 26], [0, 1], clamp));
  return (
    <div style={{position: 'absolute', left: x, top: y, width: w, height: h, borderRadius: 40, overflow: 'hidden',
      background: 'linear-gradient(160deg, rgba(40,45,72,0.78), rgba(20,23,40,0.82))', border: '1.5px solid rgba(255,255,255,0.10)',
      transform: `translateY(${(1 - s) * 90}px) scale(${0.9 + 0.1 * s})`, opacity: Math.min(1, s * 2),
      clipPath: `circle(${reveal * 150}% at 50% 100%)`}}>
      <div style={{position: 'absolute', inset: '28px 28px 96px 28px', display: 'flex', alignItems: 'center', justifyContent: 'center'}}>{children}</div>
      <div style={{position: 'absolute', left: 34, bottom: 30, display: 'flex', alignItems: 'center', gap: 14, fontFamily: FONT, fontSize: 38, color: C.text,
        fontVariationSettings: "'wght' 620, 'ROND' 100"}}>
        <span style={{fontFamily: ICON, fontSize: 44, color: C.primary, fontVariationSettings: "'FILL' 1"}}>{icon}</span>{label}
      </div>
    </div>
  );
};

// Bars 11-12: four features at once, each playing.
export const Bento: React.FC = () => (
  <AbsoluteFill>
    <Backdrop hue={C.teal} hue2={C.primary} />
    <Tile x={90} y={80} w={600} h={920} start={0} icon="content_paste" label="Clipboard history">
      <Sequence from={0} layout="none"><Crop src="d07-clipboard.mp4" from={1.6} region={R.clipboard} width={520} radius={28} /></Sequence>
    </Tile>
    <Tile x={720} y={80} w={560} h={470} start={BEAT} icon="grid_view" label="Snap layouts">
      <Sequence from={BEAT} layout="none"><Crop src="d06-snap.mp4" from={1.9} region={R.snap} width={480} radius={26} /></Sequence>
    </Tile>
    <Tile x={1310} y={80} w={520} h={470} start={BEAT * 2} icon="power_settings_new" label="Power menu">
      <Sequence from={BEAT * 2} layout="none"><Crop src="d10-power.mp4" from={1.5} region={R.power} width={330} radius={26} /></Sequence>
    </Tile>
    <Tile x={720} y={580} w={1110} h={420} start={BEAT * 3} icon="notifications_active" label="Notifications and activity pills">
      <Sequence from={BEAT * 3} layout="none">
        <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 26}}>
          <Crop src="d04-activity.mp4" from={1.0} region={R.toast} width={760} radius={22} />
          <Crop src="d04-activity.mp4" from={1.0} region={R.shelfRight} width={900} radius={18} />
        </div>
      </Sequence>
    </Tile>
  </AbsoluteFill>
);
