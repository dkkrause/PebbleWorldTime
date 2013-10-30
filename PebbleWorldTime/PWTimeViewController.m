//
//  PWTimeFirstViewController.m
//  PebbleWorldTime
//
//  Created by Don Krause on 6/2/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <PebbleKit/PebbleKit.h>
#import <MapKit/MapKit.h>
#import "PWTimeKeys.h"                          // Contstants for phone-watch communication
#import "PWTimeViewController.h"                // Main view controller
#import "NSMutableArray+QueueAdditions.h"       // Added queue functions to a NSMutableArray
#import "NSString+USStateMap.h"                 // Converts from state name to abbreviation and vice-versa

// Support classes, added via Pods
#import "AFNetworking/AFNetworking.h"           // Forecastr relies on AFNetworking
#import "Forecastr.h"                           // To get weather on the watch

@interface PWTimeViewController () <PBPebbleCentralDelegate, CLLocationManagerDelegate, MKMapViewDelegate>

#pragma mark - Outlets for buttons/selectors, etc.
@property (weak, nonatomic)   IBOutlet UISegmentedControl *clockSelect;
@property (weak, nonatomic)   IBOutlet UISwitch           *clockEnabled;
@property (weak, nonatomic)   IBOutlet UISegmentedControl *clockBackground;
@property (weak, nonatomic)   IBOutlet UISegmentedControl *clockDisplay;
@property (weak, nonatomic)   IBOutlet UISwitch           *trackGPSUpdates;
@property (strong, nonatomic) IBOutlet MKMapView          *smallMap;

@property (nonatomic) PBWatch           *targetWatch;
@property (nonatomic) NSNumber          *numDisconnects;
@property (nonatomic) id                 watchUpdateHandler;
@property (nonatomic) NSMutableArray    *msgQueue;
@property (nonatomic) NSLock            *queueLock;
@property (nonatomic) NSMutableArray    *clocks;
@property (nonatomic) MKPointAnnotation *annot;


@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) Forecastr         *forecastr;
@property (nonatomic) NSTimer           *weatherTimer;
@property (nonatomic) NSArray           *conditions;
@property (copy)      void               (^completionHandler)();

@end

@implementation PWTimeViewController
{
    dispatch_queue_t watchQueue;
}

#define AppDelegate ((PWTimeAppDelegate *)[UIApplication sharedApplication].delegate)

NSMutableDictionary *update;

#pragma mark - Location formatting class methods

+ (NSString *)getDisplayCity:(CLPlacemark *)placemark
{
    // Handle situation where there is no city
    NSString *displayCity;
    if (!([placemark.addressDictionary objectForKey:@"City"] == nil)) {
        displayCity = [placemark.addressDictionary objectForKey:@"City"];
    } else {
        displayCity = [placemark.addressDictionary objectForKey:@"State"];
    }
    return displayCity;
}

+ (NSString *)getDisplayState:(CLPlacemark *)placemark
{
    // Handle situation where there is no city
    NSString *displayState;
    if (!([placemark.addressDictionary objectForKey:@"City"] == nil)) {
        if ([[placemark.addressDictionary objectForKey:@"CountryCode"] isEqualToString:@"US"])
            displayState = [placemark.addressDictionary objectForKey:@"State"];
        else
            displayState = [placemark.addressDictionary objectForKey:@"Country"];
    } else {
        displayState = [placemark.addressDictionary objectForKey:@"Country"];
    }
    return displayState;
}

#pragma mark - getters with lazy initialization

- (NSNumber *)numDisconnects
{
    if (_numDisconnects == nil) {
        _numDisconnects = [[NSNumber alloc] initWithInt:0];
    }
    return _numDisconnects;
}

- (NSMutableArray *)msgQueue
{
    if (_msgQueue == nil) {
        _msgQueue = [[NSMutableArray alloc] init];
    }
    return _msgQueue;
}

- (NSLock *)queueLock
{
    if (_queueLock == nil) {
        _queueLock = [[NSLock alloc] init];
    }
    return _queueLock;
}

