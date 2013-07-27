//
//  State+Adders.h
//  PebbleWorldTime
//
//  Created by Don Krause on 7/25/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "State.h"

@interface State (Adders)

+ (State *)stateWithCode:(NSString *)code
                withName:(NSString *)name
             countryCode:(NSString *)countryCode
             countryName:(NSString *)countryName
  inManagedObjectContext:(NSManagedObjectContext *)context;

@end
