//
//  SNDView.m
//
//  Created by Seth Howard on 11/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "SampleView.h"
#import <AVFoundation/AVFoundation.h>

#define kCompressionValue	128.0f
#define k44100Sample	 44100.0f

@interface SampleView() <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, assign) int dCount;
@property (nonatomic, assign) CGSize viewSize;
@end


@implementation SampleView {
    @private
    float *_dataBuffer;
    float *_samplesToDisplay;
	float _compressionValue;	//how many samples are we skipping to draw waveform... should be called displayCompressionValue
	int _endSample;		//where does the wav stop drawing
	BOOL _isZooming;
	int _zoomDirection;
	float _scaleY;
    int _startIndex;		//where does the wav start drawing
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

- (void)drawWithAssetURL:(NSURL *)url {
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithCapacity:1];
	[options setObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
	
	AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:options];
    
    [self populateSampleViewWithAsset:asset];
}

- (void)prepare {
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    _scaleY = 0.0;
	_startIndex = 0;
	
    _samplesToDisplay = malloc(sizeof(float *) * self.frame.size.width);
	_waveOutlineColor = _waveFillColor = [UIColor blackColor];
	
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
    self.scrollView.delegate = self;
    [self.scrollView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    self.scrollView.backgroundColor = [UIColor clearColor];
    
    [self addSubview:self.scrollView];
    CGRect frame = self.scrollView.frame;
    frame.origin.x = 0;
    frame.origin.y = 0;
    self.scrollView.frame = frame;
}

// TODO: refactor
- (void)calcCompression {
    // this seems to have the opposite effect than what we want? the larger the frame width the more detailed the drawing is.. thus slower
    _compressionValue = round((_endSample - _startIndex)/(self.frame.size.width)) + kCompressionValue;
}

#pragma mark - Private

// this is called after we load the asset
- (void)drawSample:(float *)sampleData withArrayLength:(int)length{
	float endSeconds = (length * kCompressionValue)/k44100Sample;
    
    _dataBuffer = sampleData;
	_sampleCount = length;
    _endSample = floor((endSeconds * k44100Sample / kCompressionValue));
    [self calcCompression];
    _runningTime = (self.sampleCount * kCompressionValue)/k44100Sample;
    
    [self setNeedsDisplay];
}

- (NSDictionary *)audioSettings {
    //http://objective-audio.jp/2010/09/avassetreaderavassetwriter.html
    NSDictionary *audioSetting = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithFloat:k44100Sample],AVSampleRateKey,
                                  [NSNumber numberWithInt:1],AVNumberOfChannelsKey,
                                  [NSNumber numberWithInt:32],AVLinearPCMBitDepthKey, //was 16
                                  [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                  [NSNumber numberWithBool:YES], AVLinearPCMIsFloatKey,  //was NO
                                  [NSNumber numberWithBool:0], AVLinearPCMIsBigEndianKey,
                                  [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved, nil];
    
    return audioSetting;
}

// TODO: add error checking
- (void)populateSampleViewWithAsset:(AVAsset *)asset{	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		CMTime assetCMDuration = asset.duration;
		
        float totalSamplesToProcess = assetCMDuration.value;
        
        if ([self.delegate respondsToSelector:@selector(sampleView:totalSamplesToProcess:)]) {
            [self.delegate sampleView:self totalSamplesToProcess:totalSamplesToProcess];
        }
		
		free(_dataBuffer);
		
		UInt32 frameCount = 0;
		NSError *error = nil;
		AVAssetReader * filereader = [AVAssetReader assetReaderWithAsset:(AVAsset *)asset error:&error];
		int index = 0;	//tracking index for Cbuffer
		
		if (!error) {
            NSDictionary *audioSetting = [self audioSettings];
            
            // should only be one track anyway
            AVAssetReaderAudioMixOutput * readaudiofile = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:(asset.tracks) audioSettings:audioSetting];
            // TODO: error check
            BOOL yesorno = [filereader canAddOutput:(AVAssetReaderOutput *)readaudiofile];
            
            [filereader addOutput:(AVAssetReaderOutput *)readaudiofile];
            
            // TODO: check for error 
            BOOL lastcheck = [filereader startReading];
            Boolean nexttest = TRUE;
 
            int avgWindow = kCompressionValue;
            
            // next code is called within a loop over and over, populating a buffer with an eye on read and write pointer positions
            while(nexttest){
                CMSampleBufferRef ref = [readaudiofile copyNextSampleBuffer];
                nexttest = CMSampleBufferDataIsReady(ref);
                
                if(nexttest){
                    CMItemCount countsamp = CMSampleBufferGetNumSamples(ref);
                    
                    if (countsamp == 0) {
                        break;
                    }
                    
                    frameCount += countsamp;
                    
                    if ([self.delegate respondsToSelector:@selector(sampleView:samplesProcessed:)]) {
                        [self.delegate sampleView:self samplesProcessed:frameCount];
                    }
                    
                    CMBlockBufferRef blockBuffer;
                    AudioBufferList audioBufferList;
                    
                    // allocates new buffer memory
                    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(ref, NULL, &audioBufferList, sizeof(audioBufferList),NULL, NULL, 0, &blockBuffer);
                    
                    float *mData = (float *)audioBufferList.mBuffers[0].mData;
                    
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
                        
                        _dataBuffer[index++] = currentSample;
                        i += kCompressionValue;
                    }
                    
                    CFRelease(ref);
                    CFRelease(blockBuffer);
                }
            }
		}
		
        if ([self.delegate respondsToSelector:@selector(sampleViewWaveLoaded:)]) {
            [self.delegate sampleViewWaveLoaded:self];
        }
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[self drawSample:_dataBuffer withArrayLength:index];
			NSLog(@"Finished drawing waveform");
            
            if ([self.delegate respondsToSelector:@selector(sampleViewWaveDisplayed:)]) {
                [self.delegate sampleViewWaveDisplayed:self];
            }
		});
	});
}

