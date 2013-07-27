//
//  PWTimeTZSearchViewController.m
//  PebbleWorldTime
//
//  Created by Don Krause on 7/13/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "PWTimeTZSearchViewController.h"
#import "PWTimeViewController.h"
#import "AFNetworking/AFNetworking.h"
#import "ZipArchive/ZipArchive.h"
#import <CoreData/CoreData.h>
#import "PWTimeAppDelegate.h"

#import "City+Adders.h"
#import "State+Adders.h"
#import "Country+Adders.h"

@interface PWTimeTZSearchViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) NSTimeZone *clockTZ;
@property (weak, nonatomic) NSArray *tzList;
@property (strong, nonatomic) NSMutableArray *filteredTZList;
@property BOOL filterList;

@end

@implementation PWTimeTZSearchViewController

#ifndef USECOREDATA

@synthesize tzTable = _tzTable;
@synthesize tzSearchBar = _tzSearchBar;
@synthesize cityDatabase = _cityDatabase;
@synthesize filteredTZList = _filteredTZList;

#endif

#ifdef USECOREDATA

#define MINIMUM_US_POPULATION                     50000
#define MINIMUM_REST_OF_WORLD_POPULATION        1000000

static NSString *baseURL        = @"http://download.geonames.org/export/dump/";
static NSString *cityZipFile    = @"cities15000.zip";
static NSString *cityTxtFile    = @"cities15000.txt";
static NSString *countryFile    = @"countryInfo.txt";
static NSString *stateFile      = @"admin1CodesASCII.txt";

#endif

- (void)setDelegate:(id)delegate
{
    if (_delegate != delegate) {
        _delegate = delegate;
    }
}

- (void)setClockTZ:(NSTimeZone *)clockTZ
{
    if (![clockTZ isEqualToTimeZone:_clockTZ]) {
        _clockTZ = clockTZ;
    }
}

#pragma mark - UIViewController methods

#ifdef USECOREDATA                      // Using Core Data
- (void)downloadCountryData
{
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[baseURL stringByAppendingString:countryFile]]];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths lastObject] stringByAppendingPathComponent:countryFile];
    operation.outputStream = [NSOutputStream outputStreamToFileAtPath:path append:NO];
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSLog(@"Successfully downloaded file %@ to %@", request, path);        
        [self downloadStateData];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"Error downloading %@: %@", request, error);
        
    }];
    
    [operation start];
}

- (void)downloadStateData
{
        
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[baseURL stringByAppendingString:stateFile]]];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths lastObject] stringByAppendingPathComponent:stateFile];
    operation.outputStream = [NSOutputStream outputStreamToFileAtPath:path append:NO];
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSLog(@"Successfully downloaded file %@ to %@", request, path);
        [self downloadCityData];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"Error downloading %@: %@", request, error);
        
    }];
    [operation start];
    
}

- (void)downloadCityData
{
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[baseURL stringByAppendingString:cityZipFile]]];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths lastObject] stringByAppendingPathComponent:cityZipFile];
    operation.outputStream = [NSOutputStream outputStreamToFileAtPath:path append:NO];
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSError *error;
        NSLog(@"Successfully downloaded file %@ to %@", request, path);
        // Unzip the file
        ZipArchive *zipArchive = [[ZipArchive alloc] init];
        [zipArchive UnzipOpenFile:path];
        [zipArchive UnzipFileTo:[paths objectAtIndex:0] overWrite:YES];
        [zipArchive UnzipCloseFile];
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];    // Delete the zip file
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"Error downloading %@: %@", request, error);
        
    }];
    
    [operation start];
}

