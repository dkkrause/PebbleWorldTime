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

@interface PWTimeTZSearchViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) NSTimeZone *clockTZ;
@property (weak, nonatomic) NSArray *tzList;
@property (strong, nonatomic) NSMutableArray *filteredTZList;
@property BOOL filterList;

@end

@implementation PWTimeTZSearchViewController

@synthesize tzTable = _tzTable;
@synthesize tzSearchBar = _tzSearchBar;
@synthesize filteredTZList = _filteredTZList;

#pragma mark - UIViewController methods

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

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

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    
    [self.tzSearchBar resignFirstResponder];
    
}

#pragma mark - Methods to populate CoreData for table

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - methods to populate city database from geonames.org cities files

//
// Flow is download file (delete if present already), set a NSUserDefault to file downloaded, not put in Core Data state
// Then read the file and put it's contents in Core Data (wipe first to make sure it's clean)
// Then set a User Default that says the data has been populated and the date
// Every 90 days repopulate, maybe ask first, and provide a settings button to force a repopulate
//

#define POPULATE_NO_FILE            0x01
#define POPULATE_FILE_DOWNLOADED    0x02
#define POPULATE_FILE_UNZIPPED      0x03
#define POPULATE_COMPLETE           0x04

- (void) populateCities
{
    
    // Download the file
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://download.geonames.org/export/dump/cities15000.zip"]];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths lastObject] stringByAppendingPathComponent:@"cities15000.zip"];
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
        
        NSString *txtPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"cities15000.txt"];
        NSString *cityData = [[NSString alloc] initWithContentsOfFile:txtPath encoding:NSUTF8StringEncoding error:nil];
        NSMutableArray *cities = [[cityData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] mutableCopy];
        
        PWTimeAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        
        for (NSString *city in cities) {
            
        }
                
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"Error downloading %@: %@", request, error);
        
    }];
    
    [operation start];
    
}

#define SECONDS_IN_90_DAYS      (60 * 60 * 24 * 90)

- (bool) repopulateCitiesNeeded
{
    // Check the state, if not PWTCitiesDBPopulated then respond yes
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int state = [defaults integerForKey:@"CITY_DB_POPULATE_STATE_KEY"];
    
    // If state is good, has it been 90 days since last time populated? If so, respond yes
    if (state == POPULATE_COMPLETE) {
        
        // Check to see if it's been 90 days or more
        NSDate *rightNow = [[NSDate alloc] init];
        NSDate *lastUpdated = (NSDate *)[defaults objectForKey:@"CITY_DB_POPULATE_DATE_KEY"];
        if ([rightNow timeIntervalSinceDate:lastUpdated] > SECONDS_IN_90_DAYS) {
            return true;
        } else {
            return false;
        }
        
    } else {
        
        // Data is complete, less than 90 days old
        return true;
        
    }
    
}

@end
