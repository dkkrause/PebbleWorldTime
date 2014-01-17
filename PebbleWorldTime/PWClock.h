//
//  PWClock.h
//  PebbleWorldTime
//
//  Created by Don Krause on 8/31/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "PWTimeAnnotation.h"

@interface PWClock : NSObject

+ (PWClock *)initWithName:(NSString *)name;

@property (nonatomic) NSString          *name;
@property (nonatomic) NSNumber          *backgroundMode;
@property (nonatomic) NSString          *currentTZ;
@property (nonatomic) NSNumber          *displayFormat;
@property (nonatomic) NSString          *locationName;
@property (nonatomic) NSNumber          *latitude;
@property (nonatomic) NSNumber          *longitude;
@property (nonatomic) PWTimeAnnotation  *annot;
@property (nonatomic) NSString          *city;
@property (nonatomic) NSString          *state;
@property (nonatomic) NSString          *country;
@property (nonatomic) NSDate            *lastWeatherUpdate;

@end
