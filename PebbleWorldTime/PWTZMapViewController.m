//
//  PWTZMapViewController.m
//  PebbleWorldTime
//
//  Created by Don Krause on 8/12/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "PWTZMapViewController.h"

@interface PWTZMapViewController () <MKMapViewDelegate>
@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) IBOutlet UISegmentedControl *centerPoint;
@end

@implementation PWTZMapViewController

- (IBAction)goBack:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)centerLocation:(id)sender
{
    switch ([self.centerPoint selectedSegmentIndex]) {
    case 0:
        [self centerMap:self.mapView.userLocation.coordinate];
        break;
    case 1:
        if ([self.clock.latitude floatValue] != 1000.0) {
            [self centerMap:CLLocationCoordinate2DMake([self.clock.latitude floatValue], [self.clock.longitude floatValue])];
            }
        break;
    default:
        break;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.minimumPressDuration = 2.0; //user needs to press for 2 seconds
    [self.mapView addGestureRecognizer:lpgr];
}

- (void)centerMap:(CLLocationCoordinate2D)coord
{
    MKCoordinateRegion mapRegion;
    mapRegion.center = coord;
    mapRegion.span = MKCoordinateSpanMake(0.2, 0.2);
    [self.mapView setRegion:mapRegion animated: YES];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.mapView.showsUserLocation = YES;
    self.mapView.pitchEnabled = NO;
    self.mapView.rotateEnabled = NO;
    if ([self.clock.latitude floatValue] != 1000.0) {
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([self.clock.latitude floatValue], [self.clock.longitude floatValue]);
        [self centerMap:coordinate];
        MKPointAnnotation *annot = [[MKPointAnnotation alloc] init];
        annot.coordinate = coordinate;
        [self.mapView addAnnotation:annot];
    }
}

- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan)
        return;
    
    CGPoint touchPoint = [gestureRecognizer locationInView:self.mapView];
    CLLocationCoordinate2D touchMapCoordinate =
    [self.mapView convertPoint:touchPoint toCoordinateFromView:self.mapView];
    
//    MKPointAnnotation *annot = [[MKPointAnnotation alloc] init];
//    annot.coordinate = touchMapCoordinate;
//    [self.mapView addAnnotation:annot];
    
    CLLocation *newTZlocation = [[CLLocation alloc] initWithCoordinate:touchMapCoordinate altitude:0 horizontalAccuracy:0 verticalAccuracy:0 course:0 speed:0 timestamp:[NSDate date]];
    [self.delegate setTzLocation:newTZlocation forClock:self.clock];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
