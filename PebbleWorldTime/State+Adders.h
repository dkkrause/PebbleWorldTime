//
//  State+Adders.h
//  PebbleWorldTime
//
//  Created by Don Krause on 7/25/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "State.h"

@interface State (Adders)

+ (void)populateStateDB;
+ (NSString *)stateNameFromCode:(NSString *)code;
+ (State *)stateWithCode:(NSString *)code inManagedObjectContext:(NSManagedObjectContext *)context;

@end
