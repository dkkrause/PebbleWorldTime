//
//  PWTimeFirstViewController.m
//  PebbleWorldTime
//
//  Created by Don Krause on 6/2/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import <PebbleKit/PebbleKit.h>
#import "PWTimeViewController.h"
#import "NSMutableArray+QueueAdditions.h"
#import "PWTimeTZController.h"
#import "PWTimeKeys.h"
#import "AFNetworking/AFNetworking.h"
#import "Forecastr.h"

@interface PWTimeViewController () <PBPebbleCentralDelegate, CLLocationManagerDelegate>

@property (weak, nonatomic) IBOutlet UISegmentedControl *clockSelect;
@property (weak, nonatomic) IBOutlet UISwitch *clockEnabled;
@property (weak, nonatomic) IBOutlet UISegmentedControl *clockBackground;
@property (weak, nonatomic) IBOutlet UISegmentedControl *clockDisplay;
@property (weak, nonatomic) IBOutlet UILabel *locality;
@property (weak, nonatomic) IBOutlet UIButton *tzSelect;
@property (weak, nonatomic) IBOutlet UILabel *tzDisplay;
@property (weak, nonatomic) IBOutlet UILabel *timeDisplay;
@property (weak, nonatomic) IBOutlet UISwitch *singleMessage;

@property (weak, nonatomic) PBWatch *targetWatch;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSTimeZone *clockTZ;
@property (weak, nonatomic) NSTimer *clockUpdateTimer;
@property (weak, nonatomic) NSTimer *weatherUpdateTimer;
@property (strong, nonatomic) NSMutableArray *msgQueue;
@property (strong, nonatomic) NSLock *queueLock;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (weak, nonatomic) NSString *currentCity;
@property (weak, nonatomic) NSString *currentState;
@property (weak, nonatomic) NSString *currentCountry;
@property (strong, nonatomic) Forecastr *forecastr;
@property (strong, nonatomic) NSMutableDictionary *conditions;

@end

@implementation PWTimeViewController

dispatch_queue_t watchQueue;

NSMutableDictionary *update; // Need a strong pointer
NSString *currentCondition[3];
CLLocationCoordinate2D lastLocation;

- (CLLocationManager *) locationManager
{
    
    // Create the location manager if this object does not
    // already have one.
    if (_locationManager == nil)
        _locationManager = [[CLLocationManager alloc] init];
    
    return _locationManager;
}

- (NSMutableArray *) msgQueue
{
    if (_msgQueue == nil) {
        _msgQueue = [[NSMutableArray alloc] init];
    }
    return _msgQueue;
}

- (NSLock *) queueLock
{
    if (_queueLock == nil) {
        _queueLock = [[NSLock alloc] init];
    }
    return _queueLock;
}

- (Forecastr *) forecastr
{
    if (_forecastr == nil) {
        _forecastr = [[Forecastr alloc] init];
    }
    return _forecastr;
}

- (NSDictionary *) conditions
{
    
    if (_conditions == nil) {
        _conditions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@WEATHER_UNKNOWN, @"unknown", @WEATHER_CLEAR_DAY, @"clear-day", @WEATHER_CLEAR_NIGHT, @"clear-night", @WEATHER_RAIN, @"rain", @WEATHER_UNKNOWN, @"snow", @WEATHER_UNKNOWN, @"sleet", @WEATHER_UNKNOWN, @"wind", @WEATHER_UNKNOWN, @"fog", @WEATHER_CLOUDY, @"cloudy", @WEATHER_UNKNOWN, @"partly-cloudy-day", @WEATHER_UNKNOWN, @"partly-cloudy-night", nil];

    }
    return _conditions;
    
}

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

        } else {
            
            NSString *message = [NSString stringWithFormat:@"Blegh... %@ does NOT support AppMessages :'(", [watch name]];
            [[[UIAlertView alloc] initWithTitle:@"Connected..." message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            
        }
        
    }];

}

