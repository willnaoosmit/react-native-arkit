//
//  RCTARKit.m
//  RCTARKit
//
//  Created by HippoAR on 7/9/17.
//  Copyright © 2017 HippoAR. All rights reserved.
//

#import "RCTARKit.h"
#import "RCTConvert+ARKit.h"

@import CoreLocation;

@interface RCTARKit () <ARSCNViewDelegate, ARSessionDelegate, UIGestureRecognizerDelegate> {
    RCTARKitResolve _resolve;
}

@property (nonatomic, strong) ARSession* session;
@property (nonatomic, strong) ARWorldTrackingConfiguration *configuration;

@end


void dispatch_once_on_main_thread(dispatch_once_t *predicate,
                                  dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        dispatch_once(predicate, block);
    } else {
        if (DISPATCH_EXPECT(*predicate == 0L, NO)) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                dispatch_once(predicate, block);
            });
        }
    }
}


@implementation RCTARKit
static RCTARKit *instance = nil;
static ARSCNView *arView = nil;
static dispatch_once_t onceToken;

+ (bool)isInitialized {
    return instance !=nil;
}

+ (instancetype)sharedInstance {

    dispatch_once_on_main_thread(&onceToken, ^{
        if (instance == nil) {
          arView = [[ARSCNView alloc] init];
         instance = [[self alloc] initWithARView:arView];
        }
    });

    return instance;
}

+ (void) hardReset{
    @synchronized(self) {
        instance = nil;
        arView = nil;
        onceToken = 0;
        [[RCTARKit sharedInstance] reset];
    }
}


- (bool)isMounted {

    return self.superview != nil;
}

// This is the old regular react-native-arkit init
- (instancetype)initWithARView:(ARSCNView *)arView {
    if ((self = [super init])) {
      if( arView ){
        self.arView = arView;

        // delegates
        arView.delegate = self;
        arView.session.delegate = self;

        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
        tapGestureRecognizer.numberOfTapsRequired = 1;
        [self.arView addGestureRecognizer:tapGestureRecognizer];

        self.touchDelegates = [NSMutableArray array];
        self.rendererDelegates = [NSMutableArray array];
        self.sessionDelegates = [NSMutableArray array];

        // nodeManager
        self.nodeManager = [RCTARKitNodes sharedInstance];
        self.nodeManager.arView = arView;
        [self.sessionDelegates addObject:self.nodeManager];

        // configuration(s)
        arView.autoenablesDefaultLighting = YES;
        arView.scene.rootNode.name = @"root";

        #if TARGET_IPHONE_SIMULATOR
        // allow for basic orbit gestures if we're running in the simulator
        arView.allowsCameraControl = YES;
        arView.defaultCameraController.interactionMode = SCNInteractionModeOrbitTurntable;
        arView.defaultCameraController.maximumVerticalAngle = 45;
        arView.defaultCameraController.inertiaEnabled = YES;
        [arView.defaultCameraController translateInCameraSpaceByX:(float) 0.0 Y:(float) 0.0 Z:(float) 3.0];

        #endif

        // start ARKit
        [self addSubview:arView];
        [self resume];
      }

    }
    return self;
}




- (void)layoutSubviews {
  [super layoutSubviews];
//  NSLog(@"setting view bounds %@", NSStringFromCGRect(self.bounds));
  self.arView.frame = self.bounds;
}

- (void)pause {
  [self.session pause];
}

- (void)resume {
  [self.session runWithConfiguration:self.configuration];
}

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    if(self.onARKitError) {
        self.onARKitError(RCTJSErrorFromNSError(error));
    } else {
        NSLog(@"Initializing ARKIT failed with Error: %@ %@", error, [error userInfo]);

    }

}
- (void)reset {
  if (ARWorldTrackingConfiguration.isSupported) {
    [self.session runWithConfiguration:self.configuration options:ARSessionRunOptionRemoveExistingAnchors | ARSessionRunOptionResetTracking];
  }
}

- (void)focusScene {
    [self.nodeManager.localOrigin setPosition:self.nodeManager.cameraOrigin.position];
    [self.nodeManager.localOrigin setRotation:self.nodeManager.cameraOrigin.rotation];
}

- (void)clearScene {
    [self.nodeManager clear];
}


- (SCNScene*)scene {
  return self.arView.scene;
}


#pragma mark - setter-getter

- (ARSession*)session {
  return self.arView ? self.arView.session : nil;
}

- (BOOL)debug {
  return self.arView ? self.arView.showsStatistics : true;
}


