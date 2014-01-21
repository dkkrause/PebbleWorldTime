//
//  PWTimeFirstViewController.m
//  PebbleWorldTime
//
//  Created by Don Krause on 6/2/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <PebbleKit/PebbleKit.h>
#import "PWTimeKeys.h"                          // Contstants for phone-watch communication
#import "PWTimeViewController.h"                // Main view controller
#import "PWTimeAnnotation.h"                    // Map annotation
#import "NSMutableArray+QueueAdditions.h"       // Added queue functions to a NSMutableArray

@interface PWTimeViewController () <PBPebbleCentralDelegate, MKMapViewDelegate>

#pragma mark - Outlets for buttons/selectors, etc.
@property (weak, nonatomic)   IBOutlet UISegmentedControl *clockSelect;
@property (weak, nonatomic)   IBOutlet UISegmentedControl *clockBackground;
@property (weak, nonatomic)   IBOutlet UISegmentedControl *clockDisplay;
@property (weak, nonatomic)   IBOutlet UISwitch           *trackGPSUpdates;
@property (strong, nonatomic) IBOutlet MKMapView          *smallMap;

@property (weak, nonatomic)  MKAnnotationView *annotationView;
@property (nonatomic) PBWatch           *targetWatch;
@property (nonatomic) BOOL               watchAppRunning;
@property (nonatomic) id                 watchUpdateHandler;
@property (nonatomic) NSMutableArray    *msgQueue;
@property (nonatomic) NSLock            *queueLock;
@property (nonatomic) NSMutableArray    *clocks;

@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) NSTimer           *weatherTimer;
@property (nonatomic) NSArray           *conditions;

@end

@implementation PWTimeViewController

{
    dispatch_queue_t watchQueue;
}

NSMutableDictionary *update;

#pragma mark - getters with lazy initialization

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

- (NSMutableArray *)clocks
{
    if (_clocks == nil) {
        _clocks = [[NSMutableArray alloc] initWithCapacity:3];
    }
    return _clocks;
}

- (NSArray *)conditions
{    
    if (_conditions == nil) {
        _conditions = [[NSArray alloc]
                       initWithObjects: @"unknown", @"clear-day", @"clear-night", @"rain",
                                        @"snow", @"sleet", @"wind", @"fog", @"cloudy",
                                        @"partly-cloudy-day", @"partly-cloudy-night", nil];
    }
    return _conditions;    
}

#pragma mark - IBActions for associated buttons/selectors on screen

- (IBAction)clockSelected:(id)sender
{
    [self setViewElements:[self.clocks objectAtIndex:[sender selectedSegmentIndex]]];    // Set up the small map view on the main screen
    [self showSelectedClockOnSmallMap];
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
    // Update the currently selected watch with all of the current settings
    [self updateWeather:[self.clocks objectAtIndex:self.clockSelect.selectedSegmentIndex] withCompletionHandler:nil];
    
}

- (IBAction)trackLocationChanges:(id)sender
{    
    if ([sender isKindOfClass:[UISwitch class]]) {
        UISwitch *locSwitch = (UISwitch *)sender;
        if (locSwitch.on) {
            [self startTrackingUser];
        } else {
            [self stopTrackingUser];
        }
    }
}

#pragma mark - Watch communication methods