- (CLLocationManager *)locationManager
{
    if (_locationManager == nil) {
        _locationManager = [[CLLocationManager alloc] init];
    }
    return _locationManager;
}

- (Forecastr *)forecastr
{
    if (_forecastr == nil) {
        _forecastr = [[Forecastr alloc] init];
    }
    return _forecastr;
}

- (NSMutableArray *)clocks
{
    if (_clocks == nil) {
        _clocks = [[NSMutableArray alloc] initWithCapacity:2];
    }
    return _clocks;
}

- (NSArray *)conditions
{    
    if (_conditions == nil) {
        _conditions = [[NSArray alloc] initWithObjects: @"unknown", @"clear-day", @"clear-night", @"rain", @"snow", @"sleet",
                                                        @"wind", @"fog", @"cloudy", @"partly-cloudy-day", @"partly-cloudy-night",
                                                        nil];
    }
    return _conditions;    
}

- (MKPointAnnotation *)annot
{
    if (_annot == nil) {
        _annot = [[MKPointAnnotation alloc] init];
    }
    return _annot;
}

#pragma mark - IBActions for associated buttons/selectors on screen

- (IBAction)clockSelected:(id)sender
{
    [self setViewElements:[self.clocks objectAtIndex:[sender selectedSegmentIndex]]];    // Set up the small map view on the main screen
    [self showClockOnSmallMap:[self.clocks objectAtIndex:[self.clockSelect selectedSegmentIndex]]];
}

- (IBAction)redrawMap:(id)sender {
    [self showClockOnSmallMap:[self.clocks objectAtIndex:[self.clockSelect selectedSegmentIndex]]];
}

- (IBAction)clockEnabledSwitchChanged:(id)sender
{
    
    PWClock *clock = [self.clocks objectAtIndex:self.clockSelect.selectedSegmentIndex];
    clock.enabled = [NSNumber numberWithBool:[sender isOn]];
    if ([clock.enabled boolValue]) {
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_CITY_KEY, @PBCOMM_12_24_DISPLAY_KEY,
         @PBCOMM_WEATHER_KEY, @PBCOMM_TEMPERATURE_KEY] forClocks:@[clock]];
    } else {
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY] forClocks:@[clock]];
//        [self updateWeather:clock];
    }
    
}

- (IBAction)clockBackgroundSegmentSelected:(id)sender
{    
    PWClock *clock = [self.clocks objectAtIndex:self.clockSelect.selectedSegmentIndex];
    clock.backgroundMode = [NSNumber numberWithInt:[sender selectedSegmentIndex]];
    [self updateWatch:@[@PBCOMM_BACKGROUND_KEY] forClocks:@[clock]];
}

- (IBAction)timeDisplayChanged:(id)sender
{    
    PWClock *clock = [self.clocks objectAtIndex:self.clockSelect.selectedSegmentIndex];
    clock.displayFormat = [NSNumber numberWithInt:[sender selectedSegmentIndex]];
    [self updateWatch:@[@PBCOMM_12_24_DISPLAY_KEY] forClocks:@[clock]];
}


- (IBAction)updateWatchData:(id)sender
{    
    // Update the local watch with all of the current settings
//    [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY, @PBCOMM_WEATHER_KEY, @PBCOMM_TEMPERATURE_KEY, @PBCOMM_HI_TEMP_KEY, @PBCOMM_LO_TEMP_KEY, @PBCOMM_SUNRISE_HOUR_KEY, @PBCOMM_SUNRISE_MIN_KEY, @PBCOMM_SUNSET_HOUR_KEY, @PBCOMM_SUNSET_MIN_KEY] forClocks:@[[self.clocks objectAtIndex:self.clockSelect.selectedSegmentIndex]]];
    
    [self updateWeather:[self.clocks objectAtIndex:self.clockSelect.selectedSegmentIndex]];
    
}

- (IBAction)clearNumDisconnects:(id)sender
{
    self.numDisconnects = [[NSNumber alloc] initWithInt:0];
    [self updateDisconnectIndicator];
}

