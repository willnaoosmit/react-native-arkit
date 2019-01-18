//
//  RCTARKitSixDegreesView.m
//  RCTARKit
//
//  Created by H. Cole Wiley on 1/15/19.
//  Copyright © 2019 Scandy LLC. All rights reserved.
//

#import "RCTARKitSixDegreesView.h"

#import "RCTARSixDegreesMeshController.h"
#import "RCTARKitSixDegreesPlaneController.h"

#import <SixDegreesSDK/SixDegreesSDK.h>
#import <SixDegreesSDK/SixDegreesSDK_advanced.h>

@interface RCTARKitSixDegreesView () <MTKViewDelegate>{
  bool _isInitialized;
}
@property (nonatomic, strong) IBOutlet ARWorldTrackingConfiguration *configuration;
@end

@implementation RCTARKitSixDegreesView

-(instancetype) init
{
  if (self = [super init]) {
    [self setDevice:MTLCreateSystemDefaultDevice()];
    [self setDelegate:self];
    _isInitialized = SixDegreesSDK_IsInitialized();

//    if( !_isInitialized ){
      char version[16];
      SixDegreesSDK_GetVersion(version, 16);
      NSLog(@"Initializing 6D SDK version %s", version);

      // Create a custom ARKit configuration that enables plane detection
      ARWorldTrackingConfiguration* config = [ARWorldTrackingConfiguration new];
      config.planeDetection = ARPlaneDetectionVertical | ARPlaneDetectionHorizontal;

      // make the ARKit configuration compliant with 6D SDK requirements
      config.autoFocusEnabled = NO;
      // pick the highest 16:9 resolution (e.g. 1080p, 720p)
      NSArray<ARVideoFormat *> *supportedVideoFormats = [ARWorldTrackingConfiguration supportedVideoFormats];
      for (ARVideoFormat* videoFormat in supportedVideoFormats) {
        if (videoFormat.imageResolution.width * 9 == videoFormat.imageResolution.height * 16) {
          [config setVideoFormat:videoFormat];
          break;
        }
      }
      SixDegreesSDK_InitializeWithConfig(config);
//    }
  }
  return self;
}


- (void)drawInMTKView:(nonnull MTKView *)view {
  if (!_isInitialized) {
    _isInitialized = SixDegreesSDK_IsInitialized();
    return;
  }
  [self onFrameUpdate];

  [[RCTARSixDegreesMeshController sharedInstance] update];
  [[RCTARKitSixDegreesPlaneController sharedInstance] update];
}

// debugger logger stuff
- (void)onFrameUpdate {
  char location[16];
  location[0] = '\0';
  SixDegreesSDK_GetLocationId(location, 16);
}


- (void) pause {
  // 6D does not support the notion of pausing as of 0.19.2
}

- (void) resume {
  // 6D does not support the notion of resuming as of 0.19.2
}

- (void) reset {
  // 6D does not support the notion of resuming as of 0.19.2
}

@end
