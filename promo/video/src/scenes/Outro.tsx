import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame} from 'remotion';
import {Backdrop, Chip, Morph} from '../components';
import {BAR, BEAT, C, FONT, emphasized} from '../theme';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const INSTALL = 'curl -fsSL https://raw.githubusercontent.com/kriscrossapplesauce2004/opal-shell/main/get.sh | sh';

// Bars 40-44: the wordmark, the four modes as chips, and the one-line install.
export const Outro: React.FC = () => {
  const f = useCurrentFrame();
  const mark = emphasized(interpolate(f, [4, 40], [0, 1], clamp));
  const wght = interpolate(f, [4, 60], [200, 860], clamp);
  const line = emphasized(interpolate(f, [2 * BAR, 2 * BAR + 30], [0, 1], clamp));
  const typed = Math.floor(interpolate(f, [2 * BAR + 10, 3 * BAR + 30], [0, INSTALL.length], clamp));
  const fade = interpolate(f, [4 * BAR + BEAT * 3, 4 * BAR + BEAT * 9], [1, 0], clamp);
  return (
    <AbsoluteFill style={{opacity: fade}}>
      <Backdrop pulse={0.6} />
      <Morph size={interpolate(f, [0, 60], [300, 760], {...clamp, easing: emphasized})} y={400} opacity={0.18} beatKick={0.04}
        keys={[{at: 0, shape: 'burst'}, {at: BAR, shape: 'flower'}, {at: 2 * BAR, shape: 'cookie9'}, {at: 3 * BAR, shape: 'clover'}, {at: 4 * BAR, shape: 'circle'}]} />
      <div style={{position: 'absolute', top: 210, width: 1920, textAlign: 'center', fontFamily: FONT, fontSize: 260, color: C.text, letterSpacing: '-0.05em',
        fontVariationSettings: `'wght' ${wght}, 'wdth' 108, 'ROND' 100, 'opsz' 144`, opacity: mark, transform: `scale(${0.9 + 0.1 * mark})`}}>Opal</div>
      {[['desktop_windows', 'Desktop'], ['tablet', 'Tablet'], ['smartphone', 'Phone'], ['sports_esports', 'Console']].map(([icon, label], i) => (
        <Chip key={label} icon={icon} label={label} start={BAR + i * BEAT} x={960 + (i - 1.5) * 330} y={590} />
      ))}
      <div style={{position: 'absolute', left: 960, top: 760, transform: `translate(-50%, 0) scale(${0.96 + 0.04 * line})`, opacity: line,
        padding: '22px 34px', borderRadius: 26, background: 'rgba(16, 19, 33, 0.82)', border: '1.5px solid rgba(255,255,255,0.12)',
        fontFamily: "'JetBrains Mono', 'Fira Code', monospace", fontSize: 27, color: C.text, whiteSpace: 'nowrap', boxShadow: '0 30px 80px rgba(0,0,0,0.5)'}}>
        <span style={{color: C.primary}}>$ </span>{INSTALL.slice(0, typed)}<span style={{opacity: (f >> 4) % 2 ? 1 : 0, color: C.primary}}>▍</span>
      </div>
      <div style={{position: 'absolute', top: 870, width: 1920, textAlign: 'center', fontFamily: FONT, fontSize: 36, color: C.dim,
        fontVariationSettings: "'wght' 450, 'ROND' 100", opacity: emphasized(interpolate(f, [3 * BAR, 3 * BAR + 30], [0, 1], clamp))}}>
        github.com/kriscrossapplesauce2004/opal-shell
      </div>
    </AbsoluteFill>
  );
};
