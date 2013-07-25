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
#define GEONAMES_CITY               0x01
#define GEONAMES_LATITUDE           0x04
#define GEONAMES_LONGITUDE          0x05
#define GEONAMES_COUNTRY            0x08
#define GEONAMES_STATE              0x09
#define GEONAMES_POPULATION         0x0E
#define GEONAMES_TIMEZONE           0x11

// #define USECOREDATA

// Field locations in country database

// Field locations in Admin1 database (US states only used items)

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
