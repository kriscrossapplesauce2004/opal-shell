// Opal tokens for the promo, taken from the shell's dark nebula look.
export const FPS = 60;
export const BPM = 120;
export const BEAT = (60 / BPM) * FPS; // 30 frames
export const BAR = BEAT * 4; // 120 frames
export const W = 1920;
export const H = 1080;

export const C = {
  ink: '#05070f',
  night: '#0b1022',
  surface: '#161a2b',
  surfaceHi: '#20253a',
  text: '#eef0ff',
  dim: '#a8adc8',
  primary: '#cbb5ed',
  primaryInk: '#2d1a52',
  teal: '#7fe3e0',
  pink: '#f4a6d7',
  amber: '#ffcf8a',
  blue: '#9ec3ff',
};

export const FONT = "'Google Sans Flex', 'Google Sans', system-ui, sans-serif";
export const ICON = "'Material Symbols Rounded'";

// Bar/beat helpers: bars and beats are 1-based like the soundtrack's arrangement.
export const at = (bar: number, beat = 1) => Math.round(((bar - 1) * 4 + (beat - 1)) * BEAT);

// M3 expressive easings.
export const emphasized = (t: number) => {
  // Approximates cubic-bezier(0.2, 0, 0, 1).
  const c = Math.min(1, Math.max(0, t));
  return 1 - Math.pow(1 - c, 4);
};
export const standard = (t: number) => {
  const c = Math.min(1, Math.max(0, t));
  return c < 0.5 ? 4 * c * c * c : 1 - Math.pow(-2 * c + 2, 3) / 2;
};
