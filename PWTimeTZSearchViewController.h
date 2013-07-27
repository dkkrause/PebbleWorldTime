//
//  PWTimeTZSearchViewController.h
//  PebbleWorldTime
//
//  Created by Don Krause on 7/13/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CoreDataTableViewController.h"

// Field locations in city database
#define GEONAMES_CITY_NAME_INDEX            0x01
#define GEONAMES_CITY_LATITUDE_INDEX        0x04
#define GEONAMES_CITY_LONGITUDE_INDEX       0x05
#define GEONAMES_CITY_COUNTRY_CODE_INDEX    0x08
#define GEONAMES_CITY_STATE_CODE_INDEX      0x09
#define GEONAMES_CITY_POPULATION_INDEX      0x0E
#define GEONAMES_CITY_TIMEZONE_INDEX        0x11

// Field locations in country database
#define GEONAMES_COUNTRY_CODE_INDEX         0x00
#define GEONAMES_COUNTRY_NAME_INDEX         0x04

// Field locations in Admin1 database (US states only used items)
// The code in this file is GEONAMES_COUNTRY_CODE + '.' + GEONAMES_CITY_STATE_CODE_INDEX
#define GEONAMES_STATE_CODE_INDEX           0x00
#define GEONAMES_STATE_NAME_INDEX           0x01

//
// Remove comment below to use Core Data DB
//
//#define USECOREDATA
//
// Remove comment above to use Core Data DB
//

#ifdef USECOREDATA
@interface PWTimeTZSearchViewController : CoreDataTableViewController
#endif

#ifndef USECOREDATA
@interface PWTimeTZSearchViewController : UIViewController
#endif

@property (strong, nonatomic) IBOutlet UISearchBar *tzSearchBar;
@property (strong, nonatomic) IBOutlet UITableView *tzTable;

@property (nonatomic, strong) UIManagedDocument *cityDatabase;  // Model is a Core Data database of photos

- (void)setDelegate:(id)delegate;
- (void)setClockTZ:(NSTimeZone *)clockTZ;

@end
