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

@end

@implementation PWTimeAppDelegate
{
    UIBackgroundFetchResult result;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    return YES;
}

/*
- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
#ifdef BGDEBUG
    NSLog(@"Entering application:performFetchWithCompletionHandler:\n");
#endif
    completionHandler(UIBackgroundFetchResultNoData);
}
*/

- (void)applicationWillResignActive:(UIApplication *)application
{
#ifdef BGDEBUG
    NSLog(@"Entering applicationWillResignActive:\n");
#endif
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UINavigationController *navigationController = (UINavigationController *)window.rootViewController;
    PWTimeViewController *vc = (PWTimeViewController *)[navigationController.viewControllers objectAtIndex: 0];
    [vc stopWeatherTimer];
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
#ifdef BGDEBUG
    NSLog(@"Entering applicationDidEnterBackground:\n");
#endif
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
#ifdef BGDEBUG
    NSLog(@"Entering applicationWillEnterForeground:\n");
#endif
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UINavigationController *navigationController = (UINavigationController *)window.rootViewController;
    PWTimeViewController *vc = (PWTimeViewController *)[navigationController.viewControllers objectAtIndex: 0];
    [vc startWeatherTimer:1];
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
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UINavigationController *navigationController = (UINavigationController *)window.rootViewController;
    PWTimeViewController *vc = (PWTimeViewController *)[navigationController.viewControllers objectAtIndex: 0];
    [vc stopTrackingUser];
}

@end