#pragma mark - Draw

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
	unsigned int i = 0;
	
    // I believe this will always be true...
    // get our endSample and set are starting sample so we know what segment of the wave we're about to draw
	if (_compressionValue > 0) {
		_endSample = [self getLastVisibleIndex];
        
        // if the endsample over shoots our total _dataCount then we need to back things up or we'll display garbage (most likely we're bounce scrolling)
        if (_endSample > self.sampleCount) {
            // kick the startindex down the line to match up
            _startIndex = _startIndex - (_endSample - self.sampleCount);
            // self.dataCount - 1 ?
            _endSample = self.sampleCount;
            
            // For whatever reason our startIndex can get borked and drop below zero.
            if (_startIndex < 0) {
                _startIndex = 0;
            }
        }
	}
    
	//how many samples are we drawing
	
    // Draw the waveform
	// if it's 60s of audio then
	// There are 44,100 samples in every second, meaning there are 60 * 44,100 = 2,646,000 sample frames in a minute
	// If we want the whole thing to fit in a 1000 pixel wide image, we need to compress 2,646,000 / 1000 = 2646 samples into a single pixel.
	self.dCount = [self getLastVisibleIndex];
	
    // position our path
	UIBezierPath *path = [UIBezierPath bezierPath];
	[path moveToPoint:CGPointMake(0,self.bounds.size.height*0.5)];
	
	int index = _startIndex;
	[timeIncrements addObject:[NSNumber numberWithFloat:[self getTimeForSampleIndex:index]]];
	float avgWindow = _compressionValue;
	float currentSample = 0;
	int sampleCount = 0;
    float finalValue = 0;
	
	// approach 1: We keep track of a total sum for the entire sample window, and then divide that sum by the number of samples in the window.
	for(index = _startIndex; index < self.dCount; index += _compressionValue){
		finalValue = 0;
        currentSample = 0;
		
		if (avgWindow + index > self.dCount) {
			avgWindow = self.dCount-index - 1;
		}
		
		for (int j = 0; j < avgWindow; j++) {
			currentSample = _dataBuffer[index + j];
			finalValue += fabs(currentSample);
		}
		
		currentSample = finalValue/avgWindow;
		_samplesToDisplay[sampleCount++] = currentSample;
        
        i++;
	}
    
	//if we haven't set the scale or we're zooming. we need calc the true scale of our avgeraged samples
	if (_scaleY == 0.0 || _isZooming) {
		float maxValue = 0.0;
		
		for (i = 0; i < self.frame.size.width; i++) {
			//go through and find the max value
			if (_samplesToDisplay[i] > maxValue) {
                maxValue = _samplesToDisplay[i];
			}
		}
		
		float scaleY = 1.0/maxValue;
		scaleY = ((self.bounds.size.height)*scaleY)*0.5;
		
		if (_zoomDirection < 0) {
			if (scaleY < _scaleY) {
                _scaleY = scaleY;
			}
		}
		else {
			if (scaleY < _scaleY || _scaleY == 0) {
                _scaleY = scaleY;
			}
		}
	}
    
	//draw samples
    float boundsConst = self.bounds.size.height*0.5;
    
    // draw the upper path of the wave
	for (i = 0; i <= self.frame.size.width; i++) {
		[path addLineToPoint:CGPointMake(i,-_samplesToDisplay[i] * _scaleY + boundsConst)];
	}
    
    // continue drawing the bottom half
    for (i = self.frame.size.width; i > 0 ; i--) {
        [path addLineToPoint:CGPointMake(i,_samplesToDisplay[i] * _scaleY + boundsConst)];
    }
    
    [self.scrollView setContentSize:CGSizeMake([self getPixelPointForTime:_runningTime], self.scrollView.contentSize.height)];
    
    [path closePath];
	[self.waveOutlineColor setStroke];
	[path stroke];
    [self.waveFillColor setFill];
    [path fill];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    if (_isZooming) {
        return;
    }
    
	if (scrollView.contentSize.width - scrollView.contentOffset.x < scrollView.frame.size.width) {
		self.frame = CGRectMake(-(self.frame.size.width - (scrollView.contentSize.width - scrollView.contentOffset.x)), self.frame.origin.y, self.frame.size.width, self.frame.size.height);
        [self setStartingIndexOffset:scrollView.contentSize.width - scrollView.frame.size.width];
	}
	else if(scrollView.contentOffset.x < 0) {
		self.frame = CGRectMake(-scrollView.contentOffset.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
        [self setStartingIndexOffset:(int)scrollView.contentOffset.x];
	}
	else {
        [self setStartingIndexOffset:(int)scrollView.contentOffset.x];
    }
	
    
    if ([self.delegate respondsToSelector:@selector(sampleView:hasScrolled:)]) {
        [self.delegate sampleView:self hasScrolled:scrollView];
    }
}