- (void)setDebug:(BOOL)debug {
  if( self.arView ){
    if (debug) {
        self.arView.showsStatistics = YES;
        self.arView.debugOptions = ARSCNDebugOptionShowWorldOrigin | ARSCNDebugOptionShowFeaturePoints;
//      self.arView.debugOptions = ARSCNDebugOptionShowWorldOrigin | ARSCNDebugOptionShowFeaturePoints | SCNDebugOptionShowPhysicsShapes;
    } else {
        self.arView.showsStatistics = NO;
        self.arView.debugOptions = SCNDebugOptionNone;
    }
  }
}

- (ARPlaneDetection)planeDetection {
    ARWorldTrackingConfiguration *configuration = (ARWorldTrackingConfiguration *) self.configuration;
    return configuration.planeDetection;
}

- (void)setPlaneDetection:(ARPlaneDetection)planeDetection {
    ARWorldTrackingConfiguration *configuration = (ARWorldTrackingConfiguration *) self.configuration;

    configuration.planeDetection = planeDetection;
    [self resume];
}

-(NSDictionary*)origin {
    return @{
             @"position": vectorToJson(self.nodeManager.localOrigin.position)
             };
}

-(void)setOrigin:(NSDictionary*)json {

    if(json[@"transition"]) {
        NSDictionary * transition =json[@"transition"];
        if(transition[@"duration"]) {
            [SCNTransaction setAnimationDuration:[transition[@"duration"] floatValue]];
        } else {
            [SCNTransaction setAnimationDuration:0.0];
        }

    } else {
        [SCNTransaction setAnimationDuration:0.0];
    }
    SCNVector3 position = [RCTConvert SCNVector3:json[@"position"]];
    [self.nodeManager.localOrigin setPosition:position];
}

- (BOOL)lightEstimationEnabled {
    ARConfiguration *configuration = self.configuration;
    return configuration.lightEstimationEnabled;
}

- (void)setLightEstimationEnabled:(BOOL)lightEstimationEnabled {
    ARConfiguration *configuration = self.configuration;
    configuration.lightEstimationEnabled = lightEstimationEnabled;
    [self resume];
}
- (void)setAutoenablesDefaultLighting:(BOOL)autoenablesDefaultLighting {
    self.arView.autoenablesDefaultLighting = autoenablesDefaultLighting;
}

- (BOOL)autoenablesDefaultLighting {
    return self.arView.autoenablesDefaultLighting;
}

- (ARWorldAlignment)worldAlignment {
    ARConfiguration *configuration = self.configuration;
    return configuration.worldAlignment;
}

