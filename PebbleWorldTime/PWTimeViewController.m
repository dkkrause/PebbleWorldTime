//
//  PWTimeFirstViewController.m
//  PebbleWorldTime
//
//  Created by Don Krause on 6/2/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "PWTimeViewController.h"
#import "PWTimeTZController.h"
#import "PWTimeKeys.h"
#import <PebbleKit/PebbleKit.h>

@interface PWTimeViewController () <PBPebbleCentralDelegate>

@property (strong, nonatomic) IBOutlet UISegmentedControl *clockSelect;
@property (strong, nonatomic) IBOutlet UISwitch *clockEnabled;
@property (strong, nonatomic) IBOutlet UISegmentedControl *clockBackground;
@property (strong, nonatomic) IBOutlet UISegmentedControl *clockDisplay;
@property (strong, nonatomic) IBOutlet UISegmentedControl *clockFace;
@property (strong, nonatomic) IBOutlet UIButton *tzSelect;
@property (strong, nonatomic) IBOutlet UILabel *tzDisplay;
@property (strong, nonatomic) IBOutlet UILabel *timeDisplay;
@property (weak, nonatomic) IBOutlet UISwitch *singleMessage;

@property (strong, nonatomic) PBWatch *targetWatch;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSTimeZone *clockTZ;
@property (strong, nonatomic) NSTimer *myTimer;

@end

@implementation PWTimeViewController
@synthesize clockSelect = _clockSelect;
@synthesize clockEnabled = _clockEnabled;
@synthesize clockBackground = _clockBackground;
@synthesize clockDisplay = _clockDisplay;
@synthesize clockFace = _clockFace;
@synthesize tzSelect = _tzSelect;
@synthesize tzDisplay = _tzDisplay;
@synthesize timeDisplay = _timeDisplay;
@synthesize singleMessage = _singleMessage;

@synthesize targetWatch = _targetWatch;
@synthesize dateFormatter = _dateFormatter;
@synthesize clockTZ = _clockTZ;
@synthesize myTimer = _myTimer;

- (NSString *)readableTZ:(NSTimeZone *)tz
{
    
    NSString *tzName = [tz name];
    NSString *cityName;
    
    // Format for output on the button. City name only, followed by (TZ)
    NSRange range = [tzName rangeOfString:@"/" options:NSBackwardsSearch];
    if (range.location != NSNotFound) {
        cityName = [tzName substringFromIndex:range.location+1];
    } else {
        cityName = tzName;
    }
    NSString *tzAbbr = [tz abbreviation];
    tzAbbr = [[@" (" stringByAppendingString:tzAbbr] stringByAppendingString:@")"];
    cityName = [[cityName stringByReplacingOccurrencesOfString:@"_" withString:@" "] stringByAppendingString:tzAbbr];
    
    return cityName;
    
}

