//
//  RCTARKitSixDegreesView.m
//  RCTARKit
//
//  Created by H. Cole Wiley on 1/15/19.
//  Copyright © 2019 Scandy LLC. All rights reserved.
//

#import "RCTARKitSixDegreesManager.h"

#import "RCTARSixDegreesMeshController.h"
#import "RCTARKitSixDegreesPlaneController.h"

#import <SixDegreesSDK/SixDegreesSDK.h>
//#import <SixDegreesSDK/SixDegreesSDK_advanced.h>


@implementation RCTARKitSixDegreesManager

-(instancetype) init
{
  if (self = [super init]) {
    [self setDevice:MTLCreateSystemDefaultDevice()];
    [self setDelegate:self];

    if( !SixDegreesSDK_IsInitialized() ){
      char version[16];
      SixDegreesSDK_GetVersion(version, 16);
      NSLog(@"Initializing 6D SDK version %s", version);

      // Create a custom ARKit configuration that enables plane detection
      ARWorldTrackingConfiguration* config = [ARWorldTrackingConfiguration new];
      if (@available(iOS 11.3, *)) {
        // make the ARKit configuration compliant with 6D SDK requirements
        config.planeDetection = ARPlaneDetectionVertical | ARPlaneDetectionHorizontal;
        config.autoFocusEnabled = NO;

        // pick the highest 16:9 resolution (e.g. 1080p, 720p)
        NSArray<ARVideoFormat *> *supportedVideoFormats = [ARWorldTrackingConfiguration supportedVideoFormats];
        for (ARVideoFormat* videoFormat in supportedVideoFormats) {
          if (videoFormat.imageResolution.width * 9 == videoFormat.imageResolution.height * 16) {
            [config setVideoFormat:videoFormat];
            break;
          }
        }
      } else {
        // Fallback on earlier versions
      }
      SixDegreesSDK_InitializeWithConfig(config);
    }
  }
  return self;
}

// Currently just using this as a polling loop
- (void)drawInMTKView:(nonnull MTKView *)view {
  if (!SixDegreesSDK_IsInitialized()) {
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
//    NSLog(@"onFrameUpdate: %@", [NSString stringWithUTF8String:location]);
}

@end
