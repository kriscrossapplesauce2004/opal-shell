import React from 'react';
import {AbsoluteFill, interpolate, interpolateColors, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {Crop, Kinetic} from '../components';
import {R} from '../regions';
import {BAR, C, FONT, emphasized} from '../theme';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

// Clip d11 from 7.4 s at 1.15x: the four taps land their new palette at these frames of the scene.
const FROM = 7.4, RATE = 1.15;
const land = (clipSec: number) => Math.round(((clipSec - FROM) / RATE) * 60);
// Accent and background of each theme, from the bundled omarchy-themes.toml.
const THEMES = [
  {at: land(8.4), name: 'Ethereal', accent: '#7d82d9', bg: '#131a3a', x: 1238, y: 518},
  {at: land(10.9), name: 'Catppuccin', accent: '#89b4fa', bg: '#313244', x: 886, y: 518},
  {at: land(13.4), name: 'Hackerman', accent: '#82FB9C', bg: '#151828', x: 1414, y: 665},
  {at: land(15.9), name: 'Gruvbox', accent: '#d8a657', bg: '#3c3836', x: 1238, y: 665},
];

// Bars 13-16: Settings search lands on the theme gallery; each tap washes the whole frame in that theme.
export const Themes: React.FC = () => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const keys = [0, ...THEMES.map((t) => t.at)];
  const accents = ['#cbb5ed', ...THEMES.map((t) => t.accent)];
  const bgs = ['#0b1022', ...THEMES.map((t) => t.bg)];
  const ease = (i: number) => keys.flatMap((k, j) => (j === 0 ? [k] : [k, k + 24])).slice(0, i);
  // Hold each colour, then move to the next over 24 frames.
  const stops = keys.flatMap((k, j) => (j === 0 ? [0] : [k, k + 24]));
  const colorAt = (list: string[]) => interpolateColors(f, stops, list.flatMap((c, j) => (j === 0 ? [c] : [list[j - 1], c])));
  void ease;
  const accent = colorAt(accents);
  const bg = colorAt(bgs);
  const enter = spring({frame: f, fps, config: {damping: 20, stiffness: 80}});
  // Settings crop placement: 1200 px wide.
  const width = 1180, k = width / R.settings[2], left = 600, top = 120;
  const tilt = interpolate(f, [0, 4 * BAR], [-10, 6], clamp);
  return (
    <AbsoluteFill style={{background: `radial-gradient(110% 90% at 30% 60%, ${bg} 0%, #05070f 75%)`}}>
      {THEMES.map((t, i) => {
        // A ring of the new accent leaves the tapped card and crosses the frame.
        const p = interpolate(f, [t.at - 20, t.at + 50], [0, 1], clamp);
        if (p <= 0 || p >= 1) return null;
        const cx = left + (t.x * 4 / 3 - R.settings[0]) * k, cy = top + (t.y * 4 / 3 - R.settings[1]) * k;
        const r = emphasized(p) * 2300;
        return <div key={i} style={{position: 'absolute', left: cx - r, top: cy - r, width: r * 2, height: r * 2, borderRadius: '50%',
          border: `6px solid ${t.accent}`, opacity: 1 - p, boxShadow: `0 0 80px ${t.accent}`}} />;
      })}
      <div style={{position: 'absolute', inset: 0, perspective: 2200}}>
        <div style={{position: 'absolute', left, top, transform: `rotateY(${tilt}deg) translateY(${(1 - enter) * 160}px)`, opacity: enter}}>
          <Crop src="d11-themes.mp4" from={FROM} rate={RATE} region={R.settings} width={width} radius={40}
            style={{boxShadow: `0 50px 140px rgba(0,0,0,0.6), 0 0 0 2px ${accent}55`}} />
        </div>
      </div>
      {/* The current theme's name, swapping on each tap. */}
      <div style={{position: 'absolute', left: 120, top: 300, width: 460}}>
        <div style={{fontFamily: FONT, fontSize: 34, color: '#a8adc8', fontVariationSettings: "'wght' 500, 'ROND' 100", marginBottom: 14}}>Now wearing</div>
        <div style={{position: 'relative', height: 110}}>
          {THEMES.map((t, i) => {
            const next = THEMES[i + 1]?.at ?? 99999;
            const a = emphasized(interpolate(f, [t.at, t.at + 20], [0, 1], clamp));
            const b = emphasized(interpolate(f, [next, next + 16], [0, 1], clamp));
            if (a <= 0 || b >= 1) return null;
            return <div key={t.name} style={{position: 'absolute', fontFamily: FONT, fontSize: 92, color: t.accent, letterSpacing: '-0.03em',
              fontVariationSettings: `'wght' ${300 + 500 * a}, 'ROND' 100`, opacity: a * (1 - b), transform: `translateY(${(1 - a) * 60 - b * 60}px)`}}>{t.name}</div>;
          })}
        </div>
        <div style={{display: 'flex', gap: 14, marginTop: 30}}>
          {[0, 1, 2, 3, 4].map((i) => <div key={i} style={{width: 46, height: 46, borderRadius: i === 0 ? 16 : 23, background: accent,
            opacity: 1 - i * 0.16, transform: `rotate(${f * (i + 1) * 0.4}deg)`}} />)}
        </div>
      </div>
      <Kinetic text="45 themes. One tap." start={THEMES[1].at - 10} size={96} x={120} y={940} align="left" weight={[240, 820]} />
    </AbsoluteFill>
  );
};
