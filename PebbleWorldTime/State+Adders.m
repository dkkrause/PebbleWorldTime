//
//  State+Adders.m
//  PebbleWorldTime
//
//  Created by Don Krause on 7/25/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "State+Adders.h"
#import "City+Adders.h"
#import "Country+Adders.h"

@implementation State (Adders)

+ (void)populateStateDB
{
    
}

+ (NSString *)stateNameFromCode:(NSString *)code
{
    
    NSString *name = nil;
    
    return name;
    
}

+ (State *)stateWithCode:(NSString *)code
  inManagedObjectContext:(NSManagedObjectContext *)context
{
    
    State *state = nil;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"State"];
    request.predicate = [NSPredicate predicateWithFormat:@"code = %@", code];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches || ([matches count] > 1)) {
        // handle error
    } else if ([matches count] == 0) {
        state.code = code;
        state = [NSEntityDescription insertNewObjectForEntityForName:@"State" inManagedObjectContext:context];
        //        state.name = name;
        state.myCountry = [Country countryWithCode:@"" inManagedObjectContext:context];
    } else {
        state = [matches lastObject];
    }
    
    return state;
}

@end