- (void)setWorldAlignment:(ARWorldAlignment)worldAlignment {
    ARConfiguration *configuration = self.configuration;
    if (worldAlignment == ARWorldAlignmentGravityAndHeading) {
        configuration.worldAlignment = ARWorldAlignmentGravityAndHeading;
    } else if (worldAlignment == ARWorldAlignmentCamera) {
        configuration.worldAlignment = ARWorldAlignmentCamera;
    } else {
        configuration.worldAlignment = ARWorldAlignmentGravity;
    }
    [self resume];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110300
- (void)setDetectionImages:(NSArray*) detectionImages {

    if (@available(iOS 11.3, *)) {
        ARWorldTrackingConfiguration *configuration = self.configuration;
        NSSet *detectionImagesSet = [[NSSet alloc] init];
        for (id config in detectionImages) {
            if(config[@"resourceGroupName"]) {
                // TODO: allow bundle to be defined
                detectionImagesSet = [detectionImagesSet setByAddingObjectsFromSet:[ARReferenceImage referenceImagesInGroupNamed:config[@"resourceGroupName"] bundle:nil]];
            }
        }
        configuration.detectionImages = detectionImagesSet;
        [self resume];;
    }
}
#endif
- (NSDictionary *)readCameraPosition {
    // deprecated
    SCNVector3 cameraPosition = self.nodeManager.cameraOrigin.position;
    return vectorToJson(cameraPosition);
}

static NSDictionary * vectorToJson(const SCNVector3 v) {
    return @{ @"x": @(v.x), @"y": @(v.y), @"z": @(v.z) };
}
static NSDictionary * vector_float3ToJson(const simd_float3 v) {
    return @{ @"x": @(v.x), @"y": @(v.y), @"z": @(v.z) };
}
static NSDictionary * vector4ToJson(const SCNVector4 v) {
    return @{ @"x": @(v.x), @"y": @(v.y), @"z": @(v.z), @"w": @(v.w) };
}


- (NSDictionary *)readCamera {
    SCNVector3 position = self.arView.pointOfView.position;
    SCNVector4 rotation = self.arView.pointOfView.rotation;
    SCNVector4 orientation = self.arView.pointOfView.orientation;
    SCNVector3 eulerAngles = self.arView.pointOfView.eulerAngles;
    SCNVector3 direction = self.nodeManager.cameraDirection;
    return @{
             @"position":vectorToJson(position),
             @"rotation":vector4ToJson(rotation),
             @"orientation":vector4ToJson(orientation),
             @"eulerAngles":vectorToJson(eulerAngles),
             @"direction":vectorToJson(direction),
             };
}

- (NSDictionary *) projectAlongCamera: (NSDictionary*) nodeDict {
  // SCNVector3 point = SCNVector3Make(  [pointDict[@"x"] floatValue], [pointDict[@"y"] floatValue], [pointDict[@"z"] floatValue] );
  SCNMatrix4 nodeMat = SCNMatrix4Identity;
  SCNVector3 nodePosition = SCNVector3Zero;
  // Check if we got a position to set our matrix
  if( [nodeDict objectForKey:@"position"] ){
    nodePosition = SCNVector3Make(  [nodeDict[@"position"][@"x"] floatValue], [nodeDict[@"position"][@"y"] floatValue], [nodeDict[@"position"][@"z"] floatValue] );
    nodeMat = SCNMatrix4MakeTranslation(nodePosition.x, nodePosition.y, nodePosition.z);
  }

  // We prefer an orientation
  SCNVector4 nodeOrientation = SCNVector4Zero;
  if( [nodeDict objectForKey:@"orientation"] ){
    nodeOrientation = SCNVector4Make(
                                     [nodeDict[@"orientation"][@"x"] floatValue],
                                     [nodeDict[@"orientation"][@"y"] floatValue],
                                     [nodeDict[@"orientation"][@"z"] floatValue],
                                     [nodeDict[@"orientation"][@"w"] floatValue]
                                     );
    GLKQuaternion quat = GLKQuaternionMake(nodeOrientation.x,nodeOrientation.y, nodeOrientation.z, nodeOrientation.w);
    // Apply the position and orientation together
    nodeMat = SCNMatrix4Mult(nodeMat, SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(quat)));
  } else {
    // fall back to rotation
    SCNVector4 nodeRotation = SCNVector4Zero;
    if( [nodeDict objectForKey:@"rotation"] ){
      nodeRotation = SCNVector4Make(
                                    [nodeDict[@"rotation"][@"x"] floatValue],
                                    [nodeDict[@"rotation"][@"y"] floatValue],
                                    [nodeDict[@"rotation"][@"z"] floatValue],
                                    [nodeDict[@"rotation"][@"w"] floatValue]
                                    );
      // Apply the position and rotation together
      nodeMat = SCNMatrix4Mult(nodeMat, SCNMatrix4MakeRotation(nodeRotation.w, nodeRotation.x, nodeRotation.y, nodeRotation.z));
    } else {
      SCNVector3 nodeEulerAngles = SCNVector3Zero;
      if( [nodeDict objectForKey:@"eulerAngles"] ){
        nodeEulerAngles = SCNVector3Make(
                                         [nodeDict[@"eulerAngles"][@"x"] floatValue],
                                         [nodeDict[@"eulerAngles"][@"y"] floatValue],
                                         [nodeDict[@"eulerAngles"][@"z"] floatValue]
                                         );
        // Apply the position and rotation together
        SCNMatrix4 rotMat = SCNMatrix4MakeRotation(nodeRotation.x, 1, 0, 0);
        rotMat = SCNMatrix4Mult(nodeMat, SCNMatrix4MakeRotation(nodeRotation.y, 0, 1, 0));
        rotMat = SCNMatrix4Mult(nodeMat, SCNMatrix4MakeRotation(nodeRotation.z, 0, 0, 1));
        nodeMat = SCNMatrix4Mult(nodeMat, SCNMatrix4MakeRotation(nodeRotation.w, nodeRotation.x, nodeRotation.y, nodeRotation.z));
      }
    }
  }
  SCNVector3 position = SCNVector3Zero;
  SCNVector4 rotation = SCNVector4Zero;
  SCNVector4 orientation = SCNVector4Zero;
  SCNVector3 eulerAngles = SCNVector3Zero;

  GLKMatrix3 modelRotationMatrix = GLKMatrix4GetMatrix3(SCNMatrix4ToGLKMatrix4(nodeMat));
  GLKVector3 modelXAxis = GLKVector3Make(modelRotationMatrix.m00, modelRotationMatrix.m01, modelRotationMatrix.m02);
  GLKVector3 modelYAxis = GLKVector3Make(modelRotationMatrix.m10, modelRotationMatrix.m11, modelRotationMatrix.m12);

  const GLKVector3 yUp = modelYAxis;//GLKVector3Make(0.0, 1.0, 0.0);

  // Calculate the direction of the camera. So get the rotation and multiply it by the look forward (along the z)
  // cameraToWorld
  GLKMatrix3 camToWorldMat = GLKMatrix4GetMatrix3(SCNMatrix4ToGLKMatrix4(self.arView.pointOfView.transform));
  bool inveretable;
  GLKMatrix3 worldToCamMat = GLKMatrix3Invert(camToWorldMat, &inveretable);
  GLKVector3 cameraXAxis = GLKVector3Make(camToWorldMat.m00, camToWorldMat.m01, camToWorldMat.m02);
  // Crystal math.
  GLKVector3 camLookAtWorld = GLKMatrix3MultiplyVector3(camToWorldMat, GLKVector3Make(0.0, 0.0, -1.0));
  camLookAtWorld = GLKVector3Normalize(camLookAtWorld);

  GLKVector3 camLookUpWorld = GLKMatrix3MultiplyVector3(camToWorldMat, yUp);
  camLookUpWorld = GLKVector3Normalize(camLookUpWorld);

  GLKVector3 camLookAtCam = GLKMatrix3MultiplyVector3(worldToCamMat, GLKVector3Make(0.0, 0.0, -1.0));
  camLookAtCam = GLKVector3Normalize(camLookAtCam);

  // Get world up in camera
  GLKVector3 worldUpInCam = GLKMatrix3MultiplyVector3(worldToCamMat, yUp);
  worldUpInCam = GLKVector3Normalize(worldUpInCam);

  // Axis between node to camera in world space and camera look up in world
  GLKVector3 worldUpInCameraAndCameraUp = GLKVector3CrossProduct(worldUpInCam, yUp);
  worldUpInCameraAndCameraUp = GLKVector3Normalize(worldUpInCameraAndCameraUp);

  // Get the full projected position by rotating the nodePosition in camera space with the cam transform 4x4
  GLKVector4 full = GLKMatrix4MultiplyVector4(
                                              SCNMatrix4ToGLKMatrix4(self.arView.pointOfView.transform),
                                              GLKVector4Make(nodePosition.x, nodePosition.y, nodePosition.z, 1.0));
  position = SCNVector3Make(full.x, full.y, full.z);
  
  SCNNode* groupNode = [SCNNode node];
  SCNNode* cameraNode = [SCNNode node];
  [groupNode addChildNode:cameraNode];
  cameraNode.transform = self.arView.pointOfView.transform;
  
  // TODO: figure out wtf is going on with model placement along projected camera
  // Just using the camera for now until we get the model rotation placement issue sorted out
  if( true ){
    SCNNode* tmpNode = [SCNNode node];
    tmpNode.position = SCNVector3Make(nodePosition.x,
                                      nodePosition.y,
                                      nodePosition.z);
    [cameraNode addChildNode:tmpNode];

//      tmpNode.transform = SCNMatrix4MakeTranslation(
//                                              nodePosition.x,
//                                              nodePosition.y,
//                                              nodePosition.z
//                                              );

    position = tmpNode.worldPosition;
    orientation = tmpNode.worldOrientation;
  } else {
    // Rotate the node in camera space to match the y up vector of the world
    GLKQuaternion quat;
    
    // Get the full projected position by rotating the nodePosition in camera space with the cam transform 4x4
    GLKVector4 full = GLKMatrix4MultiplyVector4(
                                                SCNMatrix4ToGLKMatrix4(self.arView.pointOfView.transform),
                                                GLKVector4Make(nodePosition.x, nodePosition.y, nodePosition.z, 1.0));
    SCNVector3 nodeWorldPosition = SCNVector3Make(full.x, full.y, full.z);
    
    SCNVector3 cameraPosition = self.arView.pointOfView.position;
    GLKVector3 nodeToCamWorldVector = GLKVector3Subtract(
                                                         SCNVector3ToGLKVector3(nodeWorldPosition),
                                                         SCNVector3ToGLKVector3(cameraPosition)
                                                         );
    nodeToCamWorldVector = GLKVector3Normalize(nodeToCamWorldVector);
    
    
    GLKVector3 axis = GLKVector3CrossProduct(camLookAtCam, worldUpInCam);
    axis = GLKVector3Normalize(axis);
    GLKVector3 upDiffInCam = GLKVector3Subtract(worldUpInCam,
                                                yUp);
    float pitchRads = acos(GLKVector3DotProduct(
                                                yUp,
                                                worldUpInCam
                                                )/ (
                                                    GLKVector3Length(yUp) * GLKVector3Length(worldUpInCam)
                                                    )
                           );
    quat = GLKQuaternionMakeWithAngleAndAxis(pitchRads, axis.x, axis.y, axis.z);
    
    SCNNode* tmpNode = [SCNNode node];
    [groupNode addChildNode:tmpNode];
    
    [cameraNode addChildNode:tmpNode];
    //   tmpNode.transform = nodeMat;
    //  tmpNode.rotation = SCNVector4Make(axis.x, axis.y, axis.z, pitchRads);
    tmpNode.transform = SCNMatrix4Mult(
                                       SCNMatrix4MakeRotation(pitchRads, axis.x, axis.y, axis.z),
                                       nodeMat
                                       );
    
    //  tmpNode.position = SCNVector3Make(nodePosition.x,
    //                                    nodePosition.y,
    //                                    nodePosition.z);
    //  tmpNode.orientation = SCNVector4Make(quat.x, quat.y, quat.z, quat.w);
    //  tmpNode.transform = SCNMatrix4Translate(
    //                                          SCNMatrix4MakeRotation(pitchRads, axis.x, axis.y, axis.z),
    //
    //                                          );
    //  tmpNode.orientation = SCNVector4Make(-1,0,0,0.7853982);
    //
    
    NSLog(@"project: \n\n");
    NSLog(@"\nproject full clc position:\t% 01.2f\t% 01.2f\t% 01.2f\n", nodeWorldPosition.x, nodeWorldPosition.y, nodeWorldPosition.z);
    NSLog(@"\nproject tmpNode position:\t% 01.2f\t% 01.2f\t% 01.2f\n", tmpNode.position.x, tmpNode.position.y, tmpNode.position.z);
    NSLog(@"\nproject tmpNode world po:\t% 01.2f\t% 01.2f\t% 01.2f\n", tmpNode.worldPosition.x, tmpNode.worldPosition.y, tmpNode.worldPosition.z);
    
    rotation = tmpNode.rotation;
    orientation = tmpNode.worldOrientation;
    eulerAngles = tmpNode.eulerAngles;
    
    //  SCNVector3 modelYToCamera = [tmpNode convertVector:SCNVector3FromGLKVector3(modelYAxis) toNode:cameraNode];
    //  NSLog(@"project modelYToCamera:\t% 01.2f, % 01.2f, % 01.2f", modelYToCamera.x, modelYToCamera.y, modelYToCamera.z);
    
    NSLog(@"\nproject tmpNode rotation:\t% 01.2f, % 01.2f, % 01.2f, % 01.2f\n", tmpNode.rotation.x, tmpNode.rotation.y, tmpNode.rotation.z, tmpNode.rotation.w);
    NSLog(@"\nproject tmpNode world orine:\t% 01.2f, % 01.2f, % 01.2f, % 01.2f\n", tmpNode.worldOrientation.x, tmpNode.worldOrientation.y, tmpNode.worldOrientation.z, tmpNode.worldOrientation.w);
    NSLog(@"\nproject tmpNode orientation:\t% 01.2f, % 01.2f, % 01.2f, % 01.2f\n", tmpNode.orientation.x, tmpNode.orientation.y, tmpNode.orientation.z, tmpNode.orientation.w);
    
  }
  return @{
           @"position":vectorToJson(position),
           @"rotation":vector4ToJson(rotation),
           @"orientation":vector4ToJson(orientation),
           //           @"eulerAngles":vectorToJson(eulerAngles),
           };
}

