//
//  PWTimeTZController.h
//  Pebble World Time
//
//  Created by Don Krause on 5/31/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PWTimeTZController : UITableViewController

- (void)setDelegate:(id)delegate;
- (void)setClockTZ:(NSTimeZone *)clockTZ;

@end
