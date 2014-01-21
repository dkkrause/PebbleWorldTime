//
//  PWMapViewController.m
//  PebbleWorldTime
//
//  Created by Don Krause on 1/9/14.
//  Copyright (c) 2014 Don Krause. All rights reserved.
//

#import "PWMapViewController.h"
#import "PWTimeViewController.h"
#import "PWTimeAnnotation.h"

@interface PWMapViewController () <MKMapViewDelegate, UIGestureRecognizerDelegate>

@property (strong, nonatomic)   IBOutlet MKMapView     *bigMap;
@property (weak, nonatomic)     PWTimeAnnotation       *annot;
@property (weak, nonatomic)     MKAnnotationView       *annotationView;
@property (strong, nonatomic)   UITapGestureRecognizer *tpgr;

@end

@implementation PWMapViewController
{
    BOOL viewingAnnotation;
}

- (IBAction)centerMap:(id)sender {
    // Re-center map on selected point
    MKCoordinateRegion mapRegion;
    mapRegion.center = self.coordinate;
    mapRegion.span = MKCoordinateSpanMake(0.1, 0.1);
    [self.bigMap setRegion:mapRegion animated:YES];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    
    CGPoint touchPoint = [recognizer locationInView:self.bigMap];
    self.coordinate = [self.bigMap convertPoint:touchPoint toCoordinateFromView:self.bigMap];
    MKCoordinateRegion mapRegion;
    mapRegion.center = self.coordinate;
    mapRegion.span = MKCoordinateSpanMake(0.1, 0.1);
    [self.bigMap removeAnnotation:self.annot];
    CLLocation *tzLocation = [[CLLocation alloc] initWithLatitude:self.coordinate.latitude longitude:self.coordinate.longitude];
    CLGeocoder *geoCoder = [[CLGeocoder alloc] init];
    [geoCoder reverseGeocodeLocation:tzLocation completionHandler:^(NSArray *placemarks, NSError *error) {
        CLPlacemark *placemark = [placemarks lastObject];
        NSArray *lines = placemark.addressDictionary[ @"FormattedAddressLines"];
        NSString *addressString = [lines componentsJoinedByString:@", "];
        PWTimeAnnotation *newAnnot = [PWTimeAnnotation annotationWithTitle:addressString forLocation:self.coordinate];
        self.annot = newAnnot;
        [self.bigMap addAnnotation:self.annot];
#ifdef MAPDEBUG
        NSLog(@"PWMapViewController:handleSingleTap, Address: %@, annot: %@", addressString, self.annot);
#endif
    }];
    [self.bigMap setRegion:mapRegion animated:YES];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:self.coordinate.latitude longitude:self.coordinate.longitude];
    [(PWTimeViewController *)self.delegate setTzLocation:location];

}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
#ifdef MAPDEBUG
    NSLog(@"gestureRecognizer, annotView:, %d, viewingAnnotation, %d", touch.view == [self.bigMap viewForAnnotation:self.annot], viewingAnnotation);
#endif
    if ((touch.view == [self.bigMap viewForAnnotation:self.annot]) || viewingAnnotation) {
        viewingAnnotation = !viewingAnnotation;
        return NO;
    } else {
        return YES;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    // Long press selects timezone, when that watch is selected
    self.tpgr = [[UITapGestureRecognizer alloc]
                 initWithTarget:self
                 action:@selector(handleSingleTap:)];
    self.tpgr.delegate = self;
    viewingAnnotation = NO;
    
    self.bigMap.zoomEnabled       = YES;
    self.bigMap.scrollEnabled     = YES;
    self.bigMap.pitchEnabled      = NO;
    self.bigMap.rotateEnabled     = NO;
    self.bigMap.showsUserLocation = YES;
    
    [self.bigMap addGestureRecognizer:self.tpgr];
    
    MKCoordinateRegion mapRegion;
    mapRegion.center = self.coordinate;
    mapRegion.span = MKCoordinateSpanMake(0.1, 0.1);
    [self.bigMap removeAnnotation:self.annot];
    CLLocation *tzLocation = [[CLLocation alloc] initWithLatitude:self.coordinate.latitude longitude:self.coordinate.longitude];
    CLGeocoder *geoCoder = [[CLGeocoder alloc] init];
    [geoCoder reverseGeocodeLocation:tzLocation completionHandler:^(NSArray *placemarks, NSError *error) {
        CLPlacemark *placemark = [placemarks lastObject];
        NSArray *lines = placemark.addressDictionary[ @"FormattedAddressLines"];
        NSString *addressString = [lines componentsJoinedByString:@", "];
        PWTimeAnnotation *newAnnot = [PWTimeAnnotation annotationWithTitle:addressString forLocation:self.coordinate];
        self.annot = newAnnot;
        [self.bigMap addAnnotation:self.annot];
#ifdef MAPDEBUG
        NSLog(@"PWMapViewController:viewWillAppear, Address: %@, newAnnot: %@, self.annot: %@", addressString, newAnnot, self.annot);
#endif
    }];
    [self.bigMap setRegion:mapRegion animated:YES];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Do any additional setup after loading the view.
    
}

- (void)viewWillDisappear:(BOOL)animated {
    self.annot = nil;
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    MKAnnotationView *aView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"PWTSelectVC"];
    if (!aView) {
        aView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"PWTSelectVC"];
        aView.canShowCallout = YES;
        aView.rightCalloutAccessoryView = nil;
    }
    aView.annotation = annotation;
    return aView;
}

@end