- (void)populateCityDB
{
    
    NSMutableDictionary *countryData;
    NSMutableDictionary *stateData;
    
    countryData = [[NSMutableDictionary alloc] init];
    stateData = [[NSMutableDictionary alloc] init];
    
    // Read all three files into memory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

    NSString *countryFilePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:countryFile];
    NSString *countryFileData = [[NSString alloc] initWithContentsOfFile:countryFilePath encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *countries = [[countryFileData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] mutableCopy];
    countryFileData = nil;

    // Create a country dictionary
    NSMutableArray *singleCountryData;
    for (NSString *singleCountry in countries) {        
        if (![singleCountry hasPrefix:@"#"]) {            
            singleCountryData = [[singleCountry componentsSeparatedByString:@"\t"] mutableCopy];
            [countryData setObject:[singleCountryData objectAtIndex:GEONAMES_COUNTRY_NAME_INDEX] forKey:[singleCountryData objectAtIndex:GEONAMES_COUNTRY_CODE_INDEX]];            
        }
    }

    NSString *stateFilePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:stateFile];
    NSString *stateFileData = [[NSString alloc] initWithContentsOfFile:stateFilePath encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *states = [[stateFileData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] mutableCopy];
    stateFileData = nil;
    
    // Create a state dictionary
    NSMutableArray *singleStateData;
    for (NSString *singleState in states) {
        singleStateData = [[singleState componentsSeparatedByString:@"\t"] mutableCopy];
        [stateData setObject:[singleStateData objectAtIndex:GEONAMES_STATE_NAME_INDEX] forKey:[singleStateData objectAtIndex:GEONAMES_STATE_CODE_INDEX]];
    }

    NSString *cityFilePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:cityTxtFile];
    NSString *cityFileData = [[NSString alloc] initWithContentsOfFile:cityFilePath encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *cities = [[cityFileData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] mutableCopy];
    cityFileData = nil;
    
    // Go through the cities and add the ones of interest (population, etc.) by adding the city. The state and/or
    // country will be added as needed. Note that we will only add states in the US, all other countries are cities to country.
    // Limit population in US and other countries separately.
    
    NSMutableArray *singleCityData;
    for (NSString *singleCity in cities) {
        
        singleCityData = [[singleCity componentsSeparatedByString:@"\t"] mutableCopy];
        [City cityWithName:[singleCityData objectAtIndex:GEONAMES_CITY_NAME_INDEX]
                 stateCode:[singleCityData objectAtIndex:GEONAMES_CITY_STATE_CODE_INDEX]
                 stateName:[stateData objectForKey:[NSString stringWithFormat:@"%@.%@", [singleCityData objectAtIndex:GEONAMES_CITY_COUNTRY_CODE_INDEX], [singleCityData objectAtIndex:GEONAMES_CITY_STATE_CODE_INDEX]]]
               countryCode:[singleCityData objectAtIndex:GEONAMES_CITY_COUNTRY_CODE_INDEX]
               countryName:[countryData objectForKey:[singleCityData objectAtIndex:GEONAMES_CITY_COUNTRY_CODE_INDEX]]
                  latitude:[NSNumber numberWithFloat:[[singleCityData objectAtIndex:GEONAMES_CITY_LATITUDE_INDEX] floatValue]]
                 longitude:[NSNumber numberWithFloat:[[singleCityData objectAtIndex:GEONAMES_CITY_LONGITUDE_INDEX] floatValue]]
                  timeZone:[singleCityData objectAtIndex:GEONAMES_CITY_TIMEZONE_INDEX]
    inManagedObjectContext:self.cityDatabase.managedObjectContext];
        
    }
    
}

- (void)fetchCityDataIntoDocument:(UIManagedDocument *)document
{
    dispatch_queue_t fetchQ = dispatch_queue_create("City data fetcher", NULL);
    dispatch_async(fetchQ, ^{        
        [self downloadCountryData];
    });
    dispatch_async(fetchQ, ^{
       [document.managedObjectContext performBlock:^{ // perform in the NSMOC's safe thread (main thread)
           [self populateCityDB];
           [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:NULL];
       }];
    });
}

- (void)setupFetchedResultsController // attaches an NSFetchRequest to this UITableViewController
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"City"];
    request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]];
    // no predicate because we want ALL the Cities
    
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                        managedObjectContext:self.cityDatabase.managedObjectContext
                                                                          sectionNameKeyPath:nil
                                                                                   cacheName:nil];
}

- (void)useDocument
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.cityDatabase.fileURL path]]) {
        // does not exist on disk, so create it
        [self.cityDatabase saveToURL:self.cityDatabase.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
            [self setupFetchedResultsController];
            [self fetchCityDataIntoDocument:self.cityDatabase];
            
        }];
    } else if (self.cityDatabase.documentState == UIDocumentStateClosed) {
        // exists on disk, but we need to open it
        [self.cityDatabase openWithCompletionHandler:^(BOOL success) {
            [self setupFetchedResultsController];
        }];
    } else if (self.cityDatabase.documentState == UIDocumentStateNormal) {
        // already open and ready to use
        [self setupFetchedResultsController];
    }
}

