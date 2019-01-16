//
//  RCTARKitSixDegreesView.m
//  RCTARKit
//
//  Created by H. Cole Wiley on 1/15/19.
//  Copyright © 2019 Scandy LLC. All rights reserved.
//

#import "RCTARKitSixDegreesView.h"

#import "RCTARSixDegreesMeshController.h"

#import <SixDegreesSDK/SixDegreesSDK.h>
#import <SixDegreesSDK/SixDegreesSDK_advanced.h>


typedef struct
{
  vector_float2 position;
  vector_float2 textureCoordinates;
} InputVertex;


@interface RCTARKitSixDegreesView () <MTKViewDelegate>{
  bool _isInitialized;

  id<MTLRenderPipelineState> _pipelineState;
  id<MTLCommandQueue> _commandQueue;
  id<MTLTexture> _texture;
  id<MTLBuffer> _vertices;
  NSUInteger _numVertices;
  int _texWidth;
  int _texHeight;
  CGRect _viewport;

  RCTARSixDegreesMeshController* _meshController;
  SCNScene* _scene;
  SCNNode* _cameraNode;
  SCNRenderer* _renderer;
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
    [self setupARKit];
    [self setupSceneKit];
  }
  return self;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
  if (!_isInitialized) {
    _isInitialized = SixDegreesSDK_IsInitialized();
    return;
  } else if (_texture == nil) {
    [self setupMetal];
    return;
  } else if (_scene == nil) {
    [self setupSceneKit];
    return;
  }

  [self onFrameUpdate];

  MTLRenderPassDescriptor *viewRenderPassDescriptor = view.currentRenderPassDescriptor;
  if (!viewRenderPassDescriptor) return;

  { // background
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"BackgroundCommand";
    id<MTLRenderCommandEncoder> renderEncoder =
    [commandBuffer renderCommandEncoderWithDescriptor:viewRenderPassDescriptor];
    renderEncoder.label = @"BackgroundRenderEncoder";

    [renderEncoder setViewport:(MTLViewport){_viewport.origin.x, _viewport.origin.y, _viewport.size.width, _viewport.size.height, -1.0, 1.0 }];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setVertexBuffer:_vertices
                            offset:0
                           atIndex:0];

    [renderEncoder setFragmentTexture:_texture
                              atIndex:0];

    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:_numVertices];

    [renderEncoder endEncoding];
    [commandBuffer commit];
  }

  { // scene
     [_meshController update];

    GLKMatrix4 pose;
    int trackingQuality = SixDegreesSDK_GetPose(pose.m, 16);
    if (trackingQuality == SixDegreesTrackingQualityGood) {
      SCNMatrix4 matrix = SCNMatrix4FromGLKMatrix4(pose);
      [_cameraNode setWorldTransform:matrix];

      GLKMatrix4 projection;
      SixDegreesSDK_GetProjection(projection.m, 16);
      matrix = SCNMatrix4FromGLKMatrix4(projection);
      // for portrait rotate this b -90 degrees (-PI/2)
      float negpi = -M_PI_2;
      SCNMatrix4 projmatrix = SCNMatrix4Rotate(matrix, negpi, 0, 0, 1);

      [_cameraNode.camera setProjectionTransform:projmatrix];
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"SceneRendererCommand";
    MTLRenderPassDescriptor* renderPassDescriptor = [MTLRenderPassDescriptor new];
    [renderPassDescriptor.colorAttachments[0] setTexture:self.currentDrawable.texture];
    [renderPassDescriptor.colorAttachments[0] setLoadAction:MTLLoadActionLoad];
    [renderPassDescriptor.colorAttachments[0] setStoreAction:MTLStoreActionStore];
    [_renderer renderAtTime:CFAbsoluteTimeGetCurrent()
                   viewport:_viewport
              commandBuffer:commandBuffer
             passDescriptor:renderPassDescriptor];
    [commandBuffer presentDrawable:self.currentDrawable];
    [commandBuffer commit];
  }
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
  _viewport = CGRectMake(0.f, 0.f, size.width, size.height);
  // make the viewport bigger than the drawable area to avoid letterboxing
  //    if (size.width * 9 > size.height * 16) {
  //        _viewport.size.height = size.width * 9.f / 16.f;
  //        _viewport.origin.y = (size.height - _viewport.size.height) / 2.f;
  //    } else if (size.width * 9 < size.height * 16) {
  // for portrait
  _viewport.size.width = size.height * 9.f / 16.f;
  _viewport.origin.x = (size.width - _viewport.size.width) / 2.f;
  //    }
}

