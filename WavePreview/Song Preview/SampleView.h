//
//  SNDView.h
//
//  Created by Seth Howard on 11/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVAsset, SampleView;
@protocol SampleViewDelegate <NSObject>
@optional
- (void)sampleView:(SampleView *)sampleView samplesProcessed:(int)samplesProcessed;
- (void)sampleView:(SampleView *)sampleView totalSamplesToProcess:(int)totalSamples;
- (void)sampleViewWaveLoaded:(SampleView *)sampleView;
- (void)sampleViewWaveDisplayed:(SampleView *)sampleView;
- (void)sampleView:(SampleView *)sampleView hasScrolled:(UIScrollView *)scrollView;
- (void)sampleView:(SampleView *)sampleView hasZoomed:(UIPinchGestureRecognizer *)pinchGesture;
@end


@interface SampleView : UIView

- (void)drawWithAssetURL:(NSURL *)url;

- (float)getTimeForPixelPoint:(float)point;
- (float)getUncompressedIndex;
- (float)getPixelPointForTime:(float)time;
- (float)visibleTime;
- (float)getPixelPointForTime:(float)time withStartOffset:(float)pixelOffset;
- (float)getTimeForPixelPoint:(float)point withStartOffset:(float)pixelOffset;
- (float)getTimeForSampleIndex:(float)sampleIndex;
- (int)getLastVisibleIndex;

@property (nonatomic, strong) UIColor *waveOutlineColor;
@property (nonatomic, strong) UIColor *waveFillColor;
@property (nonatomic, readonly) int sampleCount;      //how many indexes of data do we have
@property (nonatomic, readonly) NSTimeInterval runningTime;	//in seconds
@property (nonatomic, assign) id<SampleViewDelegate> delegate;

@end
