//
//  PWTimeFirstViewController.h
//  PebbleWorldTime
//
//  Created by Don Krause on 6/2/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <UIKit/UIKit.h>

//
// KEYs for storing NSUserDefaults, basic preference information for the app
//
#define KEY_DOMAIN              @"com.dkkrause.PWTime"
#define CLOCK_ENABLED_KEY       @"clockEnabled"
#define CLOCK_BACKGROUND_KEY    @"clockBackground"
#define CLOCK_TZ_KEY            @"clockTZ"
#define CLOCK_DISPLAY_KEY       @"clockDisplay"
#define CLOCK_WATCHFACE_KEY     @"clockWatchface"

@interface PWTimeViewController : UIViewController

- (void)setClockTZ:(NSTimeZone *)clockTZ;
- (void)startSignificantLocationChangeUpdates;
- (void)stopSignificantLocationChangeUpdates;
- (void)startWeatherUpdateTimer:(NSTimeInterval) ti;
- (void)stopWeatherUpdateTimer;

@end
