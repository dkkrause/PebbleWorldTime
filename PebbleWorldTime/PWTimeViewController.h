//
//  PWTimeFirstViewController.h
//  PebbleWorldTime
//
//  Created by Don Krause on 6/2/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "PWClock.h"

//
// KEYs for storing NSUserDefaults, basic preference information for the app
//
#define KEY_DOMAIN                  @"com.dkkrause.PWTime"
#define CLOCK_BACKGROUND_KEY        @"clockBackground"
#define CLOCK_TZ_KEY                @"clockTZ"
#define CLOCK_DISPLAY_KEY           @"clockDisplay"
#define CLOCK_TZ_LATITUDE_KEY       @"clockTZLatitude"
#define CLOCK_TZ_LONGITUDE_KEY      @"clockTZLongitude"
#define CLOCK_DEFAULTS_WRITTEN_KEY  @"clockDefaultsWritten"

@interface PWTimeViewController : UIViewController

- (void)setTzLocation:(CLLocation *)tzLocation;
- (void)setTzLocation:(CLLocation *)tzLocation forClock:(PWClock *)clock;
- (void)startTrackingUser;
- (void)stopTrackingUser;
- (void)startWeatherTimer:(int)interval;
- (void)stopWeatherTimer;

@end