- (void)setClockTZ:(NSTimeZone *)clockTZ
{
    if (![_clockTZ isEqualToTimeZone:clockTZ]) {
        
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
    NSString *defTZ = [defaults stringForKey:[self makeKey:CLOCK_TZ_KEY]];
    if (defTZ == nil) {
        defTZ = [[NSTimeZone systemTimeZone] name];
    }
    self.clockTZ = [NSTimeZone timeZoneWithName:defTZ];
    
    if (_clockSelect.selectedSegmentIndex == 0) {
        self.clockEnabled.on = TRUE;
        self.clockEnabled.hidden = TRUE;
        self.locality.hidden = FALSE;
        self.tzSelect.hidden = TRUE;
    } else {
        self.clockEnabled.hidden = FALSE;
        self.locality.hidden = TRUE;
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
     @PBCOMM_WEATHER_KEY] forWatches:@[watchface]];
    
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

- (void)sendConfigToWatch
{

    if (self.singleMessage.isOn) {
        
        // First choice is to update all watches in one message. Doesn't work yet
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY, @PBCOMM_WEATHER_KEY] forWatches:@[@"Local", @"TZ1", @"TZ2"]];
        
    } else {
        
        // Update the local watch with all of the current settings
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY,
         @PBCOMM_WEATHER_KEY] forWatches:@[@"Local"]];
        
        // Update the TZ1 watch with all of the current settings
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY,
         @PBCOMM_WEATHER_KEY] forWatches:@[@"TZ1"]];
        
        // Update the TZ2 watch with all of the current settings
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY,
         @PBCOMM_WEATHER_KEY] forWatches:@[@"TZ2"]];
        
    }
    
}

