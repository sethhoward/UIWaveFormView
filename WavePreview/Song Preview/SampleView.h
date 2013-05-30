//
//  SNDView.h
//  MediaLibraryExportThrowaway1
//
//  Created by Seth Howard on 11/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

//TODO: this class needs control of the sliders

@class AVAsset;
@interface SampleView : UIView {
	//float *_data;		//samples

	
	
	//temp public... at least until we move the scrollView
//	SNDViewHUD *hud;	//our hud view.. time.. book marks
	int startIndex;		//where does the wav start drawing
	
@private
	float _runningTime;	//in seconds
	int _dataCount;		//how many indexes of data do we have
	float compressionValue;	//how many samples are we skipping to draw waveform... should be called displayCompressionValue
	
	
	float scalarX;
//	float lastScale;

	int startSample;
	int endSample;		//where does the wav stop drawing
	
	
	//TODO: these are weak slider references... sliders should be moved to this class and out of the sampler view
//	UISlider *_leftSlider;
//	UISlider *_rightSlider;
	
	BOOL isZooming;
	int zoomDirection;
	float _scaleY;
}

//- (void)drawSample:(float *)sampleData withArrayLength:(int)length;
- (void)drawSample:(float *)sampleData withArrayLength:(int)length;
- (void)drawSample:(float *)data withArrayLength:(int)length withStartTime:(float)startSeconds andEndTime:(float)endSeconds;
- (void)drawWithAssetURL:(NSURL *)url;

- (float)getTimeForPixelPoint:(float)point;
- (float)getUncompressedIndex;
- (float)getPixelPointForTime:(float)time;
- (void)updatePlayHead:(float)time;
- (float)getLeftPlayHeadTime;
- (float)getRightPlayHeadTime;
- (float)visibleTime;
- (float)getPixelPointForTime:(float)time withStartOffset:(float)pixelOffset;
- (float)getTimeForPixelPoint:(float)point withStartOffset:(float)pixelOffset;
- (void)setOffset:(int)xCoordOffset;
- (float)getTimeForSampleIndex:(float)sampleIndex;


- (NSTimeInterval)getTimeBetweenBookMarks;

//private
- (void)setLeftPlayHeadIndicator:(float)atXCoord;
- (void)setRightPlayHeadIndicator:(float)atXCoord;
- (int)visibleSamples;

//- (float)getPixelPointForTimeTemp:(float)time;

@property (nonatomic, strong) UIColor *waveFormColor;

//@property float *data;
@property (nonatomic, assign) UISlider *leftSlider;
@property (nonatomic, assign) UISlider *rightSlider;

//@property (readonly) float runningTime;

//@property (nonatomic, retain) SNDViewHUD *hud;
@property int startIndex;

@end
