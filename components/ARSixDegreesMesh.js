import PropTypes from 'prop-types';

import { NativeModules } from 'react-native';

import { material, position } from 'react-native-arkit/components/lib/propTypes';
import createArComponent from 'react-native-arkit/components/lib/createArComponent';

const ARSixDegreesMesh = createArComponent(
  {
    mount: NativeModules.ARSixDegreesMeshController.mount,
  },
  {
    material,
  },
  ['sixDegreesMesh'],
);

export default ARSixDegreesMesh;
