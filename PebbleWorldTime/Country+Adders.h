//
//  Country+Adders.h
//  PebbleWorldTime
//
//  Created by Don Krause on 7/25/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "Country.h"

@interface Country (Adders)

+ (Country *)countryWithCode:(NSString *)code
                    withName:(NSString *)name
      inManagedObjectContext:(NSManagedObjectContext *)context;

@end
