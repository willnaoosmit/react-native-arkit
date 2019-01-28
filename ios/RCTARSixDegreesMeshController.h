//
//  RCTARSixDegreesMeshController.h
//  RCTARKit
//
//  Created by H. Cole Wiley on 1/16/19.
//  Copyright © 2019 HippoAR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import <React/RCTBridgeModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTARSixDegreesMeshController : NSObject<RCTBridgeModule>

@property (readonly) SCNNode* meshNode;
@property (readonly) SCNNode* matNode;
@property (readonly) SCNMaterial* meshMaterial;
@property (readonly) int meshVersion;

+ (instancetype)sharedInstance;

- (void)update;
- (SCNNode*) node;

@end

NS_ASSUME_NONNULL_END
