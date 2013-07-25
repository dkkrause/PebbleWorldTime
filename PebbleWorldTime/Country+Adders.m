//
//  Country+Adders.m
//  PebbleWorldTime
//
//  Created by Don Krause on 7/25/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "Country+Adders.h"
#import "State+Adders.h"
#import "City+Adders.h"

@implementation Country (Adders)

+ (void)populateCountryDB
{
    
}

+ (NSString *)countryNameFromCode:(NSString *)code
{
    
    NSString *name = nil;
    
    return name;
    
}

+ (Country *)countryWithCode:(NSString *)code
      inManagedObjectContext:(NSManagedObjectContext *)context
{
    
    Country *country = nil;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Country"];
    request.predicate = [NSPredicate predicateWithFormat:@"code = %@", code];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches || ([matches count] > 1)) {
        // handle error
    } else if ([matches count] == 0) {
        country = [NSEntityDescription insertNewObjectForEntityForName:@"Country" inManagedObjectContext:context];
        country.code = code;
        country.name = [Country countryNameFromCode:code];
    } else {
        country = [matches lastObject];
    }
    
    return country;
}

@end
