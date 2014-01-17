//
//  PWTimeAnnotation.h
//  PebbleWorldTime
//
//  Created by Don Krause on 1/15/14.
//  Copyright (c) 2014 Don Krause. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <MapKit/MapKit.h>

@interface PWTimeAnnotation : NSObject <MKAnnotation>
+ (PWTimeAnnotation *)annotationWithTitle:(NSString *)title forLocation:(CLLocationCoordinate2D)coordinate;
@end