- (void)runWatchApp
{
    
    // Attempt to launch the app on the Pebble
    [self.targetWatch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
        if (!error) {
            NSString *message = error ? [error localizedDescription] : @"Update sent!";
            if (![message isEqualToString:@"Update sent!"]) {
                NSString *full_message = [NSString stringWithFormat:@"Cannot launch app on Pebble: %@ ", message];
                [[[UIAlertView alloc] initWithTitle:nil message:full_message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            }
        }
    }];
    
}

- (void)setTargetWatch:(PBWatch *)targetWatch
{
    
    _targetWatch = targetWatch;
    
    [_targetWatch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
        
        if (isAppMessagesSupported) {
            
            // Configure our communications channel to target the worldtime app:
            uint8_t bytes[] = {0xC5, 0x5D, 0x88, 0x75, 0x56, 0x09, 0x43, 0x9D, 0xA5, 0x2F, 0x0A, 0x97, 0x73, 0x50, 0xB9, 0x55};
            NSData *uuid = [NSData dataWithBytes:bytes length:sizeof(bytes)];
            [watch appMessagesSetUUID:uuid];
            [self runWatchApp];             // make sure the watch app is running and ...
            [self sendConfigToWatch];       // ... send the configuration to the watch

//            NSString *message = [NSString stringWithFormat:@"Yay! %@ supports AppMessages :D", [watch name]];
//            [[[UIAlertView alloc] initWithTitle:@"Connected!" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            
        } else {
            
            NSString *message = [NSString stringWithFormat:@"Blegh... %@ does NOT support AppMessages :'(", [watch name]];
            [[[UIAlertView alloc] initWithTitle:@"Connected..." message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            
        }
        
    }];

}

- (void)setClockTZ:(NSTimeZone *)clockTZ
{
        
    if (_clockTZ != clockTZ) {
        
        _clockTZ = clockTZ;
        NSString *watchface = [self.clockSelect titleForSegmentAtIndex:[self.clockSelect selectedSegmentIndex]];
        if (![watchface isEqualToString:@"Local"]) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSString *tzName = [_clockTZ name];
            [defaults setObject:tzName forKey:[self makeKey:CLOCK_TZ_KEY]];
            [defaults synchronize];
        }
        [self.tzDisplay setText:[self readableTZ:self.clockTZ]];
        [self.tzDisplay setNeedsDisplay];
        [self updateWatch:@[@PBCOMM_CITY_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY] forWatches:@[watchface]];
        
    }
    
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
    return [self makeKey:keyLabel forWatch:[self.clockSelect titleForSegmentAtIndex:[self.clockSelect selectedSegmentIndex]]];
}

- (NSString *)makeKey:(NSString *)keyLabel forWatch:(NSString *)watch
{
    
    NSString *finalKey = [KEY_DOMAIN stringByAppendingString:@"."];
    finalKey = [finalKey stringByAppendingString:watch];
    finalKey = [finalKey stringByAppendingString:@"."];
    finalKey = [finalKey stringByAppendingString:keyLabel];
    return finalKey;
    
}

- (void)loadClockFields
{
    
    // Get the current field values from NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.clockEnabled.on = [defaults boolForKey:[self makeKey:CLOCK_ENABLED_KEY]];
    self.clockBackground.selectedSegmentIndex = [defaults integerForKey:[self makeKey:CLOCK_BACKGROUND_KEY]];
    self.clockDisplay.selectedSegmentIndex = [defaults integerForKey:[self makeKey:CLOCK_DISPLAY_KEY]];
    self.clockFace.selectedSegmentIndex = [defaults integerForKey:[self makeKey:CLOCK_WATCHFACE_KEY]];
    NSString *defTZ = [defaults stringForKey:[self makeKey:CLOCK_TZ_KEY]];
    if (defTZ == nil) {
        defTZ = [[NSTimeZone systemTimeZone] name];
    }
    self.clockTZ = [NSTimeZone timeZoneWithName:defTZ];
    
    if (_clockSelect.selectedSegmentIndex == 0) {
        self.clockEnabled.on = TRUE;
        self.clockEnabled.hidden = TRUE;
        self.tzSelect.hidden = TRUE;
    } else {
        self.clockEnabled.hidden = FALSE;
        self.tzSelect.hidden = FALSE;
    }
    
}

- (IBAction)clockSelected:(id)sender {
    
    [self loadClockFields];
    
}

- (IBAction)clockEnabledSwitchChanged:(id)sender {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:self.clockEnabled.on] forKey:[self makeKey:CLOCK_ENABLED_KEY]];
    [defaults synchronize];
    
    NSString *watchface = [self.clockSelect titleForSegmentAtIndex:[self.clockSelect selectedSegmentIndex]];
    
    [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_CITY_KEY, @PBCOMM_12_24_DISPLAY_KEY,
     @PBCOMM_WATCHFACE_DISPLAY_KEY] forWatches:@[watchface]];
    
}

- (IBAction)clockBackgroundSegmentSelected:(id)sender {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInteger:[sender selectedSegmentIndex]] forKey:[self makeKey:CLOCK_BACKGROUND_KEY]];
    [defaults synchronize];
    
    [self updateWatch:@[@PBCOMM_BACKGROUND_KEY] forWatches:@[[self.clockSelect titleForSegmentAtIndex:[self.clockSelect  selectedSegmentIndex]]]];

}

