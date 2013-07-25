//
//  Country+Adders.h
//  PebbleWorldTime
//
//  Created by Don Krause on 7/25/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "Country.h"

@interface Country (Adders)

+ (void)populateCountryDB;
+ (NSString *)countryNameFromCode:(NSString *)code;
+ (Country *)countryWithCode:(NSString *)code inManagedObjectContext:(NSManagedObjectContext *)context;

@end
