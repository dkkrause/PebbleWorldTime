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
             stateCode:(NSString *)stateCode
             stateName:(NSString *)stateName
           countryCode:(NSString *)countryCode
           countryName:(NSString *)countryName
              latitude:(NSNumber *)latitude
             longitude:(NSNumber *)longitude
              timeZone:(NSString *)timezone
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
        if ([stateCode isEqualToString:@"US"]) {
            city.myState = [State stateWithCode:stateCode withName:stateName countryCode:countryCode countryName:countryName inManagedObjectContext:context];
        } else {
            city.myState = nil;
            city.myCountry = [Country countryWithCode:countryCode withName:countryName inManagedObjectContext:context];
        }
        city.latitude = latitude;
        city.longitude = longitude;
        city.timezone = timezone;
    } else {
        city = [matches lastObject];
    }
    return city;
}

@end
