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
#import "PWTimeTZSearchViewController.h"
#import "PWTimeKeys.h"
#import "AFNetworking/AFNetworking.h"
#import "Forecastr.h"

// #define PWDEBUG

@interface PWTimeViewController () <PBPebbleCentralDelegate, CLLocationManagerDelegate>

@property (weak, nonatomic) IBOutlet UISegmentedControl *clockSelect;
@property (weak, nonatomic) IBOutlet UISwitch *clockEnabled;
@property (weak, nonatomic) IBOutlet UISegmentedControl *clockBackground;
@property (weak, nonatomic) IBOutlet UISegmentedControl *clockDisplay;
@property (weak, nonatomic) IBOutlet UILabel *locality;
@property (weak, nonatomic) IBOutlet UIButton *tzSelect;
@property (weak, nonatomic) IBOutlet UILabel *tzDisplay;
@property (weak, nonatomic) IBOutlet UILabel *timeDisplay;
@property (strong, nonatomic) IBOutlet UILabel *tempDisplay;
@property (strong, nonatomic) IBOutlet UILabel *tempUpdateTime;
@property (strong, nonatomic) IBOutlet UILabel *tempHi;
@property (strong, nonatomic) IBOutlet UILabel *tempLo;
@property (strong, nonatomic) IBOutlet UILabel *sunrise;
@property (strong, nonatomic) IBOutlet UILabel *sunset;

@property (strong, nonatomic) PBWatch *targetWatch;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSTimeZone *clockTZ;
@property (strong, nonatomic) NSTimer *clockUpdateTimer;
@property (strong, nonatomic) NSTimer *weatherUpdateTimer;
@property (strong, nonatomic) NSMutableArray *msgQueue;
@property (strong, nonatomic) NSLock *queueLock;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) NSString *currentCity;
@property (strong, nonatomic) NSString *currentState;
@property (strong, nonatomic) NSString *currentCountry;
@property (strong, nonatomic) Forecastr *forecastr;
@property (strong, nonatomic) NSMutableDictionary *conditions;
@property (strong, nonatomic) NSMutableArray *currentCondition;
@property (strong, nonatomic) NSMutableArray *currentTemp;
@property (strong, nonatomic) NSMutableArray *dailyHiTemp;
@property (strong, nonatomic) NSMutableArray *dailyLoTemp;
@property (strong, nonatomic) NSMutableArray *sunriseTime;
@property (strong, nonatomic) NSMutableArray *sunsetTime;
@property (strong, nonatomic) NSMutableArray *lastKnownLocation;

@end

@implementation PWTimeViewController
{
    
    dispatch_queue_t watchQueue;
    
}

NSMutableDictionary *update;

#pragma mark - getters that alloc/init objects if uninitialized

- (NSDateFormatter *) dateFormatter
{
    if (_dateFormatter == nil) {
        _dateFormatter = [[NSDateFormatter alloc] init];
    }
    return _dateFormatter;
}

- (NSTimer *) clockUpdateTimer
{
    if (_clockUpdateTimer == nil) {
        _clockUpdateTimer = [[NSTimer alloc] init];
    }
    return _clockUpdateTimer;
}

