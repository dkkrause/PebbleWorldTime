//
//  PWTZMapViewController.h
//  PebbleWorldTime
//
//  Created by Don Krause on 8/12/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "PWTimeViewController.h"
#import "PWClock.h"

@interface PWTZMapViewController : UIViewController
@property  (strong, atomic) id delegate;
@property (strong, atomic) PWClock *clock;
@end
