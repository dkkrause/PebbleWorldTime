//
//  State.h
//  PebbleWorldTime
//
//  Created by Don Krause on 7/24/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class City, Country;

@interface State : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * code;
@property (nonatomic, retain) NSSet *cities;
@property (nonatomic, retain) Country *myCountry;
@end

@interface State (CoreDataGeneratedAccessors)

- (void)addCitiesObject:(City *)value;
- (void)removeCitiesObject:(City *)value;
- (void)addCities:(NSSet *)values;
- (void)removeCities:(NSSet *)values;

@end