- (IBAction)timeDisplayChanged:(id)sender {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInteger:[sender selectedSegmentIndex]] forKey:[self makeKey:CLOCK_DISPLAY_KEY]];
    [defaults synchronize];
    
    [self updateWatch:@[@PBCOMM_12_24_DISPLAY_KEY] forWatches:@[[self.clockSelect titleForSegmentAtIndex:[self.clockSelect selectedSegmentIndex]]]];
    
}


- (IBAction)watchFaceChanged:(id)sender {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInteger:[sender selectedSegmentIndex]] forKey:[self makeKey:CLOCK_WATCHFACE_KEY]];
    [defaults synchronize];
    
    [self updateWatch:@[@PBCOMM_WATCHFACE_DISPLAY_KEY] forWatches:@[[self.clockSelect titleForSegmentAtIndex:[sender selectedSegmentIndex]]]];
    
}

- (IBAction)updateWatchData:(id)sender {
    [self sendConfigToWatch];
}
- (IBAction)sendSingleMessage:(id)sender {
    
}

- (void)updateRunningClock:(id)sender
{
    
    NSDate *date = [[NSDate alloc] init];   // Get the current date and time
    
    // Print the time in the selected time zone
    [self.dateFormatter setTimeZone:self.clockTZ];
    self.timeDisplay.text = [self.dateFormatter stringFromDate:date];
    [self.timeDisplay setNeedsDisplay];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    
    [super viewWillAppear:animated];
    
    // See if a watch is connected
    // We'd like to get called when Pebbles connect and disconnect, so become the delegate of PBPebbleCentral:
    [[PBPebbleCentral defaultCentral] setDelegate:self];
    
    // Initialize with the last connected watch:
    [self setTargetWatch:[[PBPebbleCentral defaultCentral] lastConnectedWatch]];
    [self loadClockFields];
    
}

- (void)sendConfigToWatch
{

    if (self.singleMessage.isOn) {
        
        // First choice is to update all watches in one message. Doesn't work yet
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY, @PBCOMM_WATCHFACE_DISPLAY_KEY] forWatches:@[@"Local", @"TZ1", @"TZ2"]];
        
    } else {
        
        // Update the local watch with all of the current settings
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY,
         @PBCOMM_WATCHFACE_DISPLAY_KEY] forWatches:@[@"Local"]];
        
        //[NSThread sleepForTimeInterval:1.0];
        
        // Update the TZ1 watch with all of the current settings
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY,
         @PBCOMM_WATCHFACE_DISPLAY_KEY] forWatches:@[@"TZ1"]];
        
        //[NSThread sleepForTimeInterval:1.0];
        
        // Update the TZ2 watch with all of the current settings
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY,
         @PBCOMM_WATCHFACE_DISPLAY_KEY] forWatches:@[@"TZ2"]];
        
        //[NSThread sleepForTimeInterval:1.0];
        
    }
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.
    self.dateFormatter.dateFormat = @"yyyy-MM-dd, HH:mm:ss Z";
    self.myTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateRunningClock:) userInfo:nil repeats:YES];

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
        [tzController setClockTZ:self.clockTZ];
    }
}

/*
 * updateWatch - sends the data associated with the key parameter to the watch to update the information
 */
