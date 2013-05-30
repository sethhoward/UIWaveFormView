//
//  SNDView.m
//  MediaLibraryExportThrowaway1
//
//  Created by Seth Howard on 11/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "SampleView.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

//#import "SNDViewHUD.h"

//When do we stop mirroring the wave drawing?
#define kAllowForDoubleDrawValue 0.4f
#define kCompressionValue	128.0f
#define k44100Sample	 44100.0f
#define kTimeDisplayIncrement 45

//forward declarations of private variables
@interface SampleView() <UIScrollViewDelegate>
@property int dataCount;
@property (nonatomic, strong) UIScrollView *scrollView;
// - (void)refreshPlayHeadBookmarks;

@end


@implementation SampleView {
    @private
    float *_dataBuffer;
    float *_samplesToDisplay;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self prepare];
    }
    return self;
}
 
- (id)initWithCoder:(NSCoder *)aDecoder{
	self = [super initWithCoder:aDecoder];
	
	if (self) {
        [self prepare];
    }
	
	return self;
}

- (void)prepare {
    _scaleY = 0.0;
	scalarX = 1.0;
	startIndex = 0;
	
    _samplesToDisplay = malloc(sizeof(float *) * self.frame.size.width);
	_waveFormColor = [UIColor blackColor];
    
    //	hud = [[SNDViewHUD alloc] initWithFrame:self.frame];
    //	[self addSubview:hud];
	
    [self createGestures];
    [self createScrollView];
}

- (void)createGestures {
    //add pinch gesture
	UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
	[self addGestureRecognizer:pinch];
}

- (void)createScrollView {
    // i like the feel of the scrollview when it comes to pushing things around so we'll cheat and use one
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.frame];
   // [self.scrollView set]
    self.scrollView.delegate = self;
    [self.scrollView setBounces:NO];
    self.scrollView.backgroundColor = [UIColor clearColor];
    
   // dispatch_async(dispatch_get_main_queue(), ^{
        [self addSubview:self.scrollView];
        
    //    [self.scrollView addSubview:self];
        CGRect frame = self.scrollView.frame;
        frame.origin.x = 0;
        frame.origin.y = 0;
        self.scrollView.frame = frame;
   // });
}

//used for scrolling
//should be something like Handle Scroll
- (void)setOffset:(int)xCoordOffset{
	if (isZooming) {
		return;
	}
	
	startIndex = xCoordOffset * compressionValue;
	
	if (startIndex != 0 && startIndex < 0) {
		startIndex = 0;
		
	}
	
//	[hud setFeedbackLabelText:formatTime([self getTimeForSampleIndex:startIndex])];
    
	//NSLog(@"startIndex %i time:%f", startIndex, _runningTime);
	[self setNeedsDisplay];
}