- (SCNVector3)projectPoint:(SCNVector3)point {
  return SCNVector3Zero;
    return [self.arView projectPoint:[self.nodeManager getAbsolutePositionToOrigin:point]];

}



- (float)getCameraDistanceToPoint:(SCNVector3)point {
    return [self.nodeManager getCameraDistanceToPoint:point];
}

- (float)getDistanceBetweenPoints:(SCNVector3)point pointTwo:(SCNVector3)pointTwo {

  return [self getDistanceBetweenPoints:point pointTwo:pointTwo];
}

//-(NSString *)sideClosestToNode:(NSString)nodeId {
//  return
//}


- (bool)getNodeVisibility:(NSString *)nodeId {
  SCNNode *node = [self.nodeManager getNodeWithId:nodeId];
  return [self.arView isNodeInsideFrustum:node withPointOfView:self.arView.pointOfView];
}

- (void)moveNodeToCamera:(NSString *)nodeId {
  SCNNode *node = [self.nodeManager getNodeWithId:nodeId];
  [self.arView.pointOfView addChildNode:node];
}



#pragma mark - Lazy loads

-(ARWorldTrackingConfiguration *)configuration {
    if (_configuration) {
        return _configuration;
    }

    if (!ARWorldTrackingConfiguration.isSupported) {}

    _configuration = [ARWorldTrackingConfiguration new];
    
    _configuration.environmentTexturing = AREnvironmentTexturingAutomatic;
    _configuration.planeDetection = ARPlaneDetectionHorizontal;
    return _configuration;
}



