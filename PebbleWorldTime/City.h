//
//  City.h
//  PebbleWorldTime
//
//  Created by Don Krause on 7/24/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Country, State;

@interface City : NSManagedObject

+ (City *)cityWithName:(NSString *)name
               inState:(State *)state
             inCountry:(Country *)country
              latitude:(NSNumber *)latitude
             longitude:(NSNumber *)longitude
            inTimeZone:(NSTimeZone *)timezone
inManagedObjectContext:(NSManagedObjectContext *)context;

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSString * timezone;
@property (nonatomic, retain) Country *myCountry;
@property (nonatomic, retain) State *myState;

@end
