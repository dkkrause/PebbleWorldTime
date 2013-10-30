//
//  PWClock.m
//  PebbleWorldTime
//
//  Created by Don Krause on 8/31/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "PWClock.h"
#import "PWTimeKeys.h"
#import "PWTimeViewController.h"

@interface PWClock ()

@end

@implementation PWClock

// Synthesize internal properties
@synthesize enabled = _enabled;
@synthesize backgroundMode = _backgroundMode;
@synthesize currentTZ = _currentTZ;
@synthesize displayFormat = _displayFormat;
@synthesize latitude = _latitude;
@synthesize longitude = _longitude;

#pragma mark - class methods to initialize a clock object
+ (PWClock *)initWithName:(NSString *)name
{
    
    PWClock *clock          = [[PWClock alloc] init];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    bool defaultsWritten = [[defaults objectForKey:[PWClock makeKey:CLOCK_DEFAULTS_WRITTEN_KEY forWatch:name]] boolValue];
    
    clock.name = name;
    if (defaultsWritten) {
        clock.enabled        = [NSNumber numberWithBool:[[defaults objectForKey:[PWClock makeKey:CLOCK_ENABLED_KEY forWatch:name]] boolValue]];
        clock.backgroundMode = [NSNumber numberWithInt:[[defaults objectForKey:[PWClock makeKey:CLOCK_BACKGROUND_KEY forWatch:name]] intValue]];
        clock.currentTZ      = [defaults objectForKey:[PWClock makeKey:CLOCK_TZ_KEY forWatch:name]];
        clock.displayFormat  = [NSNumber numberWithInt:[[defaults objectForKey:[PWClock makeKey:CLOCK_DISPLAY_KEY forWatch:name]] intValue]];
        clock.latitude       = [NSNumber numberWithFloat:[[defaults objectForKey:[PWClock makeKey:CLOCK_TZ_LATITUDE_KEY forWatch:name]] floatValue]];
        clock.longitude      = [NSNumber numberWithFloat:[[defaults objectForKey:[PWClock makeKey:CLOCK_TZ_LONGITUDE_KEY forWatch:name]] floatValue]];
    } else {
        clock.enabled        = [NSNumber numberWithBool:[name isEqualToString:@"Local"]];
        clock.backgroundMode = [NSNumber numberWithInt:BACKGROUND_LIGHT];
        clock.currentTZ      = [[NSTimeZone systemTimeZone] name];
        clock.displayFormat  = [NSNumber numberWithInt:DISPLAY_WATCH_CONFIG_TIME];
        clock.latitude       = [NSNumber numberWithFloat:(float)1000.0];
        clock.longitude      = [NSNumber numberWithFloat:(float)1000.0];
    }
    clock.city              = [name stringByAppendingString:@" City"];
    clock.state             = [name stringByAppendingString:@" State"];
    clock.country           = [name stringByAppendingString:@" Country"];
    clock.currentTemp       = [NSNumber numberWithInt:-97];
    clock.dailyHiTemp       = [NSNumber numberWithInt:-97];
    clock.dailyLoTemp       = [NSNumber numberWithInt:-97];
    clock.sunriseTime       = @"00:00";
    clock.sunsetTime        = @"12:00";
    [defaults setObject:[NSNumber numberWithBool:YES] forKey:[PWClock makeKey:CLOCK_DEFAULTS_WRITTEN_KEY forWatch:name]];
    [defaults synchronize];    
    return clock;
    
}

+(NSString *)makeKey:(NSString *)keyLabel forWatch:(NSString *)name
{    
    return [KEY_DOMAIN stringByAppendingFormat:@".%@.%@", name, keyLabel];
}

#pragma mark - object methods for clock objects

#pragma mark - getters/setters, some of which must manipulate NSUserDefaults

- (NSNumber *)enabled
{
    return _enabled;
}

- (void)setEnabled:(NSNumber *)enabled
{
    _enabled = enabled;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:_enabled forKey:[PWClock makeKey:CLOCK_ENABLED_KEY forWatch:self.name]];
    [defaults synchronize];
}

- (NSNumber *)backgroundMode
{
    return _backgroundMode;
}

- (void)setBackgroundMode:(NSNumber *)backgroundMode
{
    _backgroundMode = backgroundMode;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:_backgroundMode forKey:[PWClock makeKey:CLOCK_BACKGROUND_KEY forWatch:self.name]];
    [defaults synchronize];    
}

- (NSNumber *)displayFormat
{
    return _displayFormat;
}

- (void)setDisplayFormat:(NSNumber *)displayFormat
{
    _displayFormat = displayFormat;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:_displayFormat forKey:[PWClock makeKey:CLOCK_DISPLAY_KEY forWatch:self.name]];
    [defaults synchronize];
}

- (NSString *)currentTZ
{
    return _currentTZ;
}

- (void)setCurrentTZ:(NSString *)currentTZ
{
    _currentTZ = currentTZ;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:_currentTZ forKey:[PWClock makeKey:CLOCK_TZ_KEY forWatch:self.name]];
    [defaults synchronize];    
}

- (NSNumber *)latitude
{
    return _latitude;
}

- (void)setLatitude:(NSNumber *)latitude
{
    _latitude = latitude;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:_latitude forKey:[PWClock makeKey:CLOCK_TZ_LATITUDE_KEY forWatch:self.name]];
    [defaults synchronize];
}

- (NSNumber *)longitude
{
    return _longitude;
}

- (void)setLongitude:(NSNumber *)longitude
{
    _longitude = longitude;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:_longitude forKey:[PWClock makeKey:CLOCK_TZ_LONGITUDE_KEY forWatch:self.name]];
    [defaults synchronize];
}

@end
