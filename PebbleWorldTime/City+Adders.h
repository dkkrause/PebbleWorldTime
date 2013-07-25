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
               inState:(State *)state
             inCountry:(Country *)country
              latitude:(NSNumber *)latitude
             longitude:(NSNumber *)longitude
            inTimeZone:(NSString *)timezone
inManagedObjectContext:(NSManagedObjectContext *)context;

@end
