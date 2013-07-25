//
//  City+Adders.m
//  PebbleWorldTime
//
//  Created by Don Krause on 7/25/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "City+Adders.h"
#import "State+Adders.h"
#import "Country+Adders.h"

@implementation City (Adders)

+ (City *)cityWithName:(NSString *)name
               inState:(NSString *)stateCode
             inCountry:(NSString *)countryCode
              latitude:(NSNumber *)latitude
             longitude:(NSNumber *)longitude
            inTimeZone:(NSString *)timezone
inManagedObjectContext:(NSManagedObjectContext *)context
{
    
    City *city = nil;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"City"];
    request.predicate = [NSPredicate predicateWithFormat:@"name == %@ AND state.myState.code == %@ AND state.myCountry.code == %@", name, stateCode, countryCode];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches || ([matches count] > 1)) {
        // handle error
    } else if ([matches count] == 0) {
        city = [NSEntityDescription insertNewObjectForEntityForName:@"City" inManagedObjectContext:context];
        city.name = name;
        city.myState = [State stateWithCode:stateCode inManagedObjectContext:context];
        city.myCountry = [Country countryWithCode:countryCode inManagedObjectContext:context];
        city.latitude = latitude;
        city.longitude = longitude;
        city.timezone = timezone;
    } else {
        city = [matches lastObject];
    }
    
    return city;
}

@end
