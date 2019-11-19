//
//  RCTARKitSixDegreesPlaneController.m
//  RCTARKit
//
//  Created by H. Cole Wiley on 1/17/19.
//  Copyright © 2019 HippoAR. All rights reserved.
//

#import "RCTARKitSixDegreesPlaneController.h"

#import "RCTARKitIO.h"
#import "RCTARKitNodes.h"
#import "RCTConvert+ARKit.h"

#import <SixDegreesSDK/SixDegreesSDK.h>


@interface RCTARKitSixDegreesPlaneController () {
  ARSession* _arSession;

  NSTimeInterval _lastFrameTimestamp;
  NSMutableDictionary<NSUUID*, SCNNode*>* _planes;
}

@end

@implementation RCTARKitSixDegreesPlaneController

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(mount:(NSDictionary *)property
                  node:(SCNNode *)node
                  frame:(NSString *)frame
                  parentId:(NSString *)parentId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
                  ) {

  // we need to mount first, otherwise, if the loading of the model is slow, it will be registered too late
  [[RCTARKitNodes sharedInstance] addNodeToScene:node inReferenceFrame:frame withParentId:parentId];

  NSDictionary* materialJson;
  if(property[@"material"] ) {
    materialJson = property[@"material"];
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    RCTARKitSixDegreesPlaneController* me = [RCTARKitSixDegreesPlaneController sharedInstance];
    if(materialJson) {
      [RCTConvert setMaterialProperties:me.planeMaterial properties:materialJson];
    }

    [node addChildNode:me.planesNode];
  });
  resolve(nil);
}

+ (instancetype)sharedInstance {
  static RCTARKitSixDegreesPlaneController *instance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    if (instance == nil) {
      instance = [[self alloc] init];
    }
  });
  return instance;
}

- (id)init {
  self = [super init];
  if (self) {
    _planesNode = [SCNNode new];
    [_planesNode setRenderingOrder:-1];
    _planeMaterial = [SCNMaterial new];
    [_planeMaterial setTransparency:0.6f];
    _lastFrameTimestamp = 0;
    _planes = [NSMutableDictionary new];
  }
  return self;
}

- (void)update {
  if (!_arSession) {
    _arSession = SixDegreesSDK_GetARKitSession();
    if (!_arSession) return;
  }

  ARFrame* frame = [_arSession currentFrame];
  if (!frame) return;

  if (_lastFrameTimestamp == [frame timestamp]) return;
  _lastFrameTimestamp = [frame timestamp];

  float t[16];
  SixDegreesSDK_GetARKitTransform(t, 16);
  simd_float4 c1 = simd_make_float4(t[0], t[1], t[2], t[3]);
  simd_float4 c2 = simd_make_float4(t[4], t[5], t[6], t[7]);
  simd_float4 c3 = simd_make_float4(t[8], t[9], t[10], t[11]);
  simd_float4 c4 = simd_make_float4(t[12], t[13], t[14], t[15]);
  [_planesNode setSimdTransform:simd_matrix(c1, c2, c3, c4)];

  for (ARAnchor* anchor in [frame anchors]) {
    if ([anchor isKindOfClass:[ARPlaneAnchor class]]) {
      ARPlaneAnchor* plane = (ARPlaneAnchor*)anchor;

      SCNPlane* geometry = [SCNPlane planeWithWidth:plane.extent.x height:plane.extent.z];
      [geometry setFirstMaterial:_planeMaterial];

      SCNNode* planeNode = [_planes objectForKey:plane.identifier];
      if (!planeNode) {
        SCNNode* anchorNode = [SCNNode new];
        [anchorNode setSimdTransform:plane.transform];
        planeNode = [SCNNode nodeWithGeometry:geometry];
        [anchorNode addChildNode:planeNode];
        [_planesNode addChildNode:anchorNode];
        _planes[plane.identifier] = planeNode;
      } else {
        [planeNode setGeometry:geometry];
      }
      planeNode.position = SCNVector3Make(plane.center.x, plane.center.y, plane.center.z);
      planeNode.transform = SCNMatrix4MakeRotation(-M_PI / 2.0, 1.0, 0.0, 0.0);
    }
  }
}

@end