- (void)updateWatch:(NSArray *)keys forWatches:(NSArray *)watchfaces
{
    
    // We  communicate with the watch when we call -appMessagesGetIsSupported: which implicitely opens the communication session.
    // Test if the Pebble's firmware supports AppMessages:
    [_targetWatch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
        
        if (isAppMessagesSupported) {
            
            // Configure our communications channel to target the worldtime app:
            uint8_t bytes[] = {0xC5, 0x5D, 0x88, 0x75, 0x56, 0x09, 0x43, 0x9D, 0xA5, 0x2F, 0x0A, 0x97, 0x73, 0x50, 0xB9, 0x55};
            NSData *uuid = [NSData dataWithBytes:bytes length:sizeof(bytes)];
            [watch appMessagesSetUUID:uuid];
            [self runWatchApp];
           
//            NSString *message = [NSString stringWithFormat:@"Yay! %@ supports AppMessages :D", [watch name]];
//            [[[UIAlertView alloc] initWithTitle:@"Connected!" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            @try {

                int watchOffset;
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                NSMutableDictionary *update = [[NSMutableDictionary alloc] init];
                NSString *defTZ;
                int32_t seconds;
                uint8_t isOn;
                for (NSString *watchface in watchfaces) {
                    
                    // There are three possible watchfaces, local time, time zone 1 and time zone 2. Which face are we updating?
                    if ([watchface isEqualToString:@"Local"]) {
                        watchOffset = LOCAL_WATCH_OFFSET;
                    } else if ([watchface isEqualToString:@"TZ1"]) {
                        watchOffset = WATCH_1_OFFSET;
                    } else if ([watchface isEqualToString:@"TZ2"]) {
                        watchOffset = WATCH_2_OFFSET;
                    } else {
                        return;
                    }
                    
                    for (NSNumber *key in keys) {
                        
                        // Now we need to put together the tuples to be sent to the Pebble watch
                        switch ([key intValue]) {
                                
                            case PBCOMM_WATCH_ENABLED_KEY:
                                // Is the clock enabled?
                                isOn = (uint8_t) [[NSNumber numberWithBool:[defaults boolForKey:[self makeKey:CLOCK_ENABLED_KEY forWatch:watchface]]] int8Value];
                                if (watchOffset == LOCAL_WATCH_OFFSET) isOn = TRUE;
                                [update setObject:[NSNumber numberWithUint8:isOn] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_GMT_SEC_OFFSET_KEY:
                                // GMT Offset
                                defTZ = [defaults stringForKey:[self makeKey:CLOCK_TZ_KEY forWatch:watchface]];
                                if (defTZ == nil) {
                                    defTZ = [[NSTimeZone systemTimeZone] name];
                                }
                                seconds = [[NSTimeZone timeZoneWithName:defTZ] secondsFromGMT];
                                [update setObject:[NSNumber numberWithInt32:seconds] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_CITY_KEY:
                                // Time Zone location string
                                defTZ = [defaults stringForKey:[self makeKey:CLOCK_TZ_KEY forWatch:watchface]];
                                if (defTZ == nil) {
                                    defTZ = [[NSTimeZone systemTimeZone] name];
                                }
                                [update setObject:[self readableTZ:[NSTimeZone timeZoneWithName:defTZ]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_BACKGROUND_KEY:
                                [update setObject:[NSNumber numberWithInt8:[defaults integerForKey:[self makeKey:CLOCK_BACKGROUND_KEY forWatch:watchface]]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_12_24_DISPLAY_KEY:
                                [update setObject:[NSNumber numberWithInt8:[defaults integerForKey:[self makeKey:CLOCK_DISPLAY_KEY forWatch:watchface]]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_WATCHFACE_DISPLAY_KEY:
                                [update setObject:[NSNumber numberWithInt8:[defaults integerForKey:[self makeKey:CLOCK_WATCHFACE_KEY forWatch:watchface]]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            default:
                                return;
                                
                        }
                        
                    }
                    
                }
                
                // Send data to watch:
                // See demos/feature_app_messages/weather.c in the native watch app SDK for the same definitions on the watch's end:
                [_targetWatch appMessagesPushUpdate:update onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
                    NSString *message = error ? [error localizedDescription] : @"Update sent!";
                    if (![message isEqualToString:@"Update sent!"]) {
                        NSString *full_message = [NSString stringWithFormat:@"%@ Watches: %@, Update: %@", message, watchfaces, update];
                        [[[UIAlertView alloc] initWithTitle:nil message:full_message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                    }
                }];
                return;
            }
            @catch (NSException *exception) {
            }
            [[[UIAlertView alloc] initWithTitle:nil message:@"Error parsing response" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        
        } else {
            
            NSString *message = [NSString stringWithFormat:@"Blegh... %@ does NOT support AppMessages :'(", [watch name]];
            [[[UIAlertView alloc] initWithTitle:@"Connected..." message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            
        }
        
    }];
    
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