#pragma mark - setters/getters

- (void)setDCount:(int)dCount {
    if (dCount == 0 || dCount > self.sampleCount) {
		dCount = self.sampleCount;
	}
    
    _dCount = dCount;
}

// whenever we scroll we need to update the start index.
- (void)setStartingIndexOffset:(int)xCoordOffset{
	if (_isZooming) {
		return;
	}
	
	_startIndex = xCoordOffset * _compressionValue;
	
	if (_startIndex != 0 && _startIndex < 0) {
		_startIndex = 0;		
	}
	
	[self setNeedsDisplay];
}

- (float)getTimeForSampleIndex:(float)sampleIndex{
	return (sampleIndex * kCompressionValue - _compressionValue)/k44100Sample;
}

- (float)visibleTime{
	return (_compressionValue * kCompressionValue * self.frame.size.width)/k44100Sample;
}

// TODO: rename this... this is really just telling us what the end sample is
- (int)getLastVisibleIndex{
	return ([self visibleTime] * k44100Sample)/kCompressionValue + _startIndex;
}

//TODO: all time should be using CMTime
- (float)getUncompressedIndex{
	float index = _startIndex * _compressionValue;
	
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
	float point = ((index - pixelOffset)/_compressionValue);
	
	return point;
}

- (float)getTimeForPixelPoint:(float)point withStartOffset:(float)pixelOffset{
	//each pixel hold x amount of compression
	float index = pixelOffset + (point * _compressionValue);
	float time = (index * kCompressionValue)/k44100Sample;
	
	return time;
}

#pragma mark - gesture handlers 

// TODO: needs a rewrite. It was a nice effort
- (void)handlePinch:(UIGestureRecognizer*)gesture{
	UIPinchGestureRecognizer *pinch = (UIPinchGestureRecognizer *)gesture;
	
	_isZooming = TRUE;
	
    // TODO: some sort of mystery magical number action going on here
	if ([self visibleTime] >= 0.55 || pinch.velocity < 0) {
		int visibleSample = [self getLastVisibleIndex];
		//NSLog(@"pre visible samples %i", visibleSample);
		
        CGPoint location = [pinch locationInView:self];
        float pinchInViewOffset = location.x/self.frame.size.width;
		
		float velocity = -1.0;
		
		if (pinch.velocity < 0) {
			velocity = 1.0;
		}
		
		_zoomDirection = velocity;
		
		float compressionOffset = 10.0;
		
        // TODO: going to assume we try and slow down the zoom if we get too close. This barely works
		if(_compressionValue > 20)
			_compressionValue += velocity * (_compressionValue/compressionOffset);
		else {
			_compressionValue += velocity;
		}
		
		if (_compressionValue < 1) {
			_compressionValue = 1;
		}
		
		float maxCompressionValue = self.sampleCount/self.frame.size.width;
		
		//keep it a whole number or get weird draws that don't line up with slider times
		_compressionValue = round(_compressionValue);
		
		if (_compressionValue > maxCompressionValue) {
			_compressionValue = round(maxCompressionValue);
			_startIndex = 0;
			self.scrollView.contentOffset = CGPointMake(0.0, self.scrollView.contentOffset.y);
			[self setNeedsDisplay];
		}
		else {
			int postVisibleSample = [self getLastVisibleIndex];
			_startIndex += (visibleSample - postVisibleSample)*pinchInViewOffset;
			
			//check for border overflows
			if (_startIndex < 0) {
                _startIndex = 0;
			}
			
			if (_startIndex + (self.frame.size.width * _compressionValue) >= self.sampleCount) {
                _startIndex = self.sampleCount - (self.frame.size.width * _compressionValue);
			}
			
            CGRect frame = self.frame;
            frame.origin.x = 0;
            self.frame = frame;
            
			self.scrollView.contentOffset = CGPointMake([self getPixelPointForTime:[self getTimeForSampleIndex:_startIndex]], self.scrollView.contentOffset.y);
			[self setNeedsDisplay];
		}
	}
    
    if([self.delegate respondsToSelector:@selector(sampleView:hasZoomed:)]){
        [self.delegate sampleView:self hasZoomed:pinch];
    }
    
	if ([pinch state] == UIGestureRecognizerStateEnded || [pinch state] == UIGestureRecognizerStateCancelled) {
		_isZooming = FALSE;
	}
}

#pragma mark - UIView orientation

- (void)deviceOrientationDidChange:(NSNotification *)notification {
    //Obtain current device orientation
   // UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    
   // NSLog(@"1 %f", _compressionValue);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self calcCompression];
    });
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    free(_samplesToDisplay);
    free(_dataBuffer);
}

@end
