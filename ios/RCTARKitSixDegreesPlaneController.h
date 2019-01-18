//
//  RCTARKitSixDegreesPlaneController.h
//  RCTARKit
//
//  Created by H. Cole Wiley on 1/17/19.
//  Copyright © 2019 HippoAR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import <React/RCTBridgeModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTARKitSixDegreesPlaneController : NSObject<RCTBridgeModule>

+ (instancetype)sharedInstance;

- (void)update;

@property (readonly) SCNNode* planesNode;
@property (readonly) SCNMaterial* planeMaterial;


@end

NS_ASSUME_NONNULL_END
