import React from 'react';
import {AbsoluteFill, Easing, interpolate, OffthreadVideo, random, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {BEAT, C, FONT, ICON, emphasized} from '../theme';
import {SHAPES, morph, toPath} from '../shapes';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

// ---------------------------------------------------------------- backdrop

// Deep night with slow colour fields that breathe on the beat, plus film grain.
export const Backdrop: React.FC<{hue?: string; hue2?: string; pulse?: number}> = ({hue = C.primary, hue2 = C.teal, pulse = 1}) => {
  const f = useCurrentFrame();
  const beat = (f % BEAT) / BEAT;
  const kick = Math.exp(-beat * 6) * 0.06 * pulse;
  const blob = (x: number, y: number, r: number, color: string, phase: number) => ({
    position: 'absolute' as const,
    left: `${x + Math.sin(f / 140 + phase) * 6}%`,
    top: `${y + Math.cos(f / 170 + phase) * 6}%`,
    width: r * (1 + kick),
    height: r * (1 + kick),
    transform: 'translate(-50%, -50%)',
    borderRadius: '50%',
    background: `radial-gradient(circle, ${color} 0%, transparent 65%)`,
    opacity: 0.32,
    filter: 'blur(40px)',
  });
  return (
    <AbsoluteFill style={{background: `radial-gradient(120% 90% at 50% 110%, ${C.night} 0%, ${C.ink} 70%)`, overflow: 'hidden'}}>
      <div style={blob(22, 30, 1100, hue, 0)} />
      <div style={blob(80, 70, 1200, hue2, 2)} />
      <div style={blob(60, 15, 700, C.pink, 4)} />
      <Stars />
      <Grain />
    </AbsoluteFill>
  );
};

const Stars: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill>
      {Array.from({length: 90}, (_, i) => {
        const x = random(`sx${i}`) * 100, y = random(`sy${i}`) * 100, s = 1 + random(`ss${i}`) * 2.2;
        const tw = 0.35 + 0.65 * Math.abs(Math.sin(f / (40 + random(`st${i}`) * 80) + i));
        return <div key={i} style={{position: 'absolute', left: `${x}%`, top: `${(y + f * 0.004 * s) % 100}%`, width: s, height: s, borderRadius: s, background: '#fff', opacity: tw * 0.5}} />;
      })}
    </AbsoluteFill>
  );
};

const Grain: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill style={{mixBlendMode: 'overlay', opacity: 0.16, pointerEvents: 'none'}}>
      <svg width="100%" height="100%">
        <filter id="grain">
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves={2} seed={f % 30} />
          <feColorMatrix type="saturate" values="0" />
        </filter>
        <rect width="100%" height="100%" filter="url(#grain)" />
      </svg>
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- shapes

type Key = {at: number; shape: keyof typeof SHAPES};

// An M3 Expressive shape that morphs through keyed shapes and spins a little; kicks on the beat when asked.
export const Morph: React.FC<{keys: Key[]; size: number; x?: number; y?: number; fill?: string; fill2?: string; spin?: number; beatKick?: number; opacity?: number; dur?: number}> = ({
  keys, size, x = 960, y = 540, fill = C.primary, fill2 = C.teal, spin = 0.15, beatKick = 0, opacity = 1, dur = 18,
}) => {
  const f = useCurrentFrame();
  let i = 0;
  while (i < keys.length - 1 && f >= keys[i + 1].at) i++;
  const from = keys[i];
  const to = keys[Math.min(i + 1, keys.length - 1)];
  const prev = keys[Math.max(0, i - 1)];
  // Morph into keys[i] during the dur frames after it starts.
  const t = emphasized(interpolate(f, [from.at, from.at + dur], [0, 1], clamp));
  const pts = morph(SHAPES[i === 0 ? from.shape : prev.shape], SHAPES[from.shape], i === 0 ? 1 : t);
  void to;
  const kick = beatKick ? 1 + Math.exp(-((f % BEAT) / BEAT) * 7) * beatKick : 1;
  const id = `g${size}${x}${y}`;
  return (
    <svg width={1920} height={1080} style={{position: 'absolute', inset: 0, opacity}}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor={fill} />
          <stop offset="100%" stopColor={fill2} />
        </linearGradient>
      </defs>
      <g transform={`rotate(${(f * spin) % 360} ${x} ${y})`}>
        <path d={toPath(pts, x, y, (size / 2) * kick)} fill={`url(#${id})`} />
      </g>
    </svg>
  );
};

