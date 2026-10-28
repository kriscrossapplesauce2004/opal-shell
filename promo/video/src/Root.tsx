import React from 'react';
import {Composition} from 'remotion';
import {Promo, DURATION} from './Promo';
import {FPS, H, W} from './theme';

export const Root: React.FC = () => (
  <Composition id="OpalPromo" component={Promo} durationInFrames={DURATION} fps={FPS} width={W} height={H} />
);