- (SCNScene*)scene {
  return _scene;
}

- (void)setupARKit {
  if( !_isInitialized ){
    char version[16];
    SixDegreesSDK_GetVersion(version, 16);
    NSLog(@"Initializing 6D SDK version %s", version);
    
    // Create a custom ARKit configuration that enables plane detection
    ARWorldTrackingConfiguration* config = [ARWorldTrackingConfiguration new];
    if (@available(iOS 11.3, *)) {
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
    } else {
      // Fallback on earlier versions
    }
    SixDegreesSDK_InitializeWithConfig(config);
  }
}


- (void)setupMetal {
  void* texPtr = SixDegreesSDK_GetBackgroundTexture();
  if (!texPtr) return;

  _texture = (__bridge id<MTLTexture>)texPtr;

  SixDegreesSDK_GetBackgroundTextureSize(&_texWidth, &_texHeight);

  const InputVertex vertices[] =
  {

    //   viewport coords,   tex coords
    //    //  landscape
    //        { {  1.f, -1.f },  { 1.f, 1.f } },
    //        { { -1.f, -1.f },  { 0.f, 1.f } },
    //        { { -1.f,  1.f },  { 0.f, 0.f } },
    //
    //        { {  1.f, -1.f },  { 1.f, 1.f } },
    //        { { -1.f,  1.f },  { 0.f, 0.f } },
    //        { {  1.f,  1.f },  { 1.f, 0.f } },

    //  portrait
    { {  1.f, -1.f },  { 1.f, 0.f } },
    { { -1.f, -1.f },  { 1.f, 1.f } },
    { { -1.f,  1.f },  { 0.f, 1.f } },

    { {  1.f, -1.f },  { 1.f, 0.f } },
    { { -1.f,  1.f },  { 0.f, 1.f } },
    { {  1.f,  1.f },  { 0.f, 0.f } },
  };

  _vertices = [self.device newBufferWithBytes:vertices
                                       length:sizeof(vertices)
                                      options:MTLResourceStorageModeShared];

  _numVertices = sizeof(vertices) / sizeof(InputVertex);

  id<MTLLibrary> defaultLibrary = [self.device newDefaultLibrary];
  id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"simpleVertex"];
  id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"simpleTexture"];

  MTLRenderPipelineDescriptor *pipelineStateDescriptor = [MTLRenderPipelineDescriptor new];
  pipelineStateDescriptor.label = @"Texturing Pipeline";
  pipelineStateDescriptor.vertexFunction = vertexFunction;
  pipelineStateDescriptor.fragmentFunction = fragmentFunction;
  pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;

  NSError *error = NULL;
  _pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                               error:&error];
  if (!_pipelineState)
  {
    NSLog(@"Failed to created pipeline state, error %@", error);
  }

  _commandQueue = [self.device newCommandQueue];

  [self mtkView:self drawableSizeWillChange:self.drawableSize];
}


- (void)setupSceneKit {
  _meshController = [RCTARSixDegreesMeshController sharedInstance];

  _scene = [SCNScene new];
  [_scene setFogColor:[UIColor colorWithWhite:0.7 alpha:0.2]];
  [_scene setFogStartDistance:2.0];
  [_scene setFogEndDistance:20.0];

  _cameraNode = [SCNNode new];
  [_cameraNode setCamera:[SCNCamera new]];
  [_scene.rootNode addChildNode:_cameraNode];
  [_scene.rootNode addChildNode:_meshController.meshNode];

  _renderer = [SCNRenderer rendererWithDevice:self.device
                                      options:nil];
  [_renderer setScene:_scene];
  [_renderer setPointOfView:_cameraNode];
  [_renderer setAutoenablesDefaultLighting:YES];
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