- (void)handlePinch:(UIGestureRecognizer*)gesture{
	UIPinchGestureRecognizer *pinch = (UIPinchGestureRecognizer *)gesture;
	
 //   if (pinch.state == UIGestureRecognizerStateBegan) {
        NSLog(@"1) scrollframe %@ viewframe: %@ contentOffset: %f", NSStringFromCGRect(self.scrollView.frame), NSStringFromCGRect(self.frame), self.scrollView.contentOffset.x);
 //   }
    
	isZooming = TRUE;
	
	if ([self visibleTime] >= 0.55 || pinch.velocity < 0) {
		int visibleSample = [self visibleSamples];
		//NSLog(@"pre visible samples %i", visibleSample);
		
        CGPoint location = [pinch locationInView:self];
        float pinchInViewOffset = location.x/self.frame.size.width;
		
		float velocity = -1.0;
		
		if (pinch.velocity < 0) {
			velocity = 1.0;
		}
		
		zoomDirection = velocity;
		
		float compressionOffset = 8.0;
		
		if(compressionValue > 20)
			compressionValue += velocity * (compressionValue/compressionOffset);
		else {
			compressionValue += velocity;
		}
		
		if (compressionValue < 1) {
			compressionValue = 1;
		}
		
		float maxCompressionValue = self.dataCount/self.frame.size.width;
		
		//keep it a whole number or get weird draws that don't line up with slider times
		compressionValue = round(compressionValue);
		
		if (compressionValue > maxCompressionValue) {
			NSLog(@"!!!!");
			compressionValue = round(maxCompressionValue);
			startIndex = 0;
			self.scrollView.contentOffset = CGPointMake(0.0, self.scrollView.contentOffset.y);
			[self setNeedsDisplay];
		}        
		else {
			int postVisibleSample = [self visibleSamples];
            //	NSLog(@"post visible samples %i", postVisibleSample);
			
			startIndex += (visibleSample - postVisibleSample)*pinchInViewOffset;
			
			//check for border overflows
			if (startIndex < 0) {
                startIndex = 0;
			}
			
			if (startIndex + (320 * compressionValue) >= self.dataCount) {
                startIndex = self.dataCount - (320 * compressionValue);
			}
			
			self.scrollView.contentOffset = CGPointMake([self getPixelPointForTime:[self getTimeForSampleIndex:startIndex]], self.scrollView.contentOffset.y);
			[self setNeedsDisplay];
		}
        
        // TODO:
//		[self updatePlayHead:[self getTimeForPixelPoint:[hud playheadLocation] withStartOffset:startIndex]];
		
        NSLog(@"scrollframe %@ viewframe: %@ contentOffset: %f", NSStringFromCGRect(self.scrollView.frame), NSStringFromCGRect(self.frame), self.scrollView.contentOffset.x);
	}
    
	if ([pinch state] == UIGestureRecognizerStateEnded || [pinch state] == UIGestureRecognizerStateCancelled) {
		NSLog(@"pinch has ended");
		isZooming = FALSE;
        [self setNeedsDisplay];
    //    [self setOffset:(int)self.scrollView.contentOffset.x + 1];
	}
}		

- (float)getTimeForSampleIndex:(float)sampleIndex{
	return (sampleIndex * kCompressionValue - compressionValue)/k44100Sample;
}

//this may be broken... careful

- (void)drawSample:(float *)sampleData withArrayLength:(int)length{
	float endSeconds = (length * kCompressionValue)/k44100Sample;
	[self drawSample:sampleData withArrayLength:length withStartTime:0 andEndTime:endSeconds];
}

- (void)drawSample:(float *)sampleData withArrayLength:(int)length withStartTime:(float)startSeconds andEndTime:(float)endSeconds{
	_dataBuffer = sampleData;
	self.dataCount = length;
	
	startSample = floor((startSeconds * k44100Sample / kCompressionValue));
	endSample = floor((endSeconds * k44100Sample / kCompressionValue));
	
	[self setNeedsDisplay];
}

- (float)visibleTime{
	return (compressionValue * kCompressionValue * self.frame.size.width)/k44100Sample;
}

- (int)visibleSamples{
	return ([self visibleTime] * k44100Sample)/kCompressionValue + startIndex;
}

- (void)drawWithAssetURL:(NSURL *)url {
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithCapacity:1];
	[options setObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
	
	AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:options];
    
    [self populateSampleViewWithAsset:asset];
}

