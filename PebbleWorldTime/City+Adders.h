//
//  City+Adders.h
//  PebbleWorldTime
//
//  Created by Don Krause on 7/25/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "City.h"

@interface City (Adders)

+ (City *)cityWithName:(NSString *)name
             stateCode:(NSString *)stateCode
             stateName:(NSString *)stateName
           countryCode:(NSString *)countryCode
           countryName:(NSString *)countryName
              latitude:(NSNumber *)latitude
             longitude:(NSNumber *)longitude
              timeZone:(NSString *)timezone
inManagedObjectContext:(NSManagedObjectContext *)context;

@end
