//
//  Country.h
//  PebbleWorldTime
//
//  Created by Don Krause on 7/24/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class City, State;

@interface Country : NSManagedObject

@property (nonatomic, retain) NSString * code;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet *cities;
@property (nonatomic, retain) NSSet *states;
@end

@interface Country (CoreDataGeneratedAccessors)

- (void)addCitiesObject:(City *)value;
- (void)removeCitiesObject:(City *)value;
- (void)addCities:(NSSet *)values;
- (void)removeCities:(NSSet *)values;

- (void)addStatesObject:(State *)value;
- (void)removeStatesObject:(State *)value;
- (void)addStates:(NSSet *)values;
- (void)removeStates:(NSSet *)values;

@end
