import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {MatiMatchAd} from './compositions/MatiMatchAd';

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="MatiMatchAd"
      component={MatiMatchAd}
      durationInFrames={1800}
      fps={30}
      width={1080}
      height={1920}
    />
  );
};

registerRoot(RemotionRoot);
