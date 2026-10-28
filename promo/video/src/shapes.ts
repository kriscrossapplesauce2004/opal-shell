// Material 3 Expressive shapes as polar outlines sampled to the same point count, so any two morph point by point.
export type Shape = {lobes: number; depth: number; squircle?: number; stretch?: number; spin?: number};

export const SHAPES: Record<string, Shape> = {
  circle: {lobes: 0, depth: 0},
  cookie4: {lobes: 4, depth: 0.12},
  cookie6: {lobes: 6, depth: 0.08},
  cookie9: {lobes: 9, depth: 0.06},
  clover: {lobes: 4, depth: 0.22},
  flower: {lobes: 8, depth: 0.14},
  burst: {lobes: 12, depth: 0.09},
  sunny: {lobes: 8, depth: 0.05},
  square: {lobes: 0, depth: 0, squircle: 5},
  pill: {lobes: 0, depth: 0, squircle: 3, stretch: 1.9},
};

const N = 240;

function point(s: Shape, theta: number): [number, number] {
  const spin = s.spin ?? 0;
  let r = 1 + s.depth * Math.cos(s.lobes * (theta + spin));
  r /= 1 + s.depth;
  let x = Math.cos(theta) * r;
  let y = Math.sin(theta) * r;
  if (s.squircle) {
    // Superellipse: |x|^n + |y|^n = 1, sampled along the same angle.
    const n = s.squircle;
    const c = Math.cos(theta), si = Math.sin(theta);
    const k = Math.pow(Math.pow(Math.abs(c), n) + Math.pow(Math.abs(si), n), -1 / n);
    x = c * k;
    y = si * k;
  }
  if (s.stretch) x *= s.stretch;
  return [x, y];
}

export function outline(s: Shape): [number, number][] {
  return Array.from({length: N}, (_, i) => point(s, (i / N) * Math.PI * 2 - Math.PI / 2));
}

export function morph(a: Shape, b: Shape, t: number): [number, number][] {
  const pa = outline(a), pb = outline(b);
  return pa.map(([x, y], i) => [x + (pb[i][0] - x) * t, y + (pb[i][1] - y) * t]);
}

export function toPath(points: [number, number][], cx: number, cy: number, r: number): string {
  return points.map(([x, y], i) => `${i ? 'L' : 'M'}${(cx + x * r).toFixed(2)} ${(cy + y * r).toFixed(2)}`).join(' ') + 'Z';
}