- (NSTimer *) weatherUpdateTimer
{
    if (_weatherUpdateTimer == nil) {
        _weatherUpdateTimer = [[NSTimer alloc] init];
    }
    return _weatherUpdateTimer;
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

- (CLLocationManager *) locationManager
{
    if (_locationManager == nil) {
        _locationManager = [[CLLocationManager alloc] init];
    }
    return _locationManager;
}

- (Forecastr *) forecastr
{
    if (_forecastr == nil) {
        _forecastr = [[Forecastr alloc] init];
    }
    return _forecastr;
}

- (NSMutableArray *) currentCondition
{
    if (_currentCondition == nil) {
        _currentCondition = [[NSMutableArray alloc] init];
    }
    return _currentCondition;
}

- (NSMutableArray *) currentTemp
{
    if (_currentTemp == nil) {
        _currentTemp = [[NSMutableArray alloc] init];
    }
    return _currentTemp;
}

- (NSMutableArray *) dailyHiTemp
{
    if (_dailyHiTemp == nil) {
        _dailyHiTemp = [[NSMutableArray alloc] init];
    }
    return _dailyHiTemp;
}

- (NSMutableArray *) dailyLoTemp
{
    if (_dailyLoTemp == nil) {
        _dailyLoTemp = [[NSMutableArray alloc] init];
    }
    return _dailyLoTemp;
}

- (NSMutableArray *) sunriseTime
{
    if (_sunriseTime == nil) {
        _sunriseTime = [[NSMutableArray alloc] init];
    }
    return _sunriseTime;
}

- (NSMutableArray *) sunsetTime
{
    if (_sunsetTime == nil) {
        _sunsetTime = [[NSMutableArray alloc] init];
    }
    return _sunsetTime;
}

- (NSMutableArray *) lastKnownLocation
{
    if (_lastKnownLocation == nil) {
        _lastKnownLocation = [[NSMutableArray alloc] init];
    }
    return _lastKnownLocation;
}

- (NSMutableDictionary *) conditions
{
    
    if (_conditions == nil) {
        _conditions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@WEATHER_UNKNOWN, @"unknown", @WEATHER_CLEAR_DAY, @"clear-day", @WEATHER_CLEAR_NIGHT, @"clear-night", @WEATHER_RAIN, @"rain", @WEATHER_UNKNOWN, @"snow", @WEATHER_UNKNOWN, @"sleet", @WEATHER_UNKNOWN, @"wind", @WEATHER_UNKNOWN, @"fog", @WEATHER_CLOUDY, @"cloudy", @WEATHER_PARTLY_CLOUDY_DAY, @"partly-cloudy-day", @WEATHER_PARTLY_CLOUDY_NIGHT, @"partly-cloudy-night", nil];

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
//    NSString *tzAbbr = [tz abbreviation];
//    tzAbbr = [[@" (" stringByAppendingString:tzAbbr] stringByAppendingString:@")"];
//    cityName = [[cityName stringByReplacingOccurrencesOfString:@"_" withString:@" "] stringByAppendingString:tzAbbr];
    
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
    [defaults setObject:[NSNumber numberWithUint8:[sender selectedSegmentIndex]] forKey:[self makeKey:CLOCK_BACKGROUND_KEY]];
    [defaults synchronize];
    
    [self updateWatch:@[@PBCOMM_BACKGROUND_KEY] forWatches:@[[self.clockSelect titleForSegmentAtIndex:[self.clockSelect  selectedSegmentIndex]]]];

}

- (IBAction)timeDisplayChanged:(id)sender {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithUint8:[sender selectedSegmentIndex]] forKey:[self makeKey:CLOCK_DISPLAY_KEY]];
    [defaults synchronize];
    
    [self updateWatch:@[@PBCOMM_12_24_DISPLAY_KEY] forWatches:@[[self.clockSelect titleForSegmentAtIndex:[self.clockSelect selectedSegmentIndex]]]];
    
}


- (IBAction)updateWatchData:(id)sender {
    
    [self sendConfigToWatch];
}

//
// Method to execute every second to update the clock on the iPhone display
//
- (void)updateRunningClock:(id)sender
{
    
    NSDate *date = [[NSDate alloc] init];   // Get the current date and time
    
    // Print the time in the selected time zone
    [self.dateFormatter setTimeZone:self.clockTZ];
    self.timeDisplay.text = [self.dateFormatter stringFromDate:date];
    [self.timeDisplay setNeedsDisplay];
    
}

#pragma mark - Watch communication methods

