//
//  PWTimeTZController.h
//  Pebble World Time
//
//  Created by Don Krause on 5/31/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PWTimeTZController : UITableViewController
@property (strong,nonatomic) NSArray *tzList;

- (void)setDelegate:(id)delegate;
- (void)setClockTZ:(NSString *)clockTZ;

@end
