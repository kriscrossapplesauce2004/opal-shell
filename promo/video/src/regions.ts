// Where each piece of UI sits in the edit proxies (clip pixels: desktop/console 2560x1440, tablet 2560x1600, phone 1236x2748).
// Measured from gridded frames (tools/regions.py helps for things that appear on a still background).
export type Region = [number, number, number, number];

export const R = {
  launcher: [16, 524, 1256, 812] as Region,
  quickSettings: [2030, 442, 496, 896] as Region,
  toast: [2052, 1236, 484, 104] as Region,
  shelfRight: [1896, 1366, 640, 60] as Region,
  switcher: [756, 532, 1044, 408] as Region,
  snap: [738, 18, 524, 360] as Region,
  clipboard: [1890, 82, 652, 864] as Region,
  power: [1078, 514, 404, 412] as Region,
  assistant: [1918, 274, 624, 1052] as Region,
  settings: [530, 198, 1496, 1044] as Region,
  consoleHero: [168, 116, 1836, 412] as Region,
  consoleUpdates: [1998, 116, 514, 412] as Region,
  covers: [168, 596, 2392, 248] as Region,
  consoleWidgets: [168, 908, 1768, 276] as Region,
  quickAccess: [1794, 10, 748, 1420] as Region,
};