#pragma mark - snapshot methods

- (void)hitTestSceneObjects:(const CGPoint)tapPoint resolve:(RCTARKitResolve)resolve reject:(RCTARKitReject)reject {

    resolve([self.nodeManager getSceneObjectsHitResult:tapPoint]);
}


- (UIImage *)getSnapshot:(NSDictionary *)selection {
    UIImage *image = [self.arView snapshot];


    return [self cropImage:image toSelection:selection];

}





- (UIImage *)getSnapshotCamera:(NSDictionary *)selection {
    CVPixelBufferRef pixelBuffer = self.arView.session.currentFrame.capturedImage;
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];

    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 CVPixelBufferGetWidth(pixelBuffer),
                                                 CVPixelBufferGetHeight(pixelBuffer))];

    UIImage *image = [UIImage imageWithCGImage:videoImage scale: 1.0 orientation:UIImageOrientationRight];
    CGImageRelease(videoImage);

    UIImage *cropped = [self cropImage:image toSelection:selection];
    return cropped;

}



- (UIImage *)cropImage:(UIImage *)imageToCrop toRect:(CGRect)rect
{
    //CGRect CropRect = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height+15);

    CGImageRef imageRef = CGImageCreateWithImageInRect([imageToCrop CGImage], rect);
    UIImage *cropped = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);

    return cropped;
}

