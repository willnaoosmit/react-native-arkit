import PropTypes from 'prop-types';

import { NativeModules } from 'react-native';

import { material, position } from 'react-native-arkit/components/lib/propTypes';
import createArComponent from 'react-native-arkit/components/lib/createArComponent';

const ARSixDegreesPlane = createArComponent(
  {
    mount: NativeModules.ARKitSixDegreesPlaneController.mount,
  },
  {
    material,
  },
  ['sixDegreesMesh'],
);

export default ARSixDegreesPlane;
