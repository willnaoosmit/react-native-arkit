//
//  RCTARKitSixDegreesView.m
//  RCTARKit
//
//  Created by H. Cole Wiley on 1/15/19.
//  Copyright © 2019 Scandy LLC. All rights reserved.
//

#import <MetalKit/MetalKit.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTARKitSixDegreesView : MTKView

- (instancetype)init;

- (void)pause;
- (void)resume;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