static inline double radians (double degrees) {return degrees * M_PI/180;}
UIImage* rotate(UIImage* src, UIImageOrientation orientation)
{
    UIGraphicsBeginImageContext(src.size);

    CGContextRef context = UIGraphicsGetCurrentContext();
    [src drawAtPoint:CGPointMake(0, 0)];
    if (orientation == UIImageOrientationRight) {
        CGContextRotateCTM (context, radians(90));
    } else if (orientation == UIImageOrientationLeft) {
        CGContextRotateCTM (context, radians(-90));
    } else if (orientation == UIImageOrientationDown) {
        // NOTHING
    } else if (orientation == UIImageOrientationUp) {
        CGContextRotateCTM (context, radians(90));
    }



    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
- (UIImage *)cropImage:(UIImage *)imageToCrop toSelection:(NSDictionary *)selection
{

    // selection is in view-coordinate system
    // where as the image is a camera picture with arbitary size
    // also, the camera picture is cut of so that it "covers" the self.bounds
    // if selection is nil, crop to the viewport

    UIImage * image = rotate(imageToCrop, imageToCrop.imageOrientation);

    float arViewWidth = self.bounds.size.width;
    float arViewHeight = self.bounds.size.height;
    float imageWidth = image.size.width;
    float imageHeight = image.size.height;

    float arViewRatio = arViewHeight/arViewWidth;
    float imageRatio = imageHeight/imageWidth;
    float imageToArWidth = imageWidth/arViewWidth;
    float imageToArHeight = imageHeight/arViewHeight;

    float finalHeight;
    float finalWidth;


    if (arViewRatio > imageRatio)
    {
        finalHeight = arViewHeight*imageToArHeight;
        finalWidth = arViewHeight*imageToArHeight /arViewRatio;
    }
    else
    {
        finalWidth = arViewWidth*imageToArWidth;
        finalHeight = arViewWidth * imageToArWidth * arViewRatio;
    }

    float topOffset = (image.size.height - finalHeight)/2;
    float leftOffset = (image.size.width - finalWidth)/2;


    float x = leftOffset;
    float y = topOffset;
    float width = finalWidth;
    float height = finalHeight;
    if(selection && selection != [NSNull null]) {
        x = leftOffset+ [selection[@"x"] floatValue]*imageToArWidth;
        y = topOffset+[selection[@"y"] floatValue]*imageToArHeight;
        width = [selection[@"width"] floatValue]*imageToArWidth;
        height = [selection[@"height"] floatValue]*imageToArHeight;
    }
    CGRect rect = CGRectMake(x, y, width, height);

    UIImage *cropped = [self cropImage:image toRect:rect];
    return cropped;
}


#pragma mark - plane hit detection

- (void)hitTestPlane:(const CGPoint)tapPoint types:(ARHitTestResultType)types resolve:(RCTARKitResolve)resolve reject:(RCTARKitReject)reject {

    resolve([self getPlaneHitResult:tapPoint types:types]);
}



static NSDictionary * getPlaneHitResult(NSMutableArray *resultsMapped, const CGPoint tapPoint) {
    return @{
             @"results": resultsMapped
             };
}


- (NSDictionary *)getPlaneHitResult:(const CGPoint)tapPoint  types:(ARHitTestResultType)types; {
    NSArray<ARHitTestResult *> *results = [self.arView hitTest:tapPoint types:types];
    NSMutableArray * resultsMapped = [self.nodeManager mapHitResults:results];
    NSDictionary *planeHitResult = getPlaneHitResult(resultsMapped, tapPoint);
    return planeHitResult;
}

- (void)handleTapFrom: (UITapGestureRecognizer *)recognizer {
    // Take the screen space tap coordinates and pass them to the hitTest method on the ARSCNView instance
    CGPoint tapPoint = [recognizer locationInView:self.arView];
    //
    if(self.onTapOnPlaneUsingExtent) {
        // Take the screen space tap coordinates and pass them to the hitTest method on the ARSCNView instance
        NSDictionary * planeHitResult = [self getPlaneHitResult:tapPoint types:ARHitTestResultTypeExistingPlaneUsingExtent];
        self.onTapOnPlaneUsingExtent(planeHitResult);
    }

    if(self.onTapOnPlaneNoExtent) {
        // Take the screen space tap coordinates    and pass them to the hitTest method on the ARSCNView instance
        NSDictionary * planeHitResult = [self getPlaneHitResult:tapPoint types:ARHitTestResultTypeExistingPlane];
        self.onTapOnPlaneNoExtent(planeHitResult);
    }
}



#pragma mark - ARSCNViewDelegate

- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time {
    for (id<RCTARKitRendererDelegate> rendererDelegate in self.rendererDelegates) {
        if ([rendererDelegate respondsToSelector:@selector(renderer:updateAtTime:)]) {
            [rendererDelegate renderer:renderer updateAtTime:time];
        }
    }
}



- (void)renderer:(id <SCNSceneRenderer>)renderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time {
    for (id<RCTARKitRendererDelegate> rendererDelegate in self.rendererDelegates) {
        if ([rendererDelegate respondsToSelector:@selector(renderer:didRenderScene:atTime:)]) {
            [rendererDelegate renderer:renderer didRenderScene:scene atTime:time];
        }
    }
}




- (NSDictionary *)makeAnchorDetectionResult:(SCNNode *)node anchor:(ARAnchor *)anchor {
    NSDictionary* baseProps = @{
                                @"id": anchor.identifier.UUIDString,
                                @"type": @"unkown",
                                @"eulerAngles":vectorToJson(node.eulerAngles),
                                @"position": vectorToJson([self.nodeManager getRelativePositionToOrigin:node.position]),
                                @"positionAbsolute": vectorToJson(node.position)
                                };
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:baseProps];

    if([anchor isKindOfClass:[ARPlaneAnchor class]]) {
        ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;
        NSDictionary * planeProperties = [self makePlaneAnchorProperties:planeAnchor];
        [dict addEntriesFromDictionary:planeProperties];
    } else if (@available(iOS 11.3, *)) {
        #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110300
        if([anchor isKindOfClass:[ARImageAnchor class]]) {
            ARImageAnchor *imageAnchor = (ARImageAnchor *)anchor;
            NSDictionary * imageProperties = [self makeImageAnchorProperties:imageAnchor];
            [dict addEntriesFromDictionary:imageProperties];
        }
        #endif
    } else {
        // Fallback on earlier versions
    }
    return dict;
}


