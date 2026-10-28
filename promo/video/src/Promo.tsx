import React from 'react';
import {AbsoluteFill, Audio, Sequence, staticFile} from 'remotion';
import {Backdrop, Cam, Chip, Device, Flash, Footage, Kinetic, Screen, ShapeWipe} from './components';
import {Intro} from './scenes/Intro';
import {Breakdown} from './scenes/Breakdown';
import {Convergence} from './scenes/Convergence';
import {Outro} from './scenes/Outro';
import {BAR, BEAT, C} from './theme';

export const DURATION = Math.round(91.5 * 60);

// One beat-cut shot: a clip from `from` seconds, camera keys, and a caption chip that pops on the downbeat.
type Shot = {at: number; dur: number; clip: string; from: number; cams?: Cam[]; chip?: [string, string]; chipAt?: [number, number]; title?: string; card?: boolean; rate?: number};

const full: Cam[] = [{f: 0, s: 1, x: 0.5, y: 0.5}];
const push = (x: number, y: number, s0: number, s1: number, d: number): Cam[] => [{f: 0, s: s0, x, y}, {f: d, s: s1, x, y}];

// Bars 5-12: the desktop, cut on every bar.
const DESKTOP: Shot[] = [
  {at: 4 * BAR, dur: 2 * BAR, clip: 'd01-apps.mp4', from: 1.6, rate: 1.6, cams: [{f: 0, s: 1.22, x: 0.5, y: 0.45}, {f: 2 * BAR, s: 1.0, x: 0.5, y: 0.5}], chip: ['space_dashboard', 'Real tiling, real apps'], chipAt: [960, 960]},
  {at: 6 * BAR, dur: BAR, clip: 'd02-launcher.mp4', from: 1.6, cams: push(0.2, 0.62, 1.55, 1.75, BAR), chip: ['search', 'Start and search'], chipAt: [1380, 960]},
  {at: 7 * BAR, dur: BAR, clip: 'd03-quick-settings.mp4', from: 1.8, rate: 1.2, cams: push(0.86, 0.42, 1.6, 1.8, BAR), chip: ['tune', 'Pixel-grade Quick Settings'], chipAt: [600, 960]},
  {at: 8 * BAR, dur: BAR, clip: 'd04-activity.mp4', from: 2.6, cams: push(0.75, 0.85, 1.8, 2.0, BAR), chip: ['bolt', 'Live activities'], chipAt: [600, 160]},
  {at: 9 * BAR, dur: BAR, clip: 'd05-switcher.mp4', from: 1.1, cams: push(0.5, 0.5, 1.35, 1.5, BAR), chip: ['swap_horiz', 'Alt+Tab, reimagined'], chipAt: [960, 960]},
  {at: 10 * BAR, dur: BAR / 2, clip: 'd06-snap.mp4', from: 2.1, cams: push(0.33, 0.16, 1.8, 2.0, BAR / 2), chip: ['grid_view', 'Snap layouts'], chipAt: [600, 900]},
  {at: 10 * BAR + BAR / 2, dur: BAR / 2, clip: 'd07-clipboard.mp4', from: 1.5, cams: push(0.86, 0.35, 1.6, 1.75, BAR / 2), chip: ['content_paste', 'Clipboard history'], chipAt: [600, 900]},
  {at: 11 * BAR, dur: BAR, clip: 'd08-capture.mp4', from: 1.8, cams: push(0.5, 0.45, 1.2, 1.3, BAR), chip: ['screenshot_region', 'Capture Studio'], chipAt: [960, 960]},
];

// Bars 13-16: settings search jumps to themes, then the theme taps ripple on the beat.
const STYLE: Shot[] = [
  {at: 12 * BAR, dur: BAR, clip: 'd11-themes.mp4', from: 1.6, cams: push(0.28, 0.32, 1.7, 1.9, BAR), chip: ['manage_search', 'Search jumps to the setting'], chipAt: [1300, 960]},
  {at: 13 * BAR, dur: 3 * BAR, clip: 'd11-themes.mp4', from: 4.0, cams: [{f: 0, s: 1.25, x: 0.6, y: 0.45}, {f: 3 * BAR, s: 1.12, x: 0.55, y: 0.45}], title: '45 themes. One tap.'},
];

// Bars 33-35: Claude.
const CLAUDE: Shot[] = [
  {at: 32 * BAR, dur: 3 * BAR, clip: 'd09-assistant.mp4', from: 1.0, cams: push(0.88, 0.55, 1.5, 1.7, 3 * BAR), chip: ['auto_awesome', 'Claude, built in'], chipAt: [620, 900]},
];

