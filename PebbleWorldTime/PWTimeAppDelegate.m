//
//  PWTimeAppDelegate.m
//  PebbleWorldTime
//
//  Created by Don Krause on 6/2/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "PWTimeAppDelegate.h"
#import "PWTimeViewController.h"

@interface PWTimeAppDelegate ()

@property (nonatomic) NSDate *lastDataFetch;

@end

@implementation PWTimeAppDelegate
{
    UIBackgroundFetchResult result;
}

@synthesize lastDataFetch = _lastDataFetch;

- (NSDate *)lastDataFetch
{
    if (_lastDataFetch == nil) {
        _lastDataFetch = [[NSDate alloc] init];
    }
    return _lastDataFetch;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [self enableBackgroundFetch];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
#ifdef BGDEBUG
    NSLog(@"Entering applicationWillResignActive:\n");
#endif
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    PWTimeViewController *rootViewController = (PWTimeViewController*)self.window.rootViewController;
    [rootViewController stopWeatherTimer];
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
#ifdef BGDEBUG
    NSLog(@"Entering applicationDidEnterBackground:\n");
#endif
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    self.lastDataFetch = [NSDate date];
}

- (void)enableBackgroundFetch
{
#ifdef BGDEBUG
    NSLog(@"Entering enableBackgroundFetch:\n");
#endif
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
}

- (void)disableBackgroundFetch
{
#ifdef BGDEBUG
    NSLog(@"Entering disableBackgroundFetch:\n");
#endif
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    
#define WEATHER_REFRESH_TIME    1800
    
#ifdef BGDEBUG
    NSLog(@"Entering performFetchWithCompletionHandler:\n");
#endif
    if (abs([self.lastDataFetch timeIntervalSinceNow]) < WEATHER_REFRESH_TIME) {
        result = UIBackgroundFetchResultNoData;
    } else {
        PWTimeViewController *rootViewController = (PWTimeViewController*)self.window.rootViewController;
        [rootViewController backgroundUpdateWeather:completionHandler];
        result = UIBackgroundFetchResultNewData;
        self.lastDataFetch = [NSDate date];
    }
    completionHandler(result);    
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
#ifdef BGDEBUG
    NSLog(@"Entering applicationWillEnterForeground:\n");
#endif
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    PWTimeViewController *rootViewController = (PWTimeViewController*)self.window.rootViewController;
    [rootViewController startWeatherTimer:1];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
#ifdef BGDEBUG
    NSLog(@"Entering applicationDidBecomeActive:\n");
#endif
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
#ifdef BGDEBUG
    NSLog(@"Entering applicationWillTerminate:\n");
#endif
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    PWTimeViewController *rootViewController = (PWTimeViewController*)self.window.rootViewController;
    [rootViewController stopSignificantLocationChangeUpdates];

}

@end