- (NSDictionary *)makePlaneAnchorProperties:(ARPlaneAnchor *)planeAnchor {
    return @{
             @"type": @"plane",
             @"alignment": @(planeAnchor.alignment),
             @"center": vector_float3ToJson(planeAnchor.center),
             @"extent": vector_float3ToJson(planeAnchor.extent)
             };

}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110300
- (NSDictionary *)makeImageAnchorProperties:(ARImageAnchor *)imageAnchor  API_AVAILABLE(ios(11.3)){
    return @{
             @"type": @"image",
             @"image": @{
                     @"name": imageAnchor.referenceImage.name
                     }

             };

}
  #endif

- (void)addRendererDelegates:(id) delegate {
     [self.rendererDelegates addObject:delegate];
    NSLog(@"added, number of renderer delegates %d", [self.rendererDelegates count]);
}

- (void)removeRendererDelegates:(id) delegate {
    [self.rendererDelegates removeObject:delegate];
     NSLog(@"removed, number of renderer delegates %d", [self.rendererDelegates count]);
}
- (void)renderer:(id <SCNSceneRenderer>)renderer willUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
}


- (void)renderer:(id <SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {

    NSDictionary *anchorDict = [self makeAnchorDetectionResult:node anchor:anchor];

    if (self.onPlaneDetected && [anchor isKindOfClass:[ARPlaneAnchor class]]) {
        self.onPlaneDetected(anchorDict);
    } else if (self.onAnchorDetected) {
        self.onAnchorDetected(anchorDict);
    }

}

- (void)renderer:(id <SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    NSDictionary *anchorDict = [self makeAnchorDetectionResult:node anchor:anchor];

    if (self.onPlaneUpdated && [anchor isKindOfClass:[ARPlaneAnchor class]]) {
        self.onPlaneUpdated(anchorDict);
    }else if (self.onAnchorUpdated) {
        self.onAnchorUpdated(anchorDict);
    }

}

- (void)renderer:(id<SCNSceneRenderer>)renderer didRemoveNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    NSDictionary *anchorDict = [self makeAnchorDetectionResult:node anchor:anchor];

    if (self.onPlaneRemoved && [anchor isKindOfClass:[ARPlaneAnchor class]]) {
        self.onPlaneRemoved(anchorDict);
    } else if (self.onAnchorRemoved) {
        self.onAnchorRemoved(anchorDict);
    }
}




