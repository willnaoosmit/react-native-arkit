import PropTypes from 'prop-types';

import { material, position } from './lib/propTypes';
import createArComponent from './lib/createArComponent';

const ARLine = createArComponent('addLine', {
  shape: PropTypes.shape({
    thickness: PropTypes.number,
    points: PropTypes.arrayOf(PropTypes.shape({
      position,
    })).isRequired,
  }),
  material,
});

export default ARLine;
