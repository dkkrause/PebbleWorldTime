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
@synthesize backgroundMode = _backgroundMode;
@synthesize currentTZ = _currentTZ;
@synthesize displayFormat = _displayFormat;
@synthesize latitude = _latitude;
@synthesize longitude = _longitude;
@synthesize annot = _annot;

#pragma mark - class methods to initialize a clock object
+ (PWClock *)initWithName:(NSString *)name
{
    
    PWClock *clock          = [[PWClock alloc] init];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    bool defaultsWritten = [[defaults objectForKey:[PWClock makeKey:CLOCK_DEFAULTS_WRITTEN_KEY forWatch:name]] boolValue];
    
    clock.name = name;
    if (defaultsWritten) {
        clock.backgroundMode = [NSNumber numberWithInt:[[defaults objectForKey:[PWClock makeKey:CLOCK_BACKGROUND_KEY forWatch:name]] intValue]];
        clock.currentTZ      = [defaults objectForKey:[PWClock makeKey:CLOCK_TZ_KEY forWatch:name]];
        clock.displayFormat  = [NSNumber numberWithInt:[[defaults objectForKey:[PWClock makeKey:CLOCK_DISPLAY_KEY forWatch:name]] intValue]];
        clock.latitude       = [NSNumber numberWithFloat:[[defaults objectForKey:[PWClock makeKey:CLOCK_TZ_LATITUDE_KEY forWatch:name]] floatValue]];
        clock.longitude      = [NSNumber numberWithFloat:[[defaults objectForKey:[PWClock makeKey:CLOCK_TZ_LONGITUDE_KEY forWatch:name]] floatValue]];
    } else {
        clock.backgroundMode = [NSNumber numberWithInt:BACKGROUND_LIGHT];
        clock.currentTZ      = [[NSTimeZone systemTimeZone] name];
        clock.displayFormat  = [NSNumber numberWithInt:DISPLAY_WATCH_CONFIG_TIME];
        if ([name isEqualToString:@"TZ 1"]) {
            
            clock.latitude       = [NSNumber numberWithFloat:(float)51.507200];
            clock.longitude      = [NSNumber numberWithFloat:(float)0.127500];
            clock.city           = @"London";
            clock.state          = @"England";
            clock.country        = @"United Kingdom";
        } else if ([name isEqualToString:@"TZ 2"] ) {
            clock.latitude       = [NSNumber numberWithFloat:(float)35.689500];
            clock.longitude      = [NSNumber numberWithFloat:(float)139.691700];
            clock.city           = @"Shinjuku";
            clock.state          = @"Tokyo";
            clock.country        = @"Japan";
        } else {
            clock.latitude       = [NSNumber numberWithFloat:(float)1000.0];
            clock.longitude      = [NSNumber numberWithFloat:(float)1000.0];
            clock.city           = [name stringByAppendingString:@" City"];
            clock.state          = [name stringByAppendingString:@" State"];
            clock.country        = [name stringByAppendingString:@" Country"];
        }
    }
    clock.lastWeatherUpdate = [NSDate dateWithTimeIntervalSince1970:0];
    clock.annot = nil;
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
