//
//  CineBroadcasterViewController.m
//  Broadcaster
//
//  Created by Jeffrey Wescott on 6/4/14.
//  Copyright (c) 2014 cine.io. All rights reserved.
//

#import "CineBroadcasterViewController.h"
#import <cineio/CineIO.h>
#import <AVFoundation/AVFoundation.h>

@interface CineBroadcasterViewController ()
{
    CineClient *_cine;
    CineStream *_stream;
}

@end

@implementation CineBroadcasterViewController

@synthesize broadcasterView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.broadcasterView.controlsView.recordButton.button addTarget:self action:@selector(onRecord:) forControlEvents:UIControlEventTouchUpInside];

    // cine.io setup
    NSString *path = [[NSBundle mainBundle] pathForResource:@"cineio-settings" ofType:@"plist"];
    NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:path];
    NSLog(@"settings: %@", settings);
    _cine = [[CineClient alloc] initWithSecretKey:settings[@"CINE_IO_SECRET_KEY"]];
    broadcasterView.status.text = [NSString stringWithFormat:@"Getting cine.io stream info"];
    [_cine getStream:settings[@"CINE_IO_STREAM_ID"] withCompletionHandler:^(NSError *error, CineStream *stream) {
        if (error) {
            NSLog(@"Couldn't get stream information from cine.io.");
            broadcasterView.status.text = @"ERROR: couldn't get stream information from cine.io";
        } else {
            _stream = stream;
            broadcasterView.controlsView.recordButton.enabled = YES;
            broadcasterView.status.text = @"Ready";
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL) prefersStatusBarHidden {
    return YES;
}

- (IBAction)onRecord:(id)sender
{
    NSLog(@"Record touched");
    
    if (!broadcasterView.controlsView.recordButton.recording) {
        broadcasterView.controlsView.recordButton.recording = YES;
        NSString* rtmpUrl = [NSString stringWithFormat:@"%@/%@", [_stream publishUrl], [_stream publishStreamName]];
        
        NSLog(@"%@", rtmpUrl);
        broadcasterView.status.text = [NSString stringWithFormat:@"Connecting to %@", rtmpUrl];

        
        pipeline.reset(new Broadcaster::CineBroadcasterPipeline([self](Broadcaster::SessionState state){
            [self connectionStatusChange:state];
        }));
        
        
        pipeline->setPBCallback([=](const uint8_t* const data, size_t size) {
            [self gotPixelBuffer: data withSize: size];
        });
        
        pipeline->startRtmpSession([rtmpUrl UTF8String], 1280, 720, 1500000 /* video bitrate */, 30 /* video fps */);
    } else {
        broadcasterView.controlsView.recordButton.recording = NO;
        // disconnect
        pipeline.reset();
        NSLog(@"Stopped");
        broadcasterView.status.text = @"Stopped";
    }
}

- (void) connectionStatusChange:(Broadcaster::SessionState) state
{
    NSLog(@"Connection status: %d", state);
    if(state == Broadcaster::kSessionStateStarted) {
        NSLog(@"Connected");
        broadcasterView.status.text = [NSString stringWithFormat:@"Connected"];
    } else if(state == Broadcaster::kSessionStateError || state == Broadcaster::kSessionStateEnded) {
        NSLog(@"Disconnected");
        broadcasterView.status.text = [NSString stringWithFormat:@"Disconnected"];
        pipeline.reset();
    }
}

- (void) gotPixelBuffer: (const uint8_t* const) data withSize: (size_t) size {
    // TODO (JW): need this @autoreleasepool?
    @autoreleasepool {
        CVPixelBufferRef pb = (CVPixelBufferRef) data;
        float width = CVPixelBufferGetWidth(pb);
        float height = CVPixelBufferGetHeight(pb);
        CVPixelBufferLockBaseAddress(pb, 1);
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pb];
        
        CIContext *temporaryContext = [CIContext contextWithOptions:nil];
        CGImageRef videoImage = [temporaryContext
                                 createCGImage:ciImage
                                 fromRect:CGRectMake(0, 0, width, height)];
        
        UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
        CVPixelBufferUnlockBaseAddress(pb, 0);
        
        [broadcasterView.cameraView performSelectorOnMainThread:@selector(setImage:) withObject:uiImage waitUntilDone:NO];
        
        CGImageRelease(videoImage);
    }
}
@end
