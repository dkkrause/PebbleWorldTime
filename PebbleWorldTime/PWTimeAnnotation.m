//
//  PWTimeAnnotation.m
//  PebbleWorldTime
//
//  Created by Don Krause on 1/15/14.
//  Copyright (c) 2014 Don Krause. All rights reserved.
//

#import "PWTimeAnnotation.h"

@interface PWTimeAnnotation ()
@property (nonatomic) NSString *annotTitle;
@property (nonatomic) CLLocationCoordinate2D annotCoordinate;
@end

@implementation PWTimeAnnotation

+ (PWTimeAnnotation *)annotationWithTitle:(NSString *)title forLocation:(CLLocationCoordinate2D)coordinate
{
    PWTimeAnnotation *annotation = [[PWTimeAnnotation alloc] init];
    annotation.annotTitle = title;
    annotation.annotCoordinate = coordinate;
    NSLog(@"PWTimeAnnotation, annotation=%@", annotation);
    return annotation;
}

#pragma mark - MKAnnotation

- (NSString *)title
{
    return self.annotTitle;
}

- (NSString *)subtitle
{
    return nil;
}

- (CLLocationCoordinate2D)coordinate
{
    return self.annotCoordinate;
}

@end