- (void)setCityDatabase:(UIManagedDocument *)cityDatabase
{
    if (_cityDatabase != cityDatabase) {
        _cityDatabase = cityDatabase;
        [self useDocument];
    }
}

- (void)viewWillAppear:(BOOL)animated
{

    [super viewWillAppear:animated];
    
    if (!self.cityDatabase) {  // for demo purposes, we'll create a default database if none is set
        NSURL *url = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        url = [url URLByAppendingPathComponent:@"City Data"];
        // url is now "<Documents Directory>/City Data"
        self.cityDatabase = [[UIManagedDocument alloc] initWithFileURL:url]; // setter will create this for us on disk
    }

}

#endif                                  // Using Core Data

#ifndef USECOREDATA                     // Not using Core Data

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    self.filterList = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.tzList = [NSTimeZone knownTimeZoneNames];
    
    // Determine which time zone is already selected, make that the selected one now, and put it on the screen
    int startPos = 0;
    for (int i=0; i< [self.tzList count]; i++) {
        if ([[self.tzList objectAtIndex:i] isEqualToString:[self.clockTZ name]]) {
            startPos = i;
            break;
        }
    }
    [self.tzTable selectRowAtIndexPath:[NSIndexPath indexPathForRow:startPos inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
    
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.filterList) {
        return self.filteredTZList.count;
    } else {
        return self.tzList.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    static NSString *CellIdentifier = @"TZCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    if (!self.filterList) {
        cell.textLabel.text = [self.tzList objectAtIndex:[indexPath row]];
    } else {
        cell.textLabel.text = [self.filteredTZList objectAtIndex:[indexPath row]];
    }
    if ([cell.textLabel.text isEqualToString:[self.clockTZ name]]) {
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.backgroundColor = [UIColor blueColor];
    } else {
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.backgroundColor = [UIColor whiteColor];
    }
    return cell;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
    
    if (self.filterList) {
        
        [self.delegate setClockTZ:[NSTimeZone timeZoneWithName:[self.filteredTZList objectAtIndex:indexPath.row]]];
        
    } else {
        
        [self.delegate setClockTZ:[NSTimeZone timeZoneWithName:[self.tzList objectAtIndex:indexPath.row]]];
        
    }
    [self dismissViewControllerAnimated:YES completion:nil];
    
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    self.filterList = (searchText.length != 0);
    if (self.filterList) {
        self.filteredTZList = [[NSMutableArray alloc] init];
        for (NSString *tzName in self.tzList) {
            NSRange tzRange = [tzName rangeOfString:searchText options:NSCaseInsensitiveSearch];
            if (tzRange.location != NSNotFound) {
                [self.filteredTZList addObject:tzName];
            }
        }
    } else {
        [self.filteredTZList removeAllObjects];
    }
    [self.tzTable reloadData];
}

#endif                          // Not using Core Data

#ifdef USECOREDATA              // Using Core Data

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    static NSString *CellIdentifier = @"TZCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    // ask NSFetchedResultsController for the NSMO at the row in question
    City *city = [self.fetchedResultsController objectAtIndexPath:indexPath];
    // Then configure the cell using it ...
    cell.textLabel.text = city.name;
    if (city.myState != nil) {
        cell.detailTextLabel.text = city.myState.name;
    } else {
        cell.detailTextLabel.text = city.myCountry.name;
    }
    return cell;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
    City *city = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [self.delegate setClockTZ:[NSTimeZone timeZoneWithName:city.timezone]];
    
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
/*
 self.filterList = (searchText.length != 0);
    if (self.filterList) {
        self.filteredTZList = [[NSMutableArray alloc] init];
        for (NSString *tzName in self.tzList) {
            NSRange tzRange = [tzName rangeOfString:searchText options:NSCaseInsensitiveSearch];
            if (tzRange.location != NSNotFound) {
                [self.filteredTZList addObject:tzName];
            }
        }
    } else {
        [self.filteredTZList removeAllObjects];
    }
    [self.tzTable reloadData];
 
*/
}

#endif                          // Using Core Data

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    
    [self.tzSearchBar resignFirstResponder];
    
}

@end
