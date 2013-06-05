//
//  ViewController.m
//  WavePreview
//
//  Created by Seth Howard on 5/29/13.
//  Copyright (c) 2013 Seth Howard. All rights reserved.
//

#import "ViewController.h"
#import "SampleView.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet SampleView *sampleView;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"34 Pour Some Hot Sugar (Mims vs. Def Leppard)" ofType:@"mp3"];
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
    
    [self.sampleView drawWithAssetURL:url];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
 