- (void)sendConfigToWatch
{
    // Update the local watch with all of the current settings
    [self updateWatch:@[@PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY] forClocks:@[[self.clocks objectAtIndex:0]]];
    // Update the TZ 1 watch with all of the current settings
    [self updateWatch:@[@PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY] forClocks:@[[self.clocks objectAtIndex:1]]];
    // Update the TZ 2 watch with all of the current settings
    [self updateWatch:@[@PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY] forClocks:@[[self.clocks objectAtIndex:2]]];
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
#ifdef PWDEBUGCOMM
        NSLog(@"Sending watch: %@, message: %@", self.targetWatch, update);
#endif
        [self.targetWatch appMessagesPushUpdate:update onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
            if (!error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *full_message = [NSString stringWithFormat:@"Error: %@, Update: %@", [error localizedDescription], update];
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
    [self updateWatch:keys forClocks:clocks withWeather:NULL withCompletionHandler:nil];
}


- (void)updateWatch:(NSArray *)keys forClocks:(NSArray *)clocks withWeather:(NSData *)weather withCompletionHandler:(void(^)())handler
{

    // We  communicate with the watch when we call -appMessagesGetIsSupported: which implicitely opens the communication session.
    // Test if the Pebble's firmware supports AppMessages:
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
            } else if ([clock.name isEqualToString:@"TZ 1"]) {
                clockOffset = TZ1_WATCH_OFFSET;
                clockNum = 1;
            } else if ([clock.name isEqualToString:@"TZ 2"]) {
                clockOffset = TZ2_WATCH_OFFSET;
                clockNum = 1;
            } else {
                return;
            }
#ifdef PWDEBUGCOMM
            NSLog(@"Updating Watch: %@, clockOffset: %2d\n", clock.name, clockOffset);
#endif
            for (NSNumber *key in keys) {
#ifdef PWDEBUGCOMM
                NSLog(@"Updating key: %2d\n", [key intValue] + clockOffset);
#endif
                // Now we need to put together the tuples to be sent to the Pebble watch
                switch ([key intValue]) {
                        
                    case PBCOMM_GMT_SEC_OFFSET_KEY:
                        // GMT Offset
                        timeZoneName = clock.currentTZ;
                        if ([timeZoneName isEqualToString:@""]) {
                            timeZoneName = [[NSTimeZone systemTimeZone] name];
                        }
                        gmtOffset = [[NSTimeZone timeZoneWithName:timeZoneName] secondsFromGMT];
#ifdef PWDEBUGCOMM
                        NSLog(@"GMT Offset: %8d\n", gmtOffset);
#endif
                        [update setObject:[NSNumber numberWithInt32:gmtOffset] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                        break;
                    case PBCOMM_CITY_KEY:
                        displayCity = [[clock.city stringByAppendingString:@", "] stringByAppendingString:clock.state];
#ifdef PWDEBUGCOMM
                        NSLog(@"City: %@", displayCity);
#endif
                        [update setObject:displayCity forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                        break;
                    case PBCOMM_BACKGROUND_KEY:
#ifdef PWDEBUGCOMM
                        NSLog(@"Background: %@\n", [NSNumber numberWithUint8:(uint8_t)[clock.backgroundMode intValue]]);
#endif
                        [update setObject:[NSNumber numberWithUint8:(uint8_t)[clock.backgroundMode intValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                        break;
                    case PBCOMM_12_24_DISPLAY_KEY:
#ifdef PWDEBUGCOMM
                        NSLog(@"12/24 hour: %@\n", [NSNumber numberWithUint8:(uint8_t)[clock.displayFormat intValue]]);
#endif
                        [update setObject:[NSNumber numberWithUint8:(uint8_t)[clock.displayFormat intValue]] forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                        break;
                    case PBCOMM_WEATHER_KEY:
                        if (weather != NULL) {
#ifdef PWDEBUGCOMM
                            NSLog(@"Weather: %@", weather);
#endif
                            [update setObject:weather forKey:[NSNumber numberWithInt:(clockOffset + [key intValue])]];
                        }
                        break;
                    default:
                        return;
                }
            }
        }
        
        // Send data to watch:
        // See demos/feature_app_messages/weather.c in the native watch app SDK for the same definitions on the watch's end:
        if (self.watchAppRunning) {
#ifdef PWDEBUGCOMM
            NSLog(@"Full Update:\n%@\n\n", update);
#endif
            [self.queueLock lock];
            [self.msgQueue NSMAEnqueue:update];
            [self.queueLock unlock];
            dispatch_async(watchQueue, ^{[self sendMsgToPebble];});
        } else {
#ifdef PWDEBUGCOMM
            NSLog(@"watch app not running, msg not queued: %@", update);
#endif
        }
        return;
    }
    @catch (NSException *exception) {
    }
    [[[UIAlertView alloc] initWithTitle:nil message:@"Error parsing response" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

#pragma mark - Weather methods

//
// Methods to handle weather, both getting info and handling timers to refresh information
//

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
    [self updateAllWeather:[self.clocks objectAtIndex:0] withCompletionHandler:nil];
}

- (void)updateAllWeather:(id)sender withCompletionHandler:(void(^)())handler
{
    [self updateWeather:[self.clocks objectAtIndex:0] withCompletionHandler:handler];
    [self updateWeather:[self.clocks objectAtIndex:1] withCompletionHandler:handler];
    [self updateWeather:[self.clocks objectAtIndex:2] withCompletionHandler:handler];
    [self startWeatherTimer:1800];
}

- (void)updateWeather:(PWClock *)clock withCompletionHandler:(void(^)())handler
{

    if ([clock.latitude floatValue] != 1000.0) {
        
#ifdef PWDEBUG
        NSLog(@"updateWeatherNSURLSession: Last known location for watch: %@, latitude: %3.8f, %3.8f\n", clock, [clock.latitude floatValue], [clock.longitude floatValue]);
#endif
        NSString *forecastrUrl = @"https://api.forecast.io/forecast/3348fb0cf7f9595aa092b5c8150bdedb/";
        forecastrUrl = [forecastrUrl stringByAppendingFormat:@"%@,%@", [clock.latitude stringValue], [clock.longitude stringValue]];
#ifdef PWDEBUG
        NSLog(@"updateWeatherNSURLSession forecastURL: %@", forecastrUrl);
#endif
        NSURLSession *session = [NSURLSession sharedSession];
        [[session dataTaskWithURL:[NSURL URLWithString:forecastrUrl]
                completionHandler:^(NSData *data,
                                    NSURLResponse *response,
                                    NSError *error) {
                    // handle response
                    if (error) {
#ifdef PWDEBUG
                        NSLog(@"Could not get forecastr data: %@", error);
#endif
                        return;
                    }
#ifdef PWDEBUG
//                    if (![NSJSONSerialization isValidJSONObject:data]) {
//                        NSLog(@"updateWeatherNSSession, did not get JSON data: %@", data);
//                        return;
//                    }
#endif
                    NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
            
#ifdef PWDEBUG
                    NSLog(@"updateWeatherNSURLSession, got weather for: %@", clock.city);
#endif
#ifdef PWDEBUGWEATHERDETAIL
                    NSLog(@"updateWeatherNSURLSession, got JSON:\n %@\n\n", JSON);
#endif
                    int temperature;
                    int conditions[MAX_WEATHER_CONDITIONS];
                    int daily_hi[MAX_WEATHER_CONDITIONS];
                    int daily_lo[MAX_WEATHER_CONDITIONS];
                    int sunrise_hour, sunrise_min, sunset_hour, sunset_min;
                    
                    // Print the time in the selected time zone
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    formatter.dateFormat = @"HH:mm";
                    [formatter setTimeZone:[NSTimeZone timeZoneWithName:clock.currentTZ]];
                    
                    clock.currentTZ = [JSON objectForKey:@"timezone"];
                    temperature = (int)([[[JSON objectForKey:@"currently"] objectForKey:@"temperature"] doubleValue] + 0.5);
                    for (int i = 0; i<MAX_WEATHER_DAYS; i++) {
                        conditions[i] = (i==0) ? [self.conditions indexOfObject:[[JSON objectForKey:@"currently"] objectForKey:@"icon"]]
                        : [self.conditions indexOfObject:[[[[JSON objectForKey:@"daily"] objectForKey:@"data"] objectAtIndex:i] objectForKey:@"icon"]];
                        daily_hi[i] = (int)[[[[[JSON objectForKey:@"daily"] objectForKey:@"data"] objectAtIndex:i] objectForKey:@"temperatureMax"] doubleValue] + 0.5;
                        daily_lo[i] = (int)[[[[[JSON objectForKey:@"daily"] objectForKey:@"data"] objectAtIndex:i] objectForKey:@"temperatureMin"] doubleValue] + 0.5;
                    }
                    NSDate *sunriseDate = [[NSDate alloc] initWithTimeIntervalSince1970:[[[[[JSON objectForKey:@"daily"] objectForKey:@"data"]  firstObject]objectForKey:@"sunriseTime"] doubleValue]];
                    NSDate *sunsetDate = [[NSDate alloc] initWithTimeIntervalSince1970:[[[[[JSON objectForKey:@"daily"] objectForKey:@"data"] firstObject] objectForKey:@"sunsetTime"] doubleValue]];
                    formatter.dateFormat = @"HH";
                    sunrise_hour = [[formatter stringFromDate:sunriseDate] intValue];
                    sunset_hour = [[formatter stringFromDate:sunsetDate] intValue];
                    formatter.dateFormat = @"mm";
                    sunrise_min = [[formatter stringFromDate:sunriseDate] intValue];
                    sunset_min = [[formatter stringFromDate:sunsetDate] intValue];
                    clock.lastWeatherUpdate = [NSDate date];
                    
                    Byte message_bytes[WEATHER_KEY_LEN];
                    for (int i=0; i<WEATHER_KEY_LEN; i++) {
                        switch(i) {
                            case 0:
                            case 1:
                            case 2:
                                message_bytes[i] = (Byte)conditions[i-WEATHER_ICONS];
                                break;
                            case 3:
                                message_bytes[i] = (Byte)temperature;
                                break;
                            case 4:
                            case 5:
                            case 6:
                                message_bytes[i] = (Byte)daily_hi[i-MAX_TEMPS];
                                break;
                            case 7:
                            case 8:
                            case 9:
                                message_bytes[i] = (Byte)daily_lo[i-MIN_TEMPS];
                                break;
                            case 10:
                                message_bytes[i] = (Byte)sunrise_hour;
                                break;
                            case 11:
                                message_bytes[i] = (Byte)sunrise_min;
                                break;
                            case 12:
                                message_bytes[i] = (Byte)sunset_hour;
                                break;
                            case 13:
                                message_bytes[i] = (Byte)sunset_min;
                                break;
                        }
                    }
                    NSData *weather = [NSData dataWithBytes:message_bytes length:WEATHER_KEY_LEN];
                    [self updateWatch:@[@PBCOMM_BACKGROUND_KEY, @PBCOMM_12_24_DISPLAY_KEY, @PBCOMM_CITY_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY, @PBCOMM_WEATHER_KEY] forClocks:@[clock] withWeather:weather withCompletionHandler:handler];
                }] resume];
    } else {
    }
}

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

#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    [self setTzLocation:userLocation.location forClock:[self.clocks objectAtIndex:0]];
    [self showSelectedClockOnSmallMap];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if (annotation == self.smallMap.userLocation) {
        return nil;
    } else {
        MKAnnotationView *aView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"MapPlaceVC"];
        if (!aView) {
            aView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"MapPlaceVC"];
            aView.canShowCallout = YES;
            
            // rightCalloutAccessoryView detail disclosure button to see photo
            UIButton *callout = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            aView.rightCalloutAccessoryView = callout;
        }
        aView.annotation = annotation;
        return aView;
    }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    [self performSegueWithIdentifier:@"toMap" sender:self];
}

#pragma mark - Location methods

//
// Location methods/delegates. Starts and stops are called by the App delegate when the app goes inactive/active
//
- (void)startTrackingUser
{    
    self.smallMap.showsUserLocation = YES;
}

- (void)stopTrackingUser
{
    self.smallMap.showsUserLocation = NO;
}

// Sets the TZ Location for the current clock
//
- (void)setTzLocation:(CLLocation *)tzLocation
{
    [self setTzLocation:tzLocation forClock:[self.clocks objectAtIndex:[self.clockSelect selectedSegmentIndex]]];
}

- (void)setTzLocation:(CLLocation *)tzLocation forClock:(PWClock *)clock
{
    if (tzLocation == nil) return;
    if (tzLocation.coordinate.latitude == 1000.0) return;
    
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
        [self updateWatch:@[@PBCOMM_CITY_KEY, @PBCOMM_GMT_SEC_OFFSET_KEY] forClocks:@[clock]];
        [self showSelectedClockOnSmallMap];
        
        //
        // Since location changed, update weather as well
        //
        [self updateWeather:clock withCompletionHandler:nil];
        
    }];
}

#pragma mark - UIViewController delegate methods and support methods

- (void)setViewElements:(PWClock *)clock
{
    self.clockBackground.selectedSegmentIndex = [clock.backgroundMode intValue];
    self.clockDisplay.selectedSegmentIndex = [clock.displayFormat intValue];
    NSString *defTZ = clock.currentTZ;
    if ([defTZ isEqualToString:@""]) {
        defTZ = [[NSTimeZone systemTimeZone] name];
    }
}

- (void)showSelectedClockOnSmallMap
{
    // Show the selected time zone (clock) on the screen
    PWClock *clock = [self.clocks objectAtIndex:[self.clockSelect selectedSegmentIndex]];
    if ([clock.latitude floatValue] != 1000.0) {
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([clock.latitude floatValue], [clock.longitude floatValue]);
        MKCoordinateRegion mapRegion;
        mapRegion.center = coordinate;
        mapRegion.span = MKCoordinateSpanMake(0.1, 0.1);
        [self.smallMap removeAnnotation:clock.annot];
        [self.smallMap setRegion:mapRegion animated:YES];
        if ([self.clockSelect selectedSegmentIndex] != 0) {
            clock.annot = [PWTimeAnnotation annotationWithTitle:clock.city forLocation:coordinate];
            if ([self.clockSelect selectedSegmentIndex] != 0) {
                [self.smallMap addAnnotation:clock.annot];
            }
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.
    
    // Assume the watch app is not running we'll fix this in a bit
    self.watchAppRunning = false;
    
    // Initialize the watch objects, stick them in a mutable array. Use watch 0 to set up the view controls
    [self.clocks setObject:[PWClock initWithName:@"Local"] atIndexedSubscript:0];
    [self.clocks setObject:[PWClock initWithName:@"TZ 1"] atIndexedSubscript:1];
    [self.clocks setObject:[PWClock initWithName:@"TZ 2"] atIndexedSubscript:2];
    for (int i = 1; i < 3; i++) {
        PWClock *tzClock = [self.clocks objectAtIndex:i];
        if ([tzClock.longitude floatValue] != 1000.0) {
            CLLocation *location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake([tzClock.latitude floatValue], [tzClock.longitude floatValue])
                                     altitude:0 horizontalAccuracy:0 verticalAccuracy:0 course:0 speed:0 timestamp:[NSDate date]];
            [self setTzLocation:location forClock:[self.clocks objectAtIndex:i]];
        }
    }
    [self setViewElements:[self.clocks objectAtIndex:0]];
    

    // Set up small map. Point is to show user where location is so don't allow scrolling, etc. Zoom is OK to get more detail.
    self.smallMap.zoomEnabled       = YES;
    self.smallMap.scrollEnabled     = NO;
    self.smallMap.pitchEnabled      = NO;
    self.smallMap.rotateEnabled     = NO;
    // Start tracking the GPS, if configured to do so
    if (self.trackGPSUpdates.isOn) {
        [self startTrackingUser];
    } else {
        [self stopTrackingUser];
    }
    self.smallMap.delegate = self;
    [self showSelectedClockOnSmallMap];

    // This queue manages the messaging between the phone and the watch. It sequences messages to make sure one is complete and acknowledged
    // before the next is sent.
    watchQueue = dispatch_queue_create("com.dkkrause.PebbleWorldTime", NULL);
    
    // We'd like to get called when Pebbles connect and disconnect, so become the delegate of PBPebbleCentral:
    [[PBPebbleCentral defaultCentral] setDelegate:self];
    uuid_t myAppUUIDbytes;
    NSUUID *myAppUUID = [[NSUUID alloc] initWithUUIDString:@"51616af5-2af4-4d43-800f-a5b4df1b56b0"];
    [myAppUUID getUUIDBytes:myAppUUIDbytes];
    [[PBPebbleCentral defaultCentral] setAppUUID:[NSData dataWithBytes:myAppUUIDbytes length:16]];
    [self setTargetWatch:[[PBPebbleCentral defaultCentral] lastConnectedWatch]];
    [self updateDisconnectIndicator];
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    PWClock *tzClock = [self.clocks objectAtIndex:[self.clockSelect selectedSegmentIndex]];
    CLLocationCoordinate2D location = CLLocationCoordinate2DMake([tzClock.latitude floatValue], [tzClock.longitude floatValue]);
    [segue.destinationViewController setCoordinate:location];
    [segue.destinationViewController setDelegate:self];
}

#pragma mark - PBPebbleCentral delegate methods

#pragma mark - Watch management methods

- (void)runWatchApp
{
    // Attempt to launch the app on the Pebble
    if (!self.watchAppRunning) {
        [self.targetWatch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
            if (error) {
                NSString *full_message = [NSString stringWithFormat:@"Cannot launch app on Pebble: %@ ", [error localizedDescription]];
                [[[UIAlertView alloc] initWithTitle:nil message:full_message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            } else {
#ifdef PWDEBUGCOMM
                NSLog(@"Watch app started successfully");
#endif
                self.watchAppRunning = true;
                [self sendConfigToWatch];
            }
        }];
    }
}

- (void)setTargetWatch:(PBWatch *)targetWatch
{
    _targetWatch = targetWatch;
    if(targetWatch == nil ) {
        self.watchAppRunning = false;
        dispatch_suspend(watchQueue);
        return;
    }
    [self runWatchApp];
}

/*
 *  PBPebbleCentral delegate methods
 */

- (void)updateDisconnectIndicator
{
    if ([[[PBPebbleCentral defaultCentral] connectedWatches] containsObject:self.targetWatch]) {
        self.view.backgroundColor = [UIColor whiteColor];
    } else {
        self.view.backgroundColor = [UIColor redColor];
    }
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
        [self updateDisconnectIndicator];
        [self stopTrackingUser];    // Turn off GPS tracking since no watch is connected
    }
}

@end
