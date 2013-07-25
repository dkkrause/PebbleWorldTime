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
@synthesize cityDatabase = _cityDatabase;
@synthesize filteredTZList = _filteredTZList;

#pragma mark - UIViewController methods

#ifdef USECOREDATA                      // Using Core Data

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

- (void)fetchCityDataIntoDocument:(UIManagedDocument *)document
{
    dispatch_queue_t fetchQ = dispatch_queue_create("City data fetcher", NULL);
    dispatch_async(fetchQ, ^{

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
            
            for (NSString *city in cities) {
                
            }
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            
            NSLog(@"Error downloading %@: %@", request, error);
            
        }];
        
        [operation start];
        

            // should probably saveToURL:forSaveOperation:(UIDocumentSaveForOverwriting)completionHandler: here!
            // we could decide to rely on UIManagedDocument's autosaving, but explicit saving would be better
            // because if we quit the app before autosave happens, then it'll come up blank next time we run
            // this is what it would look like (ADDED AFTER LECTURE) ...
            [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:NULL];
            // note that we don't do anything in the completion handler this time
        
    });
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

#endif                          // Using Core Data

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    
    [self.tzSearchBar resignFirstResponder];
    
}

@end