- (IBAction)trackLocationChanges:(id)sender
{    
    if ([sender isKindOfClass:[UISwitch class]]) {
        UISwitch *locSwitch = (UISwitch *)sender;
        if (locSwitch.on) {
            [self startSignificantLocationChangeUpdates];
            [AppDelegate enableBackgroundFetch];
        } else {
            [self stopSignificantLocationChangeUpdates];
            [AppDelegate disableBackgroundFetch];
        }
    }
}

#pragma mark - Watch communication methods

- (void)sendConfigToWatch
{
    // Update the local watch with all of the current settings
    [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY, @PBCOMM_WEATHER_KEY, @PBCOMM_TEMPERATURE_KEY, @PBCOMM_HI_TEMP_KEY, @PBCOMM_LO_TEMP_KEY, @PBCOMM_SUNRISE_HOUR_KEY, @PBCOMM_SUNRISE_MIN_KEY, @PBCOMM_SUNSET_HOUR_KEY, @PBCOMM_SUNSET_MIN_KEY] forClocks:@[[self.clocks objectAtIndex:0]]];
    
    // Update the TZ watch with all of the current settings
    [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_CITY_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY, @PBCOMM_WEATHER_KEY, @PBCOMM_TEMPERATURE_KEY, @PBCOMM_HI_TEMP_KEY, @PBCOMM_LO_TEMP_KEY, @PBCOMM_SUNRISE_HOUR_KEY, @PBCOMM_SUNRISE_MIN_KEY, @PBCOMM_SUNSET_HOUR_KEY, @PBCOMM_SUNSET_MIN_KEY] forClocks:@[[self.clocks objectAtIndex:1]]];
}

- (void)sendMsgToPebble
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
 * updateWatch:forClocks - sends the data associated with the key parameter to the specified clock to update the information
 */
- (void)updateWatch:(NSArray *)keys forClocks:(NSArray *)clocks
{
    [self updateWatch:keys forClocks:clocks withCompletionHandler:nil];
}