- (void)sendConfigToWatch
{

    // Update the local watch with all of the current settings
    [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY, @PBCOMM_WEATHER_KEY, @PBCOMM_TEMPERATURE_KEY, @PBCOMM_HI_TEMP_KEY, @PBCOMM_LO_TEMP_KEY, @PBCOMM_SUNRISE_KEY, @PBCOMM_SUNSET_KEY] forWatches:@[@"Local"]];
    
    // Update the TZ1 watch with all of the current settings
    [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY, @PBCOMM_WEATHER_KEY, @PBCOMM_TEMPERATURE_KEY, @PBCOMM_HI_TEMP_KEY, @PBCOMM_LO_TEMP_KEY, @PBCOMM_SUNRISE_KEY, @PBCOMM_SUNSET_KEY] forWatches:@[@"TZ"]];
    
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
 * updateWatch:forWatches - sends the data associated with the key parameter to the specified watch to update the information
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
                    
                    // There are two possible watchfaces, local time and time zone 1. Which face are we updating?
                    if ([watchface isEqualToString:@"Local"]) {
                        watchOffset = LOCAL_WATCH_OFFSET;
                    } else if ([watchface isEqualToString:@"TZ"]) {
                        watchOffset = TZ_OFFSET;
                    } else {
                        return;
                    }
#ifdef PWDEBUG
                    NSLog(@"Updating Watch: %@, watchOffset: %2d\n", watchface, watchOffset);