// ---------------------------------------------------------------- type

// Words rise out of a mask one by one while the variable weight sweeps from thin to heavy.
export const Kinetic: React.FC<{
  text: string; start: number; size?: number; color?: string; stagger?: number; weight?: [number, number]; y?: number; x?: number;
  align?: 'center' | 'left'; exit?: number; width?: number; italic?: boolean; tracking?: number;
}> = ({text, start, size = 120, color = C.text, stagger = 4, weight = [250, 760], y = 540, x = 960, align = 'center', exit, width = 100, italic, tracking = -0.02}) => {
  const f = useCurrentFrame();
  const words = text.split(' ');
  const out = exit !== undefined ? emphasized(interpolate(f, [exit, exit + 14], [0, 1], clamp)) : 0;
  return (
    <div style={{position: 'absolute', left: align === 'center' ? 0 : x, top: y, width: align === 'center' ? 1920 : undefined, transform: 'translateY(-50%)',
      display: 'flex', justifyContent: align === 'center' ? 'center' : 'flex-start', gap: size * 0.26, fontFamily: FONT, fontSize: size, color,
      letterSpacing: `${tracking}em`, lineHeight: 1.05, opacity: 1 - out}}>
      {words.map((w, i) => {
        const s = start + i * stagger;
        const p = emphasized(interpolate(f, [s, s + 22], [0, 1], clamp));
        const wg = interpolate(f, [s, s + 34], weight, {...clamp, easing: Easing.out(Easing.cubic)});
        return (
          <span key={i} style={{display: 'inline-block', overflow: 'hidden', paddingBottom: size * 0.12, marginBottom: -size * 0.12}}>
            <span style={{display: 'inline-block', transform: `translateY(${(1 - p) * 105 + out * -40}%)`,
              fontVariationSettings: `'wght' ${wg}, 'wdth' ${width}, 'ROND' 100, 'opsz' 144${italic ? ", 'slnt' -10" : ''}`}}>{w}</span>
          </span>
        );
      })}
    </div>
  );
};

// ---------------------------------------------------------------- chips

// An M3 assist chip that pops in (squish on arrival) with a Material Symbols icon.
export const Chip: React.FC<{icon: string; label: string; start: number; x: number; y: number; scale?: number; tone?: 'surface' | 'primary' | 'glass'; exit?: number}> = ({
  icon, label, start, x, y, scale = 1, tone = 'glass', exit,
}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: f - start, fps, config: {damping: 14, stiffness: 180, mass: 0.7}});
  const out = exit !== undefined ? emphasized(interpolate(f, [exit, exit + 10], [0, 1], clamp)) : 0;
  const bg = tone === 'primary' ? C.primary : tone === 'surface' ? C.surfaceHi : 'rgba(30, 34, 54, 0.72)';
  const fg = tone === 'primary' ? C.primaryInk : C.text;
  if (f < start) return null;
  return (
    <div style={{position: 'absolute', left: x, top: y, transform: `translate(-50%, -50%) scale(${scale * s * (1 - out * 0.4)}, ${scale * (0.6 + 0.4 * s) * (1 - out * 0.4)})`,
      opacity: Math.min(1, s * 1.4) * (1 - out), display: 'flex', alignItems: 'center', gap: 18, padding: '20px 40px 20px 28px', borderRadius: 999,
      background: bg, color: fg, fontFamily: FONT, fontSize: 42, fontVariationSettings: "'wght' 600, 'ROND' 100", whiteSpace: 'nowrap',
      border: tone === 'glass' ? '1.5px solid rgba(255,255,255,0.14)' : 'none', backdropFilter: 'blur(18px)', boxShadow: '0 18px 50px rgba(0,0,0,0.35)'}}>
      <span style={{fontFamily: ICON, fontSize: 50, fontVariationSettings: "'FILL' 1, 'wght' 500", color: tone === 'primary' ? C.primaryInk : C.primary}}>{icon}</span>
      {label}
    </div>
  );
};