- (void)updateWatch:(NSArray *)keys forClocks:(NSArray *)clocks withCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
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

                int clockOffset;
                int clockNum;
                update = [[NSMutableDictionary alloc] init];
                NSString *timeZoneName;
                NSString *displayCity;
                int32_t gmtOffset;
                
                for (PWClock *clock in clocks) {
                    
                    // There are two possible watchfaces, local time and time zone 1. Which face are we updating?
                    if ([clock.name isEqualToString:@"Local"]) {
                        clockOffset = LOCAL_WATCH_OFFSET;
                        clockNum = 0;
                    } else if ([clock.name isEqualToString:@"TZ"]) {
                        clockOffset = TZ_OFFSET;
                        clockNum = 1;
                    } else {
                        return;
                    }
#ifdef PWDEBUG
                    NSLog(@"Updating Watch: %@, clockOffset: %2d\n", clock.name, clockOffset);
#endif
                    for (NSNumber *key in keys) {                        
#ifdef PWDEBUG
                        NSLog(@"Updating key: %2d\n", [key intValue] + clockOffset);
#endif
                        // Now we need to put together the tuples to be sent to the Pebble watch
                        switch ([key intValue]) {
                                
                            case PBCOMM_WATCH_ENABLED_KEY:
                                // Is the clock enabled?
#ifdef PWDEBUG
                                NSLog(@"Enabled: %2d\n", (uint8_t)[clock.enabled boolValue]);
#endif
                                [update setObject:[NSNumber numberWithUint8:(uint8_t)[clock.enabled boolValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_GMT_SEC_OFFSET_KEY:
                                // GMT Offset
                                timeZoneName = clock.currentTZ;
                                if ([timeZoneName isEqualToString:@""]) {
                                    timeZoneName = [[NSTimeZone systemTimeZone] name];
                                }
                                gmtOffset = [[NSTimeZone timeZoneWithName:timeZoneName] secondsFromGMT];
#ifdef PWDEBUG
                                NSLog(@"GMT Offset: %8d\n", gmtOffset);
#endif
                                [update setObject:[NSNumber numberWithInt32:gmtOffset] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_CITY_KEY:
                                displayCity = [[clock.city stringByAppendingString:@", "] stringByAppendingString:clock.state];
#ifdef PWDEBUG
                                NSLog(@"City: %@", displayCity);
#endif
                                [update setObject:displayCity forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_BACKGROUND_KEY:
#ifdef PWDEBUG
                                NSLog(@"Background: %@\n", [NSNumber numberWithUint8:(uint8_t)[clock.backgroundMode intValue]]);
#endif
                                [update setObject:[NSNumber numberWithUint8:(uint8_t)[clock.backgroundMode intValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_12_24_DISPLAY_KEY:
#ifdef PWDEBUG
                                NSLog(@"12/24 hour: %@\n", [NSNumber numberWithUint8:(uint8_t)[clock.displayFormat intValue]]);
#endif
                                [update setObject:[NSNumber numberWithUint8:(uint8_t)[clock.displayFormat intValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_WEATHER_KEY:
#ifdef PWDEBUG
                                NSLog(@"Condition: %@, CondVal: %2d\n", clock.currentCondition, (uint8_t)[self.conditions indexOfObject:clock.currentCondition]);
#endif
                                [update setObject:[NSNumber numberWithUint8:(uint8_t)[self.conditions indexOfObject:clock.currentCondition]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_TEMPERATURE_KEY:
#ifdef PWDEBUG
                                NSLog(@"Temp: %4d\n", (int8_t)[clock.currentTemp intValue]);
#endif
                                [update setObject:[NSNumber numberWithInt8:(int8_t)[clock.currentTemp intValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_HI_TEMP_KEY:
#ifdef PWDEBUG
                                NSLog(@"Hi Temp: %4d\n", [clock.dailyHiTemp intValue]);
#endif
                                [update setObject:[NSNumber numberWithInt8:(int8_t)[clock.dailyHiTemp intValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_LO_TEMP_KEY:
#ifdef PWDEBUG
                                NSLog(@"Lo Temp: %4d\n", [clock.dailyLoTemp intValue]);
#endif
                                [update setObject:[NSNumber numberWithInt8:(int8_t)[clock.dailyLoTemp intValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_SUNRISE_HOUR_KEY:
#ifdef PWDEBUG
                                NSLog(@"Sunrise Hour: %@", [NSNumber numberWithUint8:[[clock.sunriseTime substringWithRange:NSMakeRange(0,2)] intValue]]);
#endif
                                [update setObject:[NSNumber numberWithUint8:[[clock.sunriseTime substringWithRange:NSMakeRange(0,2)] intValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_SUNRISE_MIN_KEY:
#ifdef PWDEBUG
                                NSLog(@"Sunrise Min: %@", [NSNumber numberWithUint8:[[clock.sunriseTime substringWithRange:NSMakeRange(3,2)] intValue]]);
#endif
                                [update setObject:[NSNumber numberWithUint8:[[clock.sunriseTime substringWithRange:NSMakeRange(3,2)] intValue]]  forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_SUNSET_HOUR_KEY:
#ifdef PWDEBUG
                                NSLog(@"Sunset Hour: %@", [NSNumber numberWithUint8:[[clock.sunsetTime substringWithRange:NSMakeRange(0,2)] intValue]]);
#endif
                                [update setObject:[NSNumber numberWithUint8:[[clock.sunsetTime substringWithRange:NSMakeRange(0,2)] intValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                                break;
                            case PBCOMM_SUNSET_MIN_KEY:
#ifdef PWDEBUG
                                NSLog(@"Sunset Min: %@", [NSNumber numberWithUint8:[[clock.sunsetTime substringWithRange:NSMakeRange(3,2)] intValue]]);
#endif
                                [update setObject:[NSNumber numberWithUint8:[[clock.sunsetTime substringWithRange:NSMakeRange(3,2)] intValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
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
                dispatch_async(watchQueue, ^{[self sendMsgToPebble];});
                if (completionHandler!= nil)
                    dispatch_async(watchQueue, ^{completionHandler(UIBackgroundFetchResultNewData);});
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

- (void)backgroundUpdateWeather:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [self updateWeather:[self.clocks objectAtIndex:0] withCompletionHandler:nil];
    [self updateWeather:[self.clocks objectAtIndex:1] withCompletionHandler:completionHandler];
}

- (void)startWeatherTimer:(int)interval
{
    [self stopWeatherTimer];        // in case one is running
    self.weatherTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(updateAllWeather:) userInfo:nil repeats:NO];
}
                         
- (void)stopWeatherTimer
{
    if (self.weatherTimer != nil)
        [self.weatherTimer invalidate];
}

- (void)updateAllWeather:(id)sender
{
    [self updateWeather:[self.clocks objectAtIndex:0]];
    [self updateWeather:[self.clocks objectAtIndex:1]];
    [self startWeatherTimer:1800];
}

- (void)updateWeather:(PWClock *)clock
{
    [self updateWeather:clock withCompletionHandler:nil];
}

- (void)updateWeather:(PWClock *)clock withCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    
    if (completionHandler != nil) self.completionHandler = completionHandler;
    if ([clock.latitude floatValue] != 1000.0) {
        
#ifdef PWDEBUG
        NSLog(@"updateWeather: Last known location for watch: %@, latitude: %3.8f, %3.8f\n", clock, [clock.latitude floatValue], [clock.longitude floatValue]);
#endif
        [self.forecastr getForecastForLatitude:[clock.latitude floatValue] longitude:[clock.longitude floatValue] time:nil exclusions:nil success:^(id JSON) {
#ifdef PWDEBUG
//            NSLog(@"JSON:\n %@\n\n", JSON);
#endif
            // Print the time in the selected time zone
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"HH:mm";
            [formatter setTimeZone:[NSTimeZone timeZoneWithName:clock.currentTZ]];
            
            clock.currentTZ = [JSON objectForKey:@"timezone"];
            clock.currentTemp =[NSNumber numberWithInt:(int)([[[JSON objectForKey:@"currently"] objectForKey:@"temperature"] doubleValue] + 0.5)];
            clock.currentCondition = [[JSON objectForKey:@"currently"] objectForKey:@"icon"];
            clock.dailyHiTemp = [NSNumber numberWithInt:(int)([[[[[JSON objectForKey:@"daily"] objectForKey:@"data"] firstObject] objectForKey:@"temperatureMax"] doubleValue] + 0.5)];
            clock.dailyLoTemp = [NSNumber numberWithInt:(int)([[[[[JSON objectForKey:@"daily"] objectForKey:@"data"]  firstObject]objectForKey:@"temperatureMin"] doubleValue] + 0.5)];
            NSDate *sunriseDate = [[NSDate alloc] initWithTimeIntervalSince1970:[[[[[JSON objectForKey:@"daily"] objectForKey:@"data"]  firstObject]objectForKey:@"sunriseTime"] doubleValue]];
            NSDate *sunsetDate = [[NSDate alloc] initWithTimeIntervalSince1970:[[[[[JSON objectForKey:@"daily"] objectForKey:@"data"] firstObject] objectForKey:@"sunsetTime"] doubleValue]];
            clock.sunriseTime = [formatter stringFromDate:sunriseDate];
            clock.sunsetTime = [formatter stringFromDate:sunsetDate];
            [self updateWatch:@[@PBCOMM_CITY_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_WEATHER_KEY, @PBCOMM_TEMPERATURE_KEY, @PBCOMM_HI_TEMP_KEY, @PBCOMM_LO_TEMP_KEY, @PBCOMM_SUNRISE_HOUR_KEY, @PBCOMM_SUNRISE_MIN_KEY, @PBCOMM_SUNSET_HOUR_KEY, @PBCOMM_SUNSET_MIN_KEY] forClocks:@[clock]];
            if (self.completionHandler != nil) self.completionHandler();
            
        } failure:^(NSError *error, id response) {
            clock.currentTemp = [NSNumber numberWithInt:-98];
            clock.dailyHiTemp = [NSNumber numberWithInt:-98];
            clock.dailyLoTemp = [NSNumber numberWithInt:-98];
            clock.currentCondition = @"unknown";
            clock.sunriseTime = @"00:00";
            clock.sunsetTime = @"12:00";
#ifdef PWDEBUG
            NSLog(@"Error while retrieving forecast: %@", [self.forecastr messageForError:error withResponse:response]);
#endif
            [self updateWatch:@[@PBCOMM_CITY_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_WEATHER_KEY, @PBCOMM_TEMPERATURE_KEY, @PBCOMM_HI_TEMP_KEY, @PBCOMM_LO_TEMP_KEY, @PBCOMM_SUNRISE_HOUR_KEY, @PBCOMM_SUNRISE_MIN_KEY, @PBCOMM_SUNSET_HOUR_KEY, @PBCOMM_SUNSET_MIN_KEY] forClocks:@[clock]];
            if (self.completionHandler != nil) self.completionHandler();
        }];        
    } else {
        if (self.completionHandler != nil) self.completionHandler();
    }
}

#pragma mark - Location methods

//
// Location methods/delegates. Starts and stops are called by the App delegate when the app goes inactive/active
//
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

- (void)setTzLocation:(CLLocation *)tzLocation forClock:(PWClock *)clock
{
    if (tzLocation == nil) return;
    
    CLGeocoder *geoCoder = [[CLGeocoder alloc] init];
    [geoCoder reverseGeocodeLocation:tzLocation completionHandler:^(NSArray *placemarks, NSError *error) {
        
        CLPlacemark *placemark = [placemarks lastObject];
#ifdef PWDEBUG
        NSLog(@"setTzLocation placemark:\n");
        [placemark.addressDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSLog(@"Key: %@, Value: %@\n", key, obj);
        } ];
#endif
        // Remember where we were last found ...
        clock.latitude = [NSNumber numberWithFloat:tzLocation.coordinate.latitude];
        clock.longitude = [NSNumber numberWithFloat:tzLocation.coordinate.longitude];
        clock.city = [PWTimeViewController getDisplayCity:placemark];
        clock.state = [PWTimeViewController getDisplayState:placemark];
        clock.country = [placemark.addressDictionary objectForKey:@"CountryCode"];
        
#ifdef PWDEBUG
        NSLog(@"setTzLocation: latitude: %3.8f, longitude: %3.8f\n", [clock.latitude floatValue], [clock.longitude floatValue]);
#endif
        [self updateWatch:@[@PBCOMM_WATCH_ENABLED_KEY, @PBCOMM_CITY_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY] forClocks:@[clock]];
        if (([clock.latitude floatValue] != 1000.0) && ([self.clocks objectAtIndex:1] == clock)) {
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([clock.latitude floatValue], [clock.longitude floatValue]);
            MKCoordinateRegion mapRegion;
            mapRegion.center = coordinate;
            mapRegion.span = MKCoordinateSpanMake(0.2, 0.2);
            self.annot.coordinate = coordinate;
            [self.smallMap addAnnotation:self.annot];
        }

        [self showClockOnSmallMap:[self.clocks objectAtIndex:[self.clockSelect selectedSegmentIndex]]];
        
        //
        // Since location changed, update weather as well
        //
        [self updateWeather:clock];
        
    }];
}

//
// Delegate method from the CLLocationManagerDelegate protocol.
//
#pragma mark - CLLocationManager delegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{    
    CLLocation *location = [locations lastObject];
    if (location == nil) return;
    PWClock *clock = [self.clocks objectAtIndex:0];  // Index 0 is always the local watch, which is the only watch that tracks the GPS
    [self setTzLocation:location forClock:clock];
    [self showClockOnSmallMap:[self.clocks objectAtIndex:[self.clockSelect selectedSegmentIndex]]];

}

#pragma mark - UIViewController delegate methods and support methods

- (void)setViewElements:(PWClock *)clock
{
    self.clockEnabled.on = [clock.enabled boolValue];
    self.clockBackground.selectedSegmentIndex = [clock.backgroundMode intValue];
    self.clockDisplay.selectedSegmentIndex = [clock.displayFormat intValue];
    NSString *defTZ = clock.currentTZ;
    if ([defTZ isEqualToString:@""]) {
        defTZ = [[NSTimeZone systemTimeZone] name];
    }
    
    if ([self.clockSelect selectedSegmentIndex] == 0) {
//        self.clockEnabled.on = TRUE;
        self.clockEnabled.hidden = TRUE;
    } else {
        self.clockEnabled.hidden = FALSE;
    }
}

- (void)showClockOnSmallMap:(PWClock *)clock
{
    // Show the selected time zone (clock) on the screen
    if ([clock.latitude floatValue] != 1000.0) {
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([clock.latitude floatValue], [clock.longitude floatValue]);
        MKCoordinateRegion mapRegion;
        mapRegion.center = coordinate;
        mapRegion.span = MKCoordinateSpanMake(0.1, 0.1);
        [self.smallMap setRegion:mapRegion animated:YES];
    }
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    
    if ([self.clockSelect selectedSegmentIndex] == 1)
        [self performSegueWithIdentifier:@"toMap" sender:self];
    
}

- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan)
        return;
    
    if ([self.clockSelect selectedSegmentIndex] == 0){
        [[[UIAlertView alloc] initWithTitle:@"Local Clock Selected"
                                    message:@"Select TZ above to change clock time zone location."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil]
         show];
    } else {
        
        CGPoint touchPoint = [gestureRecognizer locationInView:self.smallMap];
        CLLocationCoordinate2D touchMapCoordinate =
        [self.smallMap convertPoint:touchPoint toCoordinateFromView:self.smallMap];
        
        //    MKPointAnnotation *annot = [[MKPointAnnotation alloc] init];
        //    annot.coordinate = touchMapCoordinate;
        //    [self.mapView addAnnotation:annot];
        
        CLLocation *newTZlocation = [[CLLocation alloc] initWithCoordinate:touchMapCoordinate altitude:0 horizontalAccuracy:0 verticalAccuracy:0 course:0 speed:0 timestamp:[NSDate date]];
        [self setTzLocation:newTZlocation forClock:[self.clocks objectAtIndex:1]];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.
    
    // Initialize the watch objects, stick them in a mutable array. Use watch 0 to set up the view controls
    [self.clocks setObject:[PWClock initWithName:@"Local"] atIndexedSubscript:0];
    [self.clocks setObject:[PWClock initWithName:@"TZ"] atIndexedSubscript:1];
    PWClock *tzClock = [self.clocks objectAtIndex:1];
    if ([tzClock.longitude floatValue] != 1000.0) {
        CLLocation *location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake([tzClock.latitude floatValue], [tzClock.longitude floatValue])
                                 altitude:0 horizontalAccuracy:0 verticalAccuracy:0 course:0 speed:0 timestamp:[NSDate date]];
        [self setTzLocation:location forClock:[self.clocks objectAtIndex:1]];
    }
    [self setViewElements:[self.clocks objectAtIndex:0]];
    
    // Long press selects timezone, when that watch is selected
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.minimumPressDuration = 2.0; //user needs to press for 2 seconds

    self.smallMap.zoomEnabled = YES;
    self.smallMap.scrollEnabled = YES;
    self.smallMap.pitchEnabled = NO;
    self.smallMap.rotateEnabled = NO;
    self.smallMap.showsUserLocation = YES;
    [self.smallMap addGestureRecognizer:lpgr];
    
    [self showClockOnSmallMap:[self.clocks objectAtIndex:[self.clockSelect selectedSegmentIndex]]];

    // This queue manages the messaging between the phone and the watch. It sequences messages to make sure one is complete and acknowledged
    // before the next is sent.
    watchQueue = dispatch_queue_create("com.dkkrause.PebbleWorldTime", NULL);
    
    // Set the developer API key for Forecastr so that we can get weather data
    self.forecastr.apiKey = @"3348fb0cf7f9595aa092b5c8150bdedb";
    
    // We'd like to get called when Pebbles connect and disconnect, so become the delegate of PBPebbleCentral:
    [[PBPebbleCentral defaultCentral] setDelegate:self];
    [self setTargetWatch:[[PBPebbleCentral defaultCentral] lastConnectedWatch]];
    [self updateDisconnectIndicator];
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{

}

#pragma mark - PBPebbleCentral delegate methods

#pragma mark - Watch management methods

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

    // Assume that appMessages are supported, only very early versions of PebbleOS did not support this.
    // Configure our communications channel to target the worldtime app: (watchface must have same UUID)
    uint8_t bytes[] = {0xC5, 0x5D, 0x88, 0x75, 0x56, 0x09, 0x43, 0x9D, 0xA5, 0x2F, 0x0A, 0x97, 0x73, 0x50, 0xB9, 0x55};
    NSData *uuid = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    [_targetWatch appMessagesSetUUID:uuid];
    [self addReceiveHandler:_targetWatch];          // So we can receive messages from the watch
    
    [self sendConfigToWatch];                       // Send the configuration to the newly connected watch
    
    // Since we have a connected watch start tracking the GPS, if configured to do so
    if (self.trackGPSUpdates.isOn) {
        [self startSignificantLocationChangeUpdates];
        [AppDelegate enableBackgroundFetch];
    }
}

/*
 *  PBPebbleCentral delegate methods
 */

- (NSString *)discTitle:(NSString *)text
{
    if ([self.numDisconnects intValue] != 0) {
       return [text stringByAppendingFormat:@" (%@)", self.numDisconnects];
    } else {
        return text;
    }
}

- (void)updateDisconnectIndicator
{
    if ([[[PBPebbleCentral defaultCentral] connectedWatches] containsObject:self.targetWatch]) {
        self.view.backgroundColor = [UIColor whiteColor];
    } else {
        self.view.backgroundColor = [UIColor redColor];
    }
}

- (void)addReceiveHandler:(PBWatch *)watch
{
#ifdef PWDEBUG
    NSLog(@"Entering addReceiveHandler\n");
#endif
    self.watchUpdateHandler = [watch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {
        [update enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
#ifdef PWDEBUG
            NSLog(@"receivehandler block: key: %@, obj: %@\n", key, obj);
#endif
            switch ([key intValue]) {
                case IOS_UPDATE_WEATHER:
                    switch ([obj intValue]) {
                        case LOCAL_WEATHER:
                            [self updateWeather:[self.clocks objectAtIndex:0]];
                            break;
                        case TZ_WEATHER:
                            [self updateWeather:[self.clocks objectAtIndex:1]];
                            break;
                        case BOTH_WEATHER:
                            [self updateWeather:[self.clocks objectAtIndex:0]];
                            [self updateWeather:[self.clocks objectAtIndex:1]];
                            break;
                        default:
                            break;
                    }
                    break;
                default:
                    break;
            }
        }];
        return TRUE;            // No matter what we'll go on from here ...
    }];
}

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidConnect:(PBWatch*)watch isNew:(BOOL)isNew
{
    [self setTargetWatch:watch];
    [self updateDisconnectIndicator];
}

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidDisconnect:(PBWatch*)watch
{    
    if (_targetWatch == watch || [watch isEqual:_targetWatch]) {        
        [watch appMessagesRemoveUpdateHandler:self.watchUpdateHandler];
        [self setWatchUpdateHandler:nil];
        [self setTargetWatch:nil];
        self.numDisconnects = [NSNumber numberWithInt:[self.numDisconnects intValue] + 1];
        [self updateDisconnectIndicator];
        [self stopSignificantLocationChangeUpdates];    // Turn off GPS tracking since no watch is connected
        [AppDelegate disableBackgroundFetch];
    }
}

@end
