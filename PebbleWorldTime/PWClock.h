//
//  PWClock.h
//  PebbleWorldTime
//
//  Created by Don Krause on 8/31/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface PWClock : NSObject

+ (PWClock *)initWithName:(NSString *)name;

@property (nonatomic) NSString *name;
@property (nonatomic) NSNumber *enabled;
@property (nonatomic) NSNumber *backgroundMode;
@property (nonatomic) NSString *currentTZ;
@property (nonatomic) NSNumber *displayFormat;
@property (nonatomic) NSString *locationName;
@property (nonatomic) NSNumber *latitude;
@property (nonatomic) NSNumber *longitude;
@property (nonatomic) NSString *city;
@property (nonatomic) NSString *state;
@property (nonatomic) NSString *country;
@property (nonatomic) NSString *currentCondition;
@property (nonatomic) NSNumber *currentTemp;
@property (nonatomic) NSNumber *dailyHiTemp;
@property (nonatomic) NSNumber *dailyLoTemp;
@property (nonatomic) NSString *sunriseTime;
@property (nonatomic) NSString *sunsetTime;
@property (nonatomic) NSDate   *lastWeatherUpdate;

@end