- (void)drawRect:(CGRect)updateRect
{
	if (!_dataBuffer) {
		[super drawRect:updateRect];
		return;
	}
	// Assume the view is correctly sized to for the sound waveform.
	// Basically, you want the bounds of the view to have length = length of sound
	// the height of the view can be anything you want.  (Sound data in OSX is scaled to
	// 1.0 to -1.0.)
	// This rountine could be rewritten to have an arbitrary x scale as well, but
	// it's a little more confusing.
	
	//track our time values at defined points during the draw.. we'll hand this to the hud
	NSMutableArray *timeIncrements = [NSMutableArray arrayWithCapacity:0];
	unsigned i;
	float maxIndex;
	//how much time are we actually showing?
	float visibleTime = [self visibleTime];
	
	if (compressionValue > 0) {
		endSample = [self visibleSamples];
	}
	
	//NSLog(@"startindex: %i endsample: %i",startIndex, endSample);
	
	//how many samples are we drawing
	
	//TODO: what's the point of dcount here?
	int dCount = (endSample - startIndex);
	//NSLog(@"dCount %i  %@", dCount, NSStringFromCGRect(updateRect));
	
    // Draw the waveform
	// if it's 60s of audio then
	// There are 44,100 samples in every second, meaning there are 60 * 44,100 = 2,646,000 sample frames in a minute
	// If we want the whole thing to fit in a 1000 pixel wide image, we need to ‚Äúcompress‚Äù 2,646,000 / 1000 = 2646 samples into a single pixel.
	maxIndex = updateRect.size.width;
	
	// start at the first sample
	i = startSample;
    
	// deal with our compression
	if (compressionValue == 0) {
		compressionValue = round(dCount/(maxIndex * scalarX));
		visibleTime = [self visibleTime];
	}
	
	dCount = [self visibleSamples];
	
	if (dCount == 0) {
		dCount = self.dataCount;
	}
	
	if (dCount > self.dataCount) {
		dCount = self.dataCount;
	}
	
	//NSLog(@"compressionValue: %f .. dcount: %i visibleTime:%f", compressionValue, dCount, visibleTime);
	
	if (compressionValue < 1) {
		compressionValue = 1;
	}
	
	UIBezierPath *path = [UIBezierPath bezierPath];
	
	[path moveToPoint:CGPointMake(0,self.bounds.size.height*0.5)];
	
	//if we're zoomed in too closely don't double draw
	if(visibleTime > kAllowForDoubleDrawValue)
		[path moveToPoint:CGPointMake(i, self.bounds.size.height*0.5)];
	
    //i tracks the time intervals that are added in the proceding loop
	i++;
	int index = startIndex;
	[timeIncrements addObject:[NSNumber numberWithFloat:[self getTimeForSampleIndex:index]]];
	float avgWindow = compressionValue;
	float currentSample = 0;
	int sampleCount = 0;
    float finalValue = 0;
	
	// approach 1: We keep track of a total sum for the entire sample window, and then divide that sum by the number of samples in the window. 
	for(index = startIndex; index < dCount; index += compressionValue){
		finalValue = 0;
        currentSample = 0;
		
		if (avgWindow + index > dCount) {
			avgWindow = dCount-index - 1;
		}
		
		for (int j = 0; j < avgWindow; j++) {
			currentSample = _dataBuffer[index + j];
			finalValue += fabs(currentSample);
		}
		
		currentSample = finalValue/avgWindow;
		_samplesToDisplay[sampleCount++] = currentSample;
		
		if (i % kTimeDisplayIncrement == 0) {
			[timeIncrements addObject:[NSNumber numberWithFloat:(index * kCompressionValue)/k44100Sample]];
		}
        
        i++;
	} 
	
	//if we haven't set the scale or we're zoom we need calc the true scale of our avgeraged samples
	if (_scaleY == 0.0 || isZooming) {
		float maxValue = 0.0;
		
		for (i = 0; i < self.frame.size.width; i++) {
			//go through and find the max value
			if (_samplesToDisplay[i] > maxValue) {
				maxValue = _samplesToDisplay[i];
			}
		}
		
		float scaleY = 1.0/maxValue;
		//NSLog(@"scaly: %f maxValue: %f", scaleY, maxValue);
		scaleY = ((self.bounds.size.height)*scaleY)*0.5;
		
		if (zoomDirection < 0) {
			if (scaleY < _scaleY) {
				_scaleY = scaleY;
			}
		}
		else {
			if (scaleY < _scaleY + 50 || _scaleY == 0) {
				_scaleY = scaleY;
			}
		}
	}
    
	//draw samples
    float boundsConst = self.bounds.size.height*0.5;
    
   // NSLog(@"scrollview offset %i sampleindex %i", (int)scrollView.contentOffset.x, startIndex);
    
	for (i = 0 + ((int)self.scrollView.contentOffset.x % 2); i <= self.frame.size.width; i+=2) {
		//if(visibleTime > kAllowForDoubleDrawValue)
			[path addLineToPoint:CGPointMake(i,_samplesToDisplay[i] * _scaleY + boundsConst)];
		
		[path addLineToPoint:CGPointMake(i,-_samplesToDisplay[i] * _scaleY + boundsConst)];
	}
    
   // NSLog(@"i: %i", i);
	
	//set the total time.. only called the first time run
	if(_runningTime == 0.0){
		_runningTime = (_dataCount * kCompressionValue)/k44100Sample;
		//NSLog(@"running time : %f compressionValue: %f endSample: %i", _runningTime, compressionValue, endSample);
		
	//	[self setLeftPlayHeadIndicator:0];
	//	[self setRightPlayHeadIndicator:self.frame.size.width];
	}	
	else {
	//	[self refreshPlayHeadBookmarks];
	}
    
	
	//let the hud know about the new  time values
	dispatch_async(dispatch_get_main_queue(), ^{
//		[hud setTimes:timeIncrements];
        // TODO: ???
		[self.scrollView setContentSize:CGSizeMake([self getPixelPointForTime:_runningTime], self.scrollView.contentSize.height)];
		
		//[[UIColor blackColor] setStroke];	
	});
	
	[self.waveFormColor setStroke];
	[path stroke];
}

