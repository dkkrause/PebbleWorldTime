//
//  Country+Adders.m
//  PebbleWorldTime
//
//  Created by Don Krause on 7/25/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "Country+Adders.h"

@implementation Country (Adders)

+ (Country *)countryWithCode:(NSString *)code
                    withName:(NSString *)name
      inManagedObjectContext:(NSManagedObjectContext *)context
{
    
    Country *country = nil;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Country"];
    request.predicate = [NSPredicate predicateWithFormat:@"code == %@ AND name == %@", code, name];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches || ([matches count] > 1)) {
        // handle error
    } else if ([matches count] == 0) {
        country = [NSEntityDescription insertNewObjectForEntityForName:@"Country" inManagedObjectContext:context];
        country.code = code;
        country.name = name;
    } else {
        country = [matches lastObject];
    }
    return country;
}

@end