// ---------------------------------------------------------------- footage

export type Cam = {f: number; s: number; x: number; y: number};

// A recorded clip on a rounded card with camera keys (scale and focus point in clip pixels, 0-1).
export const Footage: React.FC<{
  src: string; from: number; cams?: Cam[]; radius?: number; inset?: number; enter?: 'rise' | 'zoom' | 'none'; playbackRate?: number;
  width?: number; height?: number; shadow?: boolean; style?: React.CSSProperties;
}> = ({src, from, cams = [{f: 0, s: 1, x: 0.5, y: 0.5}], radius = 28, inset = 0, enter = 'none', playbackRate = 1, width = 1920, height = 1080, shadow = true, style}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const fs = cams.map((c) => c.f);
  const ease = {...clamp, easing: Easing.bezier(0.3, 0, 0, 1)};
  const s = cams.length > 1 ? interpolate(f, fs, cams.map((c) => c.s), ease) : cams[0].s;
  const cx = cams.length > 1 ? interpolate(f, fs, cams.map((c) => c.x), ease) : cams[0].x;
  const cy = cams.length > 1 ? interpolate(f, fs, cams.map((c) => c.y), ease) : cams[0].y;
  const e = enter === 'none' ? 1 : spring({frame: f, fps, config: {damping: 20, stiffness: 120}});
  const entry = enter === 'rise' ? `translateY(${(1 - e) * 140}px) scale(${0.94 + 0.06 * e})` : enter === 'zoom' ? `scale(${1.12 - 0.12 * e})` : '';
  const w = width - inset * 2, h = height - inset * 2;
  // Keep the focus point centred while zoomed, without showing past the clip's edges.
  const tx = Math.max(Math.min((0.5 - cx) * w * s, (w * (s - 1)) / 2), (-w * (s - 1)) / 2);
  const ty = Math.max(Math.min((0.5 - cy) * h * s, (h * (s - 1)) / 2), (-h * (s - 1)) / 2);
  return (
    <div style={{position: 'absolute', left: inset, top: inset, width: w, height: h, borderRadius: radius, overflow: 'hidden', transform: entry,
      boxShadow: shadow ? '0 40px 120px rgba(0,0,0,0.55), 0 0 0 1.5px rgba(255,255,255,0.08)' : undefined, background: C.ink, ...style}}>
      <OffthreadVideo src={staticFile(`clips/${src}`)} startFrom={Math.round(from * fps)} playbackRate={playbackRate} muted
        style={{width: w, height: h, objectFit: 'cover', transform: `translate(${tx}px, ${ty}px) scale(${s})`, transformOrigin: '50% 50%'}} />
    </div>
  );
};

// ---------------------------------------------------------------- devices

// Thin modern bezels: the screen content is a child sized to the screen.
export const Device: React.FC<{kind: 'phone' | 'tablet' | 'monitor'; w: number; h: number; x: number; y: number; scale?: number; rotate?: number; children: React.ReactNode; style?: React.CSSProperties}> = ({
  kind, w, h, x, y, scale = 1, rotate = 0, children, style,
}) => {
  const bezel = kind === 'phone' ? 14 : kind === 'tablet' ? 22 : 16;
  const radius = kind === 'phone' ? 58 : kind === 'tablet' ? 40 : 18;
  return (
    <div style={{position: 'absolute', left: x, top: y, transform: `translate(-50%, -50%) scale(${scale}) rotate(${rotate}deg)`, ...style}}>
      <div style={{padding: bezel, borderRadius: radius + bezel, background: 'linear-gradient(145deg, #2a2e40, #0d0f18 60%, #23273a)',
        boxShadow: '0 50px 140px rgba(0,0,0,0.6), inset 0 0 0 1.5px rgba(255,255,255,0.12)'}}>
        <div style={{width: w, height: h, borderRadius: radius, overflow: 'hidden', position: 'relative', background: '#000'}}>{children}</div>
      </div>
      {kind === 'monitor' && (
        <div style={{position: 'absolute', left: '50%', bottom: -110, transform: 'translateX(-50%)', width: 220, height: 110,
          background: 'linear-gradient(#1b1e2c, #10121b)', clipPath: 'polygon(30% 0, 70% 0, 100% 100%, 0 100%)'}} />
      )}
    </div>
  );
};