#pragma mark helpers

//TODO: all time should be using CMTime


- (float)getUncompressedIndex{
	float index = startIndex * compressionValue;
	
	return index;
}

//could be a negative value if off the left side of the screen or a positive value
- (float)getPixelPointForTime:(float)time{
	return [self getPixelPointForTime:time withStartOffset:0];
}

- (float)getTimeForPixelPoint:(float)point{
	return [self getTimeForPixelPoint:point withStartOffset:0];
}

- (float)getPixelPointForTime:(float)time withStartOffset:(float)pixelOffset{
	float index = (k44100Sample * time)/(kCompressionValue);
	
	float point = ((index - pixelOffset)/compressionValue);
	
	//NSLog(@"")
	
	return point;
}

- (float)getTimeForPixelPoint:(float)point withStartOffset:(float)pixelOffset{
	//each pixel hold x amount of compression
	float index = pixelOffset + (point * compressionValue);
	//index *= compressionValue;
	
	float time = (index * kCompressionValue)/k44100Sample;
	
    //	NSLog(@"index %f , pixeloffset: %i point: %f", index, pixelOffset, point);
	
	return time;
}

 /*
- (NSTimeInterval)getTimeBetweenBookMarks{
	return [self getRightPlayHeadTime] - [self getLeftPlayHeadTime];
}*/

#pragma mark playhead
/*
- (void)refreshPlayHeadBookmarks{
	float time = [hud leftBookmarkTime];
	float pixel;
	
	if (time > 0.0) {
		pixel = [self getPixelPointForTime:time withStartOffset:startIndex];
		//	NSLog(@"--pixel point: %f time: %f", pixel, time);
		
		[self setLeftPlayHeadIndicator:pixel];
	}
	
	time = [hud rightBookmarkTime];
	
	if (time < _runningTime) {
		pixel = [self getPixelPointForTime:time withStartOffset:startIndex];
		[self setRightPlayHeadIndicator:pixel];
	}
}

- (void)setLeftPlayHeadIndicator:(float)atXCoord{
	[hud setLeftBookmarkLocation:atXCoord];
	_leftSlider.value = atXCoord;
	
	float time = [self getTimeForPixelPoint:atXCoord withStartOffset:startIndex];
	
	[hud setLeftBookmarkTime:time];
	//[hud setFeedbackLabelText:formatTime(time)];
}

- (void)setRightPlayHeadIndicator:(float)atXCoord{	
	[hud setRightBookmarkLocation:atXCoord];	
	_rightSlider.value = atXCoord;
	float time = [self getTimeForPixelPoint:atXCoord withStartOffset:startIndex];
	
	[hud setRightBookmarkTime:time];
	//[hud setFeedbackLabelText:formatTime(time)];
}

- (float)getLeftPlayHeadTime{
	return [hud leftBookmarkTime];
}

- (float)getRightPlayHeadTime{
	return [hud rightBookmarkTime];
}*/