- (void)sendMsgToWatch
{
    NSMutableDictionary *update;
    BOOL queueEmpty;
    
    [self.queueLock lock];
    queueEmpty = [self.msgQueue NSMAEmpty];
    [self.queueLock unlock];
    
    if (!queueEmpty) {
        [self.queueLock lock];
        update = [self.msgQueue NSMADequeue];
        [self.queueLock unlock];
        [_targetWatch appMessagesPushUpdate:update onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
            NSString *message = error ? [error localizedDescription] : @"Update sent!";
            if (![message isEqualToString:@"Update sent!"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *full_message = [NSString stringWithFormat:@"Error: %@, Update: %@", message, update];
                    [[[UIAlertView alloc] initWithTitle:nil message:full_message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];});
            }
        }];
        
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
            @try {

                int watchOffset;
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                update = [[NSMutableDictionary alloc] init];
                NSString *defTZ;
                NSString *displayTZ;
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
                                // Time Zone location string. If we have a geolocation, use that instead
                                if ((self.currentCity != nil) && (watchOffset == LOCAL_WATCH_OFFSET)) {
                                    displayTZ = [[self.currentCity stringByAppendingString:@", "] stringByAppendingString:self.currentState];
                                } else {
                                    defTZ = [defaults stringForKey:[self makeKey:CLOCK_TZ_KEY forWatch:watchface]];
                                    if (defTZ == nil) {
                                        defTZ = [[NSTimeZone systemTimeZone] name];
                                    }
                                    displayTZ = [self readableTZ:[NSTimeZone timeZoneWithName:defTZ]];
                                }
                                [update setObject:displayTZ forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_BACKGROUND_KEY:
                                [update setObject:[NSNumber numberWithInt8:[defaults integerForKey:[self makeKey:CLOCK_BACKGROUND_KEY forWatch:watchface]]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_12_24_DISPLAY_KEY:
                                [update setObject:[NSNumber numberWithInt8:[defaults integerForKey:[self makeKey:CLOCK_DISPLAY_KEY forWatch:watchface]]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_WEATHER_KEY:
 //                               NSLog(@"Weather code: %@\n", [NSNumber numberWithUint8:[[self.conditions objectForKey:currentCondition[watchOffset]] intValue]]);
                                [update setObject:[NSNumber numberWithUint8:[[self.conditions objectForKey:currentCondition[watchOffset]] intValue]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            default:
                                return;
                                
                        }
                        
                    }
                    
                }
                
                // Send data to watch:
                // See demos/feature_app_messages/weather.c in the native watch app SDK for the same definitions on the watch's end:
                [self.queueLock lock];
                [self.msgQueue NSMAEnqueue:update];
                [self.queueLock unlock];
                dispatch_async(watchQueue, ^{[self sendMsgToWatch];});
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

- (void)updateWeather {
        
    // Kick off asking for weather without specifying a time
    [self.forecastr getForecastForLatitude:lastLocation.latitude longitude:lastLocation.longitude time:nil exclusions:nil success:^(id JSON) {
        currentCondition[0] = [[JSON objectForKey:@"currently"] objectForKey:@"icon"];
        if ([currentCondition[0] isEqualToString:@""])
            currentCondition[0] = @"unknown";
        [self updateWatch:@[@PBCOMM_WEATHER_KEY] forWatches:@[@"Local"]];
        self.weatherUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1800.0 target:self selector:@selector(updateWeather:) userInfo:nil repeats:NO];
    } failure:^(NSError *error, id response) {
        currentCondition[0] = @"unknown";
        NSLog(@"Error while retrieving forecast: %@", [self.forecastr messageForError:error withResponse:response]);
        [self updateWatch:@[@PBCOMM_WEATHER_KEY] forWatches:@[@"Local", @"TZ1", @"TZ2"]];
        self.weatherUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:900.0 target:self selector:@selector(updateWeather:) userInfo:nil repeats:NO];
    }];
    
}

//
// Location methods/delegates
//
- (void)startStandardUpdates
{
    
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    
    // Set a movement threshold for new events.
    self.locationManager.distanceFilter = 500;
    
    [self.locationManager startUpdatingLocation];
    
}

- (void)startSignificantLocationChangeUpdates
{
    
    self.locationManager.delegate = self;
    [self.locationManager startMonitoringSignificantLocationChanges];
    
}

//
// Delegate method from the CLLocationManagerDelegate protocol.
//
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{

    if (self.weatherUpdateTimer != nil) {
        [self.weatherUpdateTimer invalidate];
    }
    
    CLLocation *location = [locations lastObject];
    CLGeocoder * geoCoder = [[CLGeocoder alloc] init];
    [geoCoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        
        CLPlacemark *placemark = [placemarks lastObject];
            
        // Remember where we were last found ...
        self.currentCity = [placemark.addressDictionary objectForKey:@"City"];
        self.currentState = [placemark.addressDictionary objectForKey:@"State"];
        self.currentCountry = [placemark.addressDictionary objectForKey:@"CountryCode"];
        [self.locality setText:[[[placemark.addressDictionary objectForKey:@"City"] stringByAppendingString:@", "] stringByAppendingString:[placemark.addressDictionary objectForKey:@"State"]]];
        lastLocation.latitude = location.coordinate.latitude;
        lastLocation.longitude = location.coordinate.longitude;
        [self updateWatch:@[@PBCOMM_CITY_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY] forWatches:@[@"Local"]];
        
        //
        // Since location changed, update weather as well
        //
        // Kick off asking for weather without specifying a time
        [self.forecastr getForecastForLatitude:location.coordinate.latitude longitude:location.coordinate.longitude time:nil exclusions:nil success:^(id JSON) {
            currentCondition[0] = [[JSON objectForKey:@"currently"] objectForKey:@"icon"];
            if ([currentCondition[0] isEqualToString:@""])
                currentCondition[0] = @"unknown";
            [self updateWatch:@[@PBCOMM_WEATHER_KEY] forWatches:@[@"Local"]];
            self.weatherUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1800.0 target:self selector:@selector(updateWeather:) userInfo:nil repeats:NO];
        } failure:^(NSError *error, id response) {
            currentCondition[0] = @"unknown";
            NSLog(@"Error while retrieving forecast: %@", [self.forecastr messageForError:error withResponse:response]);
            [self updateWatch:@[@PBCOMM_WEATHER_KEY] forWatches:@[@"Local", @"TZ1", @"TZ2"]];
            self.weatherUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:900.0 target:self selector:@selector(updateWeather:) userInfo:nil repeats:NO];
        }];
        
    }];

}

- (void)viewDidLoad
{
    
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.

    // We'd like to get called when Pebbles connect and disconnect, so become the delegate of PBPebbleCentral:
    [[PBPebbleCentral defaultCentral] setDelegate:self];
    [self setTargetWatch:[[PBPebbleCentral defaultCentral] lastConnectedWatch]];
    
    // This queue manages the messaging between the phone and the watch. It sequences messages to make sure one is complete and acknowledged
    // before the next is sent.
    watchQueue = dispatch_queue_create("com.dkkrause.PebbleWorldTime", NULL);
    
    self.forecastr.apiKey = @"3348fb0cf7f9595aa092b5c8150bdedb";
    
    self.dateFormatter.dateFormat = @"yyyy-MM-dd \n HH:mm:ss Z";
    self.clockUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateRunningClock:) userInfo:nil repeats:YES];
    
    [self startSignificantLocationChangeUpdates];
//    [self startStandardUpdates];
    
    [self loadClockFields];
    [self sendConfigToWatch];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    
    [super viewWillAppear:animated];
    
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
