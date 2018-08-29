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


/**

 func line(from p1: SCNVector3, to p2: SCNVector3) -> SCNNode? {
   // Draw a line between two points and return it as a node
   var indices = [Int32(0), Int32(1)]
   let positions = [p1, p2]
   let vertexSource = SCNGeometrySource(vertices: positions)
   let indexData = Data(bytes: &indices, count:MemoryLayout<Int32>.size * indices.count)
   let element = SCNGeometryElement(data: indexData, primitiveType: .line, primitiveCount: 1, bytesPerIndex: MemoryLayout<Int32>.size)
   let line = SCNGeometry(sources: [vertexSource], elements: [element])
   let lineNode = SCNNode(geometry: line)
   return lineNode
  }
  */