//TODO: player only returns currenttime in rounded off seconds for some reason
//which means we get a big jump.. consider updating on a timer.. moving with a best guess
//and updating to the correct time periodically (perhaps every second from the actual player time)
- (void)updatePlayHead:(float)time{
	
	//float pixel = [self getPixelPointForTime:time withStartOffset:startIndex];
	
	//NSLog(@"playhead time %f pixel %f", time, pixel);
	
//	[hud updatePlayhead:pixel];
}

#pragma mark - Private

- (void)populateSampleViewWithAsset:(AVAsset *)asset{
	NSLog(@"Opening song");
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		CMTime assetCMDuration = asset.duration;
		
        float totalSamplesToProcess = assetCMDuration.value;
        NSLog(@"totalSamplesToProcess %f", totalSamplesToProcess);
		
		free(_dataBuffer);
		
		UInt32 frameCount = 0;
		NSError *error = nil;
		AVAssetReader * filereader = [AVAssetReader assetReaderWithAsset:(AVAsset *)asset error:&error];
		int index = 0;	//tracking index for Cbuffer
		
		if (!error) {
			//http://objective-audio.jp/2010/09/avassetreaderavassetwriter.html
			NSDictionary *audioSetting = [NSDictionary dictionaryWithObjectsAndKeys:
										  [NSNumber numberWithFloat:k44100Sample],AVSampleRateKey,
										  [NSNumber numberWithInt:1],AVNumberOfChannelsKey,
										  [NSNumber numberWithInt:32],AVLinearPCMBitDepthKey, //was 16
										  [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
										  [NSNumber numberWithBool:YES], AVLinearPCMIsFloatKey,  //was NO
										  [NSNumber numberWithBool:0], AVLinearPCMIsBigEndianKey,
										  [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved, nil];
            
			//should only be one track anyway
			AVAssetReaderAudioMixOutput * readaudiofile = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:(asset.tracks) audioSettings:audioSetting];
			BOOL yesorno = [filereader canAddOutput:(AVAssetReaderOutput *)readaudiofile];
			
            // TODO: remove
			if (yesorno == NO) {
                NSLog(@"crap");
                assert(nil);
            }

			
			[filereader addOutput:(AVAssetReaderOutput *)readaudiofile];
			
			//this line will force callbackInterruptionListener to be called!!!!!!!!!!!!
			BOOL lastcheck = [filereader startReading];
			
            // I've found that sometimes we'll fail for some reason or another and it's worth just trying again
			if (lastcheck == NO) {
				NSLog(@"File Read failed reading");
				[self populateSampleViewWithAsset:asset];
				return;
			}
			
			Boolean nexttest = TRUE;
			
			NSLog(@"processing file data");
			int avgWindow = kCompressionValue;
			
            NSLog(@"Reading sample data");
			
			//next code is called within a loop over and over, populating a buffer with an eye on read and write pointer positions
			while(nexttest){
				CMSampleBufferRef ref = [readaudiofile copyNextSampleBuffer];
				
				nexttest = CMSampleBufferDataIsReady(ref);
				
				//finished?
				if (nexttest == NO)
					NSLog(@"crap3");
				
				if(nexttest){
					CMItemCount countsamp = CMSampleBufferGetNumSamples(ref);
					
					if (countsamp == 0) {
						break;
					}
					
					frameCount += countsamp;
					
                    // TODO: delegate the progress
					//dispatch_async(dispatch_get_main_queue(), ^{
//						loadingProgress.progress = (frameCount/totalSamplesToProcess);
					//});
					
				//	NSLog(@"progress %f", (frameCount/totalSamplesToProcess));
					
					CMBlockBufferRef blockBuffer;
					AudioBufferList audioBufferList;
					
					//allocates new buffer memory
					CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(ref, NULL, &audioBufferList, sizeof(audioBufferList),NULL, NULL, 0, &blockBuffer);
					
					float *mData = (float *)audioBufferList.mBuffers[0].mData;
					
					//int compressionValue = kCompressionValue;
					float currentSample = 0;
					avgWindow = kCompressionValue;
					
					_dataBuffer = realloc(_dataBuffer, frameCount/kCompressionValue * sizeof(float));
					
					float min = 0.0;
					float max = 0.0;
					
					for(int i = 0; i < countsamp;){
						if (avgWindow + i >= countsamp) {
							avgWindow = i - countsamp;
						}
						
						min = 0.0;
						max = -0.0;
						
						for (int j = 0; j < kCompressionValue; j++) {
							currentSample = mData[j+i];
							
							if (currentSample < 0) {
								if(currentSample < min)
									min = currentSample;
							}
							else {
								if (currentSample > max) {
									max = currentSample;
								}
							}
						}
						
						if (fabs(min) > fabs(max)) {
							currentSample = min;
						}
						else {
							currentSample = max;
						}
						
						//NSLog(@"%f" ,currentSample);
						_dataBuffer[index++] = currentSample;
						i += kCompressionValue;
					}
					
					CFRelease(ref);
					CFRelease(blockBuffer);
				}
			}
		}
		
        // TODO: delegate
		NSLog(@"Finished opening, ready for display frameCOunt: %i", (unsigned int)frameCount);
        NSLog(@"Drawing waveform");


        // TODO:
	//	[self.scrollView setContentSize:CGSizeMake([[[[UIApplication sharedApplication] windows] objectAtIndex:0] frame].size.width, self.scrollView.contentSize.height)];
		

		
		dispatch_sync(dispatch_get_main_queue(), ^{
			[self drawSample:_dataBuffer withArrayLength:index];
			NSLog(@"Finished drawing waveform");
//			[loadingIndicatorView setHidden:YES];
//			leftPlaybackSlider.enabled = TRUE;
//			rightPlaybackSlider.enabled = TRUE;
		});
		
		//TODO: update the time with this.. calling once a second... this will sync the play head
		//in the meantime, run a play move with a best guess nstimer or dispatch_source
	//	CMTime time = asset.duration;
	//	time.value = 44100.0;
		
	
        /*if (periodicObserver) {
			[player removeTimeObserver:periodicObserver];
		}*/
		
/*		periodicObserver = [player addPeriodicTimeObserverForInterval:time queue:nil usingBlock:^(CMTime currentTime){
			//CMTime currentTime = player.currentTime;
			// playback time label
			//currentTime = player.currentTime;
			NSString* formattedTime = formatCMTime(currentTime);
			timeLabel.text = formattedTime;
			//	[self playerHeadTimerUpdate];
		}];*/
		
        
        
        /*
		dispatch_sync(dispatch_get_main_queue(), ^{
			loadingLabel.text = @"Finished drawing waveform";
			
			if (_asset.duration.value/_asset.duration.timescale > 120) {
				leftPlaybackSlider.value = 100;
				[self playSliderValueChanged:self];
			}
		});*/
	});
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
	if (scrollView.contentOffset.x >= 0) {
//		self.frame = CGRectMake(scrollView.contentOffset.x, scrollView.contentOffset.y, self.frame.size.width, self.frame.size.height);
	}
	else {
//		self.frame = CGRectMake(0, scrollView.contentOffset.y, self.frame.size.width, self.frame.size.height);
	}
	
	
	[self setOffset:(int)scrollView.contentOffset.x];
	//NSLog(@"%@", scrollView);
	
}

- (void)dealloc{
    free(_samplesToDisplay);
    free(_dataBuffer);
}

@end