// Bars 36-39: fast montage, half-bar cuts.
const half = BAR / 2;
const MONTAGE: Shot[] = [
  {at: 35 * BAR, dur: half, clip: 'd10-power.mp4', from: 1.0, cams: push(0.5, 0.5, 1.5, 1.6, half), chip: ['power_settings_new', 'Power menu'], chipAt: [960, 940]},
  {at: 35 * BAR + half, dur: half, clip: 'p04-power.mp4', from: 1.2, cams: push(0.5, 0.35, 1.0, 1.05, half), chip: ['vibration', 'Power key drum'], chipAt: [960, 940]},
  {at: 36 * BAR, dur: half, clip: 't02-app.mp4', from: 3.6, cams: push(0.5, 0.5, 1.0, 1.06, half), chip: ['apps', 'Launcher over apps'], chipAt: [960, 940]},
  {at: 36 * BAR + half, dur: half, clip: 'p02-shade.mp4', from: 1.4, cams: push(0.5, 0.4, 1.0, 1.05, half), chip: ['swipe_down', 'Phone shade'], chipAt: [960, 940]},
  {at: 37 * BAR, dur: half, clip: 'd03-quick-settings.mp4', from: 4.0, cams: push(0.86, 0.6, 1.7, 1.85, half), chip: ['music_note', 'Now playing, everywhere'], chipAt: [700, 940]},
  {at: 37 * BAR + half, dur: half, clip: 'p03-apps.mp4', from: 5.8, cams: push(0.5, 0.4, 1.0, 1.05, half), chip: ['view_carousel', 'Recents'], chipAt: [960, 940]},
  {at: 38 * BAR, dur: half, clip: 'p05-lock.mp4', from: 1.4, cams: push(0.5, 0.35, 1.0, 1.06, half), chip: ['lock', 'Lock screen'], chipAt: [960, 940]},
  {at: 38 * BAR + half, dur: half, clip: 'd12-lock.mp4', from: 1.8, cams: push(0.5, 0.4, 1.0, 1.08, half), chip: ['palette', 'Themed to the wallpaper'], chipAt: [960, 940]},
];

// Phone clips are portrait: they play inside a phone on the backdrop instead of being cropped to the frame.
const PhoneFrame: React.FC<{s: Shot}> = ({s}) => (
  <AbsoluteFill>
    <Backdrop />
    <Device kind="phone" w={392} h={872} x={960} y={500} scale={1.08}>
      <Screen src={s.clip} from={s.from} w={392} h={872} srcW={1236} srcH={2748} playbackRate={s.rate ?? 1} />
    </Device>
  </AbsoluteFill>
);

const ShotView: React.FC<{s: Shot}> = ({s}) => (
  <AbsoluteFill>
    {s.clip.startsWith('p') ? <PhoneFrame s={s} /> : <Footage src={s.clip} from={s.from} cams={s.cams ?? full} radius={0} shadow={false} playbackRate={s.rate ?? 1} />}
    {s.chip && <Chip icon={s.chip[0]} label={s.chip[1]} start={6} x={s.chip && s.clip.startsWith('p') ? 960 : s.chipAt?.[0] ?? 960} y={s.clip.startsWith('p') ? 1010 : s.chipAt?.[1] ?? 960} exit={s.dur - 12} />}
    {s.title && (
      <>
        <AbsoluteFill style={{background: 'linear-gradient(180deg, transparent 55%, rgba(5,7,15,0.75) 100%)'}} />
        <Kinetic text={s.title} start={BEAT} size={110} y={930} weight={[220, 800]} exit={s.dur - 16} />
      </>
    )}
  </AbsoluteFill>
);

const Shots: React.FC<{list: Shot[]}> = ({list}) => (
  <>
    {list.map((s, i) => (
      <Sequence key={i} from={s.at} durationInFrames={s.dur} premountFor={60}>
        <ShotView s={s} />
      </Sequence>
    ))}
  </>
);

export const Promo: React.FC = () => (
  <AbsoluteFill style={{background: C.ink}}>
    <Sequence from={0} durationInFrames={4 * BAR}><Intro /></Sequence>
    <Shots list={DESKTOP} />
    <Shots list={STYLE} />
    <Sequence from={16 * BAR} durationInFrames={2 * BAR}><Breakdown /></Sequence>
    <Sequence from={18 * BAR} durationInFrames={14 * BAR}><Convergence /></Sequence>
    <Shots list={CLAUDE} />
    <Shots list={MONTAGE} />
    <Sequence from={39 * BAR} durationInFrames={DURATION - 39 * BAR}><Outro /></Sequence>
    {/* Hits and wipes on the section changes. */}
    <Flash at={4 * BAR} />
    <Flash at={18 * BAR} />
    <Flash at={39 * BAR} />
    <ShapeWipe start={12 * BAR - 12} shape="cookie9" />
    <ShapeWipe start={32 * BAR - 12} shape="clover" color={C.teal} />
    <ShapeWipe start={35 * BAR - 12} shape="burst" color={C.pink} />
    <Audio src={staticFile('soundtrack.wav')} />
  </AbsoluteFill>
);

export {Backdrop};