// A device screen showing a clip scaled to fill it.
export const Screen: React.FC<{src: string; from: number; w: number; h: number; srcW: number; srcH: number; playbackRate?: number}> = ({src, from, w, h, srcW, srcH, playbackRate = 1}) => {
  const {fps} = useVideoConfig();
  const k = Math.max(w / srcW, h / srcH);
  return (
    <OffthreadVideo src={staticFile(`clips/${src}`)} startFrom={Math.round(from * fps)} playbackRate={playbackRate} muted
      style={{position: 'absolute', left: (w - srcW * k) / 2, top: (h - srcH * k) / 2, width: srcW * k, height: srcH * k}} />
  );
};

// ---------------------------------------------------------------- transitions

// A shape-masked wipe: an M3 shape grows from a point and reveals the next scene.
export const ShapeWipe: React.FC<{start: number; dur?: number; shape?: keyof typeof SHAPES; x?: number; y?: number; color?: string}> = ({start, dur = 22, shape = 'cookie9', x = 960, y = 540, color = C.primary}) => {
  const f = useCurrentFrame();
  const t = interpolate(f, [start, start + dur], [0, 1], clamp);
  if (t <= 0 || t >= 1) return null;
  const grow = emphasized(t);
  const r = grow * 2600;
  const hole = Math.max(0, emphasized(interpolate(t, [0.35, 1], [0, 1], clamp)) * 2600);
  return (
    <svg width={1920} height={1080} style={{position: 'absolute', inset: 0}}>
      <path fillRule="evenodd" d={toPath(morph(SHAPES[shape], SHAPES[shape], 0), x, y, r) + ' ' + toPath(morph(SHAPES.circle, SHAPES.circle, 0), x, y, hole)}
        fill={color} transform={`rotate(${t * 90} ${x} ${y})`} />
    </svg>
  );
};

// A quick white flash on a hit.
export const Flash: React.FC<{at: number; dur?: number; strength?: number}> = ({at, dur = 12, strength = 0.85}) => {
  const f = useCurrentFrame();
  const o = interpolate(f, [at, at + 2, at + dur], [0, strength, 0], clamp);
  return o > 0 ? <AbsoluteFill style={{background: '#fff', opacity: o, mixBlendMode: 'screen'}} /> : null;
};

// ---------------------------------------------------------------- crops and keys

// One region of a clip shown at a given width, as its own card.
export const Crop: React.FC<{
  src: string; from: number; region: [number, number, number, number]; width: number; srcW?: number; srcH?: number;
  rate?: number; radius?: number; shadow?: boolean; style?: React.CSSProperties;
}> = ({src, from, region: [rx, ry, rw, rh], width, srcW = 2560, srcH = 1440, rate = 1, radius = 26, shadow = true, style}) => {
  const {fps} = useVideoConfig();
  const k = width / rw;
  return (
    <div style={{width, height: rh * k, borderRadius: radius, overflow: 'hidden', position: 'relative', background: C.ink,
      boxShadow: shadow ? '0 40px 110px rgba(0,0,0,0.55), 0 0 0 1.5px rgba(255,255,255,0.10)' : undefined, ...style}}>
      <OffthreadVideo src={staticFile(`clips/${src}`)} startFrom={Math.round(from * fps)} playbackRate={rate} muted
        style={{position: 'absolute', left: -rx * k, top: -ry * k, width: srcW * k, height: srcH * k, maxWidth: 'none'}} />
    </div>
  );
};