#endif
                    for (NSNumber *key in keys) {
                        
#ifdef PWDEBUG
                        NSLog(@"Updating key: %@\n", key);
#endif
                        // Now we need to put together the tuples to be sent to the Pebble watch
                        switch ([key intValue]) {
                                
                            case PBCOMM_WATCH_ENABLED_KEY:
                                // Is the clock enabled?
                                isOn = (uint8_t) [[NSNumber numberWithBool:[defaults boolForKey:[self makeKey:CLOCK_ENABLED_KEY forWatch:watchface]]] uint8Value];
                                if (watchOffset == LOCAL_WATCH_OFFSET) isOn = TRUE;
#ifdef PWDEBUG
                                NSLog(@"Enabled: %2d\n", isOn);
#endif
                                [update setObject:[NSNumber numberWithUint8:isOn] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_GMT_SEC_OFFSET_KEY:
                                // GMT Offset
                                defTZ = [defaults stringForKey:[self makeKey:CLOCK_TZ_KEY forWatch:watchface]];
                                if (defTZ == nil) {
                                    defTZ = [[NSTimeZone systemTimeZone] name];
                                }
                                seconds = [[NSTimeZone timeZoneWithName:defTZ] secondsFromGMT];
#ifdef PWDEBUG
                                NSLog(@"GMT Offset: %8d\n", seconds);
#endif
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
#ifdef PWDEBUG
                                NSLog(@"City: %@", displayTZ);
#endif
                                [update setObject:displayTZ forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_BACKGROUND_KEY:
#ifdef PWDEBUG
                                NSLog(@"Background: %@\n", [NSNumber numberWithUint8:[defaults integerForKey:[self makeKey:CLOCK_BACKGROUND_KEY forWatch:watchface]]]);
#endif

                                [update setObject:[NSNumber numberWithUint8:[defaults integerForKey:[self makeKey:CLOCK_BACKGROUND_KEY forWatch:watchface]]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_12_24_DISPLAY_KEY:
#ifdef PWDEBUG
                                NSLog(@"12/24 hour: %@\n", [NSNumber numberWithUint8:[defaults integerForKey:[self makeKey:CLOCK_DISPLAY_KEY forWatch:watchface]]]);
#endif
                                [update setObject:[NSNumber numberWithUint8:[defaults integerForKey:[self makeKey:CLOCK_DISPLAY_KEY forWatch:watchface]]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_WEATHER_KEY:
#ifdef PWDEBUG
                                NSLog(@"Condition: %@, CondVal: %2d\n", [self.currentCondition objectAtIndex:(watchOffset/16)], [[self.conditions objectForKey:[self.currentCondition objectAtIndex:(watchOffset/16)]] uint8Value]);
#endif
                                [update setObject:[NSNumber numberWithUint8:[[self.conditions objectForKey:[self.currentCondition objectAtIndex:(watchOffset/16)]] uint8Value]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_TEMPERATURE_KEY:
#ifdef PWDEBUG
                                NSLog(@"Temp: %4d\n", [[self.currentTemp objectAtIndex:(watchOffset/16)] int8Value]);
#endif
                                [update setObject:[NSNumber numberWithInt8:(int8_t)[[self.currentTemp objectAtIndex:(watchOffset/16)] int8Value]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_HI_TEMP_KEY:
#ifdef PWDEBUG
                                NSLog(@"Hi Temp: %4d\n", [[self.dailyHiTemp objectAtIndex:(watchOffset/16)] int8Value]);
#endif
                                [update setObject:[NSNumber numberWithInt8:(int8_t)[[self.dailyHiTemp objectAtIndex:(watchOffset/16)] int8Value]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_LO_TEMP_KEY:
#ifdef PWDEBUG
                                NSLog(@"Lo Temp: %4d\n", [[self.dailyLoTemp objectAtIndex:(watchOffset/16)] int8Value]);
#endif
                                [update setObject:[NSNumber numberWithInt8:(int8_t)[[self.dailyLoTemp objectAtIndex:(watchOffset/16)] int8Value]] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_SUNRISE_KEY:
#ifdef PWDEBUG
                                NSLog(@"Sunrise: %@", [self.sunriseTime objectAtIndex:(watchOffset/16)]);
#endif
                                [update setObject:[self.sunriseTime objectAtIndex:(watchOffset/16)] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            case PBCOMM_SUNSET_KEY:
#ifdef PWDEBUG
                                NSLog(@"Sunset: %@", [self.sunsetTime objectAtIndex:(watchOffset/16)]);
#endif
                                [update setObject:[self.sunsetTime objectAtIndex:(watchOffset/16)] forKey:[NSNumber numberWithInt:(watchOffset + [key intValue])]];
                                break;
                            default:
                                return;
                                
                        }
                        
                    }
                
                }
                
                // Send data to watch:
                // See demos/feature_app_messages/weather.c in the native watch app SDK for the same definitions on the watch's end:
#ifdef PWDEBUG
                NSLog(@"Full Update:\n%@\n\n", update);
#endif
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

#pragma mark - Weather methods

//
// Methods to handle weather, both getting info and handling timers to refresh information
//
- (void)startWeatherUpdateTimer:(NSTimeInterval) ti
{
    if (self.weatherUpdateTimer != nil) {
        [self.weatherUpdateTimer invalidate];
    }
    self.weatherUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(updateAllWeather:) userInfo:nil repeats:NO];
}

- (void)stopWeatherUpdateTimer
{
    if (self.weatherUpdateTimer != nil) {
        [self.weatherUpdateTimer invalidate];
    }
}

- (void)updateAllWeather:(id)sender
{
    [self updateWeather:@"Local"];
    [self updateWeather:@"TZ"];
}

- (void)updateWeather:(NSString *)watch
{        
    
    // There are two possible watchfaces, local time and time zone. Which face are we updating?
    int watchNum;
    if ([watch isEqualToString:@"Local"]) {
        watchNum = LOCAL_WATCH_OFFSET / 16;
    } else if ([watch isEqualToString:@"TZ"]) {
        watchNum = TZ_OFFSET / 16;
    } else {
        return;
    }
    CLLocation *lastLocation = [self.lastKnownLocation objectAtIndex:watchNum];
    if (lastLocation != nil) {
        
#ifdef PWDEBUG
        NSLog(@"updateWeather: Last known location for watch: %@, latitude: %3.8f, %3.8f\n", watch, lastLocation.coordinate.latitude, lastLocation.coordinate.longitude);
#endif
        [self.forecastr getForecastForLatitude:lastLocation.coordinate.latitude longitude:lastLocation.coordinate.longitude time:nil exclusions:nil success:^(id JSON) {
#ifdef PWDEBUG
            NSLog(@"JSON:\n %@\n\n", JSON);
#endif
            // Print the time in the selected time zone
            NSDate *date = [[NSDate alloc] init];   // Get the current date and time
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"HH:mm";
            [formatter setTimeZone:self.clockTZ];
            
            [self.currentTemp setObject:[NSNumber numberWithInt8:(int8_t)([[[JSON objectForKey:@"currently"] objectForKey:@"temperature"] doubleValue] + 0.5)]atIndexedSubscript:watchNum];
            self.tempDisplay.text = [[self.currentTemp objectAtIndex:0]stringValue];
            [self.currentCondition setObject:[[JSON objectForKey:@"currently"] objectForKey:@"icon"] atIndexedSubscript:watchNum];
            if ([[self.currentCondition objectAtIndex:0] isEqualToString:@""])
                [self.currentCondition setObject:@"unknown" atIndexedSubscript:watchNum];
            [self.dailyHiTemp setObject:[NSNumber numberWithInt8:(int8_t)([[[[[JSON objectForKey:@"daily"] objectForKey:@"data"] firstObject] objectForKey:@"temperatureMax"] doubleValue] + 0.5)] atIndexedSubscript:watchNum];
            [self.dailyLoTemp setObject:[NSNumber numberWithInt8:(int8_t)([[[[[JSON objectForKey:@"daily"] objectForKey:@"data"]  firstObject]objectForKey:@"temperatureMin"] doubleValue] + 0.5)] atIndexedSubscript:watchNum];
            NSDate *sunriseDate = [[NSDate alloc] initWithTimeIntervalSince1970:[[[[[JSON objectForKey:@"daily"] objectForKey:@"data"]  firstObject]objectForKey:@"sunriseTime"] doubleValue]];
            NSDate *sunsetDate = [[NSDate alloc] initWithTimeIntervalSince1970:[[[[[JSON objectForKey:@"daily"] objectForKey:@"data"] firstObject] objectForKey:@"sunsetTime"] doubleValue]];
            [self.sunriseTime setObject:[formatter stringFromDate:sunriseDate] atIndexedSubscript:watchNum];
            [self.sunsetTime setObject:[formatter stringFromDate:sunsetDate] atIndexedSubscript:watchNum];
            [self updateWatch:@[@PBCOMM_WEATHER_KEY, @PBCOMM_TEMPERATURE_KEY, @PBCOMM_HI_TEMP_KEY, @PBCOMM_LO_TEMP_KEY, @PBCOMM_SUNRISE_KEY, @PBCOMM_SUNSET_KEY] forWatches:@[watch]];
            [self startWeatherUpdateTimer:1800.0];
            
            // Display the time on the phone in the selected time zone
            self.tempHi.text = [[self.dailyHiTemp objectAtIndex:watchNum] stringValue];
            self.tempLo.text = [[self.dailyLoTemp objectAtIndex:watchNum] stringValue];
            self.sunrise.text = [self.sunriseTime objectAtIndex:watchNum];
            self.sunset.text = [self.sunsetTime objectAtIndex:watchNum];
            self.tempUpdateTime.text = [formatter stringFromDate:date];
            
        } failure:^(NSError *error, id response) {
            
            [self.currentTemp setObject:[NSNumber numberWithInt8:-99] atIndexedSubscript:watchNum];
            [self.dailyHiTemp setObject:[NSNumber numberWithInt8:-99] atIndexedSubscript:watchNum];
            [self.dailyLoTemp setObject:[NSNumber numberWithInt8:-99] atIndexedSubscript:watchNum];
            self.tempDisplay.text = [[self.currentTemp objectAtIndex:watchNum] stringValue];
            [self.currentCondition setObject:@"unknown" atIndexedSubscript:watchNum];
            [self.sunriseTime setObject:@"iphone" atIndexedSubscript:watchNum];
            [self.sunsetTime setObject:@"iphone" atIndexedSubscript:watchNum];
#ifdef PWDEBUG
            NSLog(@"Error while retrieving forecast: %@", [self.forecastr messageForError:error withResponse:response]);
#endif
            [self updateWatch:@[@PBCOMM_WEATHER_KEY, @PBCOMM_TEMPERATURE_KEY, @PBCOMM_HI_TEMP_KEY, @PBCOMM_LO_TEMP_KEY, @PBCOMM_SUNRISE_KEY, @PBCOMM_SUNSET_KEY] forWatches:@[watch]];
            [self startWeatherUpdateTimer:900.0];
            
        }];
        
    } else {
        [self startWeatherUpdateTimer:30.0];
    }
    
}

#pragma mark - Location methods

//
// Location methods/delegates. Starts and stops are called by the App delegate when the app goes inactive/active
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

- (void)stopSignificantLocationChangeUpdates
{
    [self.locationManager stopMonitoringSignificantLocationChanges];
    self.locationManager.delegate = nil;
}

//
// Delegate method from the CLLocationManagerDelegate protocol.
//
#pragma mark - CLLocationManager delegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{

    [self stopWeatherUpdateTimer];  // In case one is running
    
    CLLocation *location = [locations lastObject];
    CLGeocoder * geoCoder = [[CLGeocoder alloc] init];
    [geoCoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        
        CLPlacemark *placemark = [placemarks lastObject];
            
        // Remember where we were last found ...
        self.currentCity = [placemark.addressDictionary objectForKey:@"City"];
        self.currentState = [placemark.addressDictionary objectForKey:@"State"];
        self.currentCountry = [placemark.addressDictionary objectForKey:@"CountryCode"];
        [self.locality setText:[[[placemark.addressDictionary objectForKey:@"City"] stringByAppendingString:@", "] stringByAppendingString:[placemark.addressDictionary objectForKey:@"State"]]];
        [self.lastKnownLocation setObject:location atIndexedSubscript:0];
#ifdef PWDEBUG
        NSLog(@"locationManager: lastKnownLocation: latitude: %3.8f, longitude: %3.8f\n", location.coordinate.latitude, location.coordinate.longitude);
#endif
        [self updateWatch:@[@PBCOMM_CITY_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY] forWatches:@[@"Local"]];
        
        //
        // Since location changed, update weather as well
        //
        [self updateWeather:@"Local"];
        
    }];

}

#pragma mark - UIViewController delegate methods

- (void)viewDidLoad
{
    
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.
    [self.currentCondition setObject:@"unknown" atIndexedSubscript:0];
    [self.currentCondition setObject:@"unknown" atIndexedSubscript:1];
    
    [self.currentTemp setObject:[NSNumber numberWithInt8:(int8_t)-100] atIndexedSubscript:0];
    [self.currentTemp setObject:[NSNumber numberWithInt8:(int8_t)-100] atIndexedSubscript:1];
    [self.dailyHiTemp setObject:[NSNumber numberWithInt8:(int8_t)-100] atIndexedSubscript:0];
    [self.dailyHiTemp setObject:[NSNumber numberWithInt8:(int8_t)-100] atIndexedSubscript:1];
    [self.dailyLoTemp setObject:[NSNumber numberWithInt8:(int8_t)-100] atIndexedSubscript:0];
    [self.dailyLoTemp setObject:[NSNumber numberWithInt8:(int8_t)-100] atIndexedSubscript:1];
    
    [self.sunriseTime setObject:@"unknown" atIndexedSubscript:0];
    [self.sunriseTime setObject:@"unknown" atIndexedSubscript:1];
    [self.sunsetTime setObject:@"unknown" atIndexedSubscript:0];
    [self.sunsetTime setObject:@"unknown" atIndexedSubscript:1];
    
    // We'd like to get called when Pebbles connect and disconnect, so become the delegate of PBPebbleCentral:
    [[PBPebbleCentral defaultCentral] setDelegate:self];
    [self setTargetWatch:[[PBPebbleCentral defaultCentral] lastConnectedWatch]];
    
    // This queue manages the messaging between the phone and the watch. It sequences messages to make sure one is complete and acknowledged
    // before the next is sent.
    watchQueue = dispatch_queue_create("com.dkkrause.PebbleWorldTime", NULL);
    self.forecastr.apiKey = @"3348fb0cf7f9595aa092b5c8150bdedb";
    self.dateFormatter.dateFormat = @"yyyy-MM-dd \n HH:mm:ss Z";
    
    
}

- (void)viewWillAppear:(BOOL)animated
{
    
    [super viewWillAppear:animated];
    
    self.clockUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateRunningClock:) userInfo:nil repeats:YES];
    [self loadClockFields];
    [self sendConfigToWatch];
    
    
}

- (void)didReceiveMemoryWarning
{
    
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
    if ([segue.identifier isEqualToString:@"toTZ"]) {
        PWTimeTZSearchViewController *tzController = segue.destinationViewController;
        [tzController setDelegate:self];
        [tzController setClockTZ:self.clockTZ];
    }
}

#pragma mark - PBPebbleCentral delegate methods

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
