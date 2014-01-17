//
//  PWMapViewController.h
//  PebbleWorldTime
//
//  Created by Don Krause on 1/9/14.
//  Copyright (c) 2014 Don Krause. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface PWMapViewController : UIViewController
@property CLLocationCoordinate2D coordinate;
@property id delegate;

@end