// A keyboard key that sinks while pressed. `down` lists [pressFrame, releaseFrame] pairs.
export const Keycap: React.FC<{label: string; width?: number; down: [number, number][]; x: number; y: number; delay?: number}> = ({label, width = 150, down, x, y, delay = 0}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({frame: f - delay, fps, config: {damping: 15, stiffness: 160}});
  const pressed = down.some(([a, b]) => f >= a && f < b);
  const lastEdge = Math.max(...down.flatMap(([a, b]) => [a, b]).filter((e) => e <= f), -999);
  const p = spring({frame: f - lastEdge, fps, config: {damping: 18, stiffness: 420}});
  const depth = pressed ? p : 1 - p;
  return (
    <div style={{position: 'absolute', left: x, top: y, transform: `translate(-50%, -50%) translateY(${(1 - enter) * 80}px) scale(${0.9 + 0.1 * enter})`, opacity: enter}}>
      <div style={{width, height: 120, borderRadius: 30, background: '#0c0f1c', paddingBottom: 12 * (1 - depth), boxSizing: 'border-box', transform: `translateY(${12 * depth}px)`}}>
        <div style={{height: 108, borderRadius: 30, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: FONT, fontSize: 44,
          fontVariationSettings: "'wght' 620, 'ROND' 100", color: pressed ? C.primaryInk : C.text,
          background: pressed ? C.primary : 'linear-gradient(180deg, #2b3049, #1d2134)', border: '1.5px solid rgba(255,255,255,0.14)',
          boxShadow: pressed ? `0 0 50px ${C.primary}88` : '0 18px 40px rgba(0,0,0,0.45)'}}>{label}</div>
      </div>
    </div>
  );
};

// An M3 connected button group; the selected segment changes colour only.
export const Segmented: React.FC<{items: [string, string][]; selected: number; x: number; y: number; start?: number}> = ({items, selected, x, y, start = 0}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const e = spring({frame: f - start, fps, config: {damping: 16, stiffness: 150}});
  return (
    <div style={{position: 'absolute', left: x, top: y, transform: `translate(-50%, -50%) translateY(${(1 - e) * 50}px)`, opacity: e, display: 'flex', gap: 6}}>
      {items.map(([icon, label], i) => {
        const on = i === selected;
        return (
          <div key={label} style={{display: 'flex', alignItems: 'center', gap: 14, padding: '18px 34px', fontFamily: FONT, fontSize: 38,
            fontVariationSettings: "'wght' 600, 'ROND' 100", color: on ? C.primaryInk : C.text, background: on ? C.primary : 'rgba(32, 37, 58, 0.85)',
            borderRadius: i === 0 ? '999px 14px 14px 999px' : i === items.length - 1 ? '14px 999px 999px 14px' : 14,
            transition: 'none', border: '1.5px solid rgba(255,255,255,0.10)'}}>
            <span style={{fontFamily: ICON, fontSize: 44, fontVariationSettings: "'FILL' 1"}}>{icon}</span>{label}
          </div>
        );
      })}
    </div>
  );
};

// Plain caption text that fades and rises in, then holds.
export const Caption: React.FC<{text: string; start: number; x?: number; y: number; size?: number; color?: string; align?: 'left' | 'center'; weight?: number; exit?: number; maxWidth?: number}> = ({
  text, start, x = 960, y, size = 40, color = C.dim, align = 'center', weight = 450, exit, maxWidth = 900,
}) => {
  const f = useCurrentFrame();
  const t = emphasized(interpolate(f, [start, start + 24], [0, 1], clamp));
  const out = exit !== undefined ? interpolate(f, [exit, exit + 14], [0, 1], clamp) : 0;
  return (
    <div style={{position: 'absolute', left: align === 'center' ? x - maxWidth / 2 : x, top: y, width: maxWidth, textAlign: align, fontFamily: FONT, fontSize: size, color,
      fontVariationSettings: `'wght' ${weight}, 'ROND' 100`, lineHeight: 1.25, opacity: t * (1 - out), transform: `translateY(${(1 - t) * 24}px)`}}>{text}</div>
  );
};
