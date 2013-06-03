//
//  PWTimeFirstViewController.m
//  PebbleWorldTime
//
//  Created by Don Krause on 6/2/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "PWTimeViewController.h"
#import "PWTimeTZController.h"
#import <PebbleKit/PebbleKit.h>

@interface PWTimeViewController () <PBPebbleCentralDelegate>

@property (strong, nonatomic) IBOutlet UISwitch *clockEnabledSwitch;
@property (strong, nonatomic) IBOutlet UISegmentedControl *clockBackgroundSegmentControl;
@property (strong, nonatomic) IBOutlet UIButton *tzSelectButton;
@property (strong, nonatomic) IBOutlet UILabel *localTimeDisplay;
@property (strong, nonatomic) IBOutlet UILabel *zoneTimeDisplay;
@property (strong, nonatomic) IBOutlet UILabel *watchface;

@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSString *clockTZ;
@property (strong, nonatomic) PBWatch *targetWatch;

@end

@implementation PWTimeViewController

@synthesize clockEnabledSwitch = _clockEnabledSwitch;
@synthesize clockBackgroundSegmentControl = _clockBackgroundSegmentControl;
@synthesize tzSelectButton = _tzSelectButton;
@synthesize localTimeDisplay = _localTimeDisplay;
@synthesize zoneTimeDisplay = _zoneTimeDisplay;
@synthesize watchface = _watchface;

@synthesize dateFormatter = _dateFormatter;
@synthesize clockTZ = _clockTZ;
@synthesize targetWatch = _targetWatch;

- (void)setClockTZ:(NSString *)clockTZ
{
    _clockTZ = clockTZ;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSString stringWithString:_clockTZ] forKey:[self makeKey:CLOCK_TZ_KEY]];
    [defaults synchronize];
    [self.tzSelectButton setTitle:_clockTZ forState:UIControlStateNormal];
    [self.tzSelectButton setNeedsDisplay];
    
}

- (void)setTargetWatch:(PBWatch*)watch {
    _targetWatch = watch;
    
    // NOTE:
    // For demonstration purposes, we start communicating with the watch immediately upon connection,
    // because we are calling -appMessagesGetIsSupported: here, which implicitely opens the communication session.
    // Real world apps should communicate only if the user is actively using the app, because there
    // is one communication session that is shared between all 3rd party iOS apps.
    
    // Test if the Pebble's firmware supports AppMessages / Weather:
    [watch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
        if (isAppMessagesSupported) {
            // Configure our communications channel to target the weather app:
            // See demos/feature_app_messages/weather.c in the native watch app SDK for the same definition on the watch's end:
            uint8_t bytes[] = {0x42, 0xc8, 0x6e, 0xa4, 0x1c, 0x3e, 0x4a, 0x07, 0xb8, 0x89, 0x2c, 0xcc, 0xca, 0x91, 0x41, 0x98};
            NSData *uuid = [NSData dataWithBytes:bytes length:sizeof(bytes)];
            [watch appMessagesSetUUID:uuid];
            
            NSString *message = [NSString stringWithFormat:@"Yay! %@ supports AppMessages :D", [watch name]];
            [[[UIAlertView alloc] initWithTitle:@"Connected!" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        } else {
            
            NSString *message = [NSString stringWithFormat:@"Blegh... %@ does NOT support AppMessages :'(", [watch name]];
            [[[UIAlertView alloc] initWithTitle:@"Connected..." message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    }];
}

- (NSDateFormatter *)dateFormatter
{

    if (_dateFormatter == nil) {
        _dateFormatter = [[NSDateFormatter alloc] init];
    }
    return _dateFormatter;
}

- (NSString *)makeKey:(NSString *)keyLabel
{
    
    NSString *finalKey = [KEY_DOMAIN stringByAppendingString:@"."];
    finalKey = [finalKey stringByAppendingString:self.watchface.text];
    finalKey = [finalKey stringByAppendingString:@"."];
    finalKey = [finalKey stringByAppendingString:keyLabel];
    return finalKey;
    
}

- (IBAction)clockEnabledSwitchChanged:(id)sender {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:self.clockEnabledSwitch.on] forKey:[self makeKey:CLOCK_ENABLED_KEY]];
    [defaults synchronize];
    
}

- (IBAction)clockBackgroundSegmentSelected:(id)sender {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInteger:self.clockBackgroundSegmentControl.selectedSegmentIndex] forKey:[self makeKey:CLOCK_BACKGROUND_KEY]];
    [defaults synchronize];

}

- (void)updateClocks:(id)sender
{
    
    NSDate *date = [[NSDate alloc] init];   // Get the current date and time
    
    // Print the local time
    [self.dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    self.localTimeDisplay.text = [self.dateFormatter stringFromDate:date];
    [self.localTimeDisplay setNeedsDisplay];
    
    // Print the time in the selected time zone
    [self.dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:self.tzSelectButton.titleLabel.text]];
    self.zoneTimeDisplay.text = [self.dateFormatter stringFromDate:date];
    [self.zoneTimeDisplay setNeedsDisplay];
    
    date = nil; // get rid of the date, we don't need it any more
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // See if a watch is connected
    // We'd like to get called when Pebbles connect and disconnect, so become the delegate of PBPebbleCentral:
    [[PBPebbleCentral defaultCentral] setDelegate:self];
    
    // Initialize with the last connected watch:
    [self setTargetWatch:[[PBPebbleCentral defaultCentral] lastConnectedWatch]];
    
    // Get the current field values from NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.clockEnabledSwitch.on = [defaults boolForKey:[self makeKey:CLOCK_ENABLED_KEY]];
    self.clockBackgroundSegmentControl.selectedSegmentIndex = [defaults integerForKey:[self makeKey:CLOCK_BACKGROUND_KEY]];
    [self.tzSelectButton setTitle:[defaults stringForKey:[self makeKey:CLOCK_TZ_KEY]] forState:UIControlStateNormal];
    if (self.tzSelectButton.titleLabel.text == nil) {
        [self.tzSelectButton setTitle:@"America/Los_Angeles" forState:UIControlStateNormal];
    }
    [self.tzSelectButton setNeedsDisplay];
    
    self.dateFormatter.dateFormat = @"yyyy-MM-dd, HH:mm:ss Z";
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateClocks:) userInfo:nil repeats:YES];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
    if ([segue.identifier isEqualToString:@"toTZ"]) {
        PWTimeTZController *tzController = segue.destinationViewController;
        [tzController setDelegate:self];
        [tzController setClockTZ:self.tzSelectButton.titleLabel.text];
    }
}

/*
 *  PBPebbleCentral delegate methods
 */

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidConnect:(PBWatch*)watch isNew:(BOOL)isNew {
    [self setTargetWatch:watch];
}

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidDisconnect:(PBWatch*)watch {
    [[[UIAlertView alloc] initWithTitle:@"Disconnected!" message:[watch name] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    if (_targetWatch == watch || [watch isEqual:_targetWatch]) {
        [self setTargetWatch:nil];
    }
}

@end