#pragma mark - ARSessionDelegate

- (ARFrame * _Nullable)currentFrame {
//    return self.arView.session.currentFrame;
  return nil;
}

- (NSDictionary *)getCurrentLightEstimation {
    return [self wrapLightEstimation:[self currentFrame].lightEstimate];
}

- (NSMutableArray *)getCurrentDetectedFeaturePoints {
    NSMutableArray * featurePoints = [NSMutableArray array];
    for (int i = 0; i < [self currentFrame].rawFeaturePoints.count; i++) {
        vector_float3 positionV = [self currentFrame].rawFeaturePoints.points[i];
        SCNVector3 position = [self.nodeManager getRelativePositionToOrigin:SCNVector3Make(positionV[0],positionV[1],positionV[2])];
        NSString * pointId = [NSString stringWithFormat:@"featurepoint_%lld",[self currentFrame].rawFeaturePoints.identifiers[i]];

        [featurePoints addObject:@{
                                   @"x": @(position.x),
                                   @"y": @(position.y),
                                   @"z": @(position.z),
                                   @"id":pointId,
                                   }];

    }
    return featurePoints;
}

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    for (id<RCTARKitSessionDelegate> sessionDelegate in self.sessionDelegates) {
        if ([sessionDelegate respondsToSelector:@selector(session:didUpdateFrame:)]) {
            [sessionDelegate session:session didUpdateFrame:frame];
        }
    }
    if (self.onFeaturesDetected) {
        NSArray * featurePoints = [self getCurrentDetectedFeaturePoints];
        dispatch_async(dispatch_get_main_queue(), ^{


            if(self.onFeaturesDetected) {
                self.onFeaturesDetected(@{
                                          @"featurePoints":featurePoints
                                          });
            }
        });
    }

    if (self.lightEstimationEnabled && self.onLightEstimation) {
        /** this is called rapidly and is therefore demanding, better poll it from outside with getCurrentLightEstimation **/



        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.onLightEstimation) {
                NSDictionary *estimate = [self getCurrentLightEstimation];
                self.onLightEstimation(estimate);
            }
        });

    }

}

- (NSDictionary *)wrapLightEstimation:(ARLightEstimate *)estimate {
    if(!estimate) {
        return nil;
    }
    return @{
             @"ambientColorTemperature":@(estimate.ambientColorTemperature),
             @"ambientIntensity":@(estimate.ambientIntensity),
             };
}



- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
    if (self.onTrackingState) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onTrackingState(@{
                                   @"state": @(camera.trackingState),
                                   @"reason": @(camera.trackingStateReason)
                                   });
        });
    }
}



#pragma mark - RCTARKitTouchDelegate

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    for (id<RCTARKitTouchDelegate> touchDelegate in self.touchDelegates) {
        if ([touchDelegate respondsToSelector:@selector(touches:beganWithEvent:)]) {
            [touchDelegate touches:touches beganWithEvent:event];
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    for (id<RCTARKitTouchDelegate> touchDelegate in self.touchDelegates) {
        if ([touchDelegate respondsToSelector:@selector(touches:movedWithEvent:)]) {
            [touchDelegate touches:touches movedWithEvent:event];
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    for (id<RCTARKitTouchDelegate> touchDelegate in self.touchDelegates) {
        if ([touchDelegate respondsToSelector:@selector(touches:endedWithEvent:)]) {
            [touchDelegate touches:touches endedWithEvent:event];
        }
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    for (id<RCTARKitTouchDelegate> touchDelegate in self.touchDelegates) {
        if ([touchDelegate respondsToSelector:@selector(touches:cancelledWithEvent:)]) {
            [touchDelegate touches:touches cancelledWithEvent:event];
        }
    }
}



#pragma mark - dealloc
-(void) dealloc {
}

@end
