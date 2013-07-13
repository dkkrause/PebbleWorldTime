//
//  PWTimeTZSearchViewController.h
//  PebbleWorldTime
//
//  Created by Don Krause on 7/13/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PWTimeTZSearchViewController : UIViewController

@property (strong, nonatomic) IBOutlet UISearchBar *tzSearchBar;
@property (strong, nonatomic) IBOutlet UITableView *tzTable;

- (void)setDelegate:(id)delegate;
- (void)setClockTZ:(NSTimeZone *)clockTZ;

@end
