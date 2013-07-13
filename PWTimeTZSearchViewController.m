//
//  PWTimeTZSearchViewController.m
//  PebbleWorldTime
//
//  Created by Don Krause on 7/13/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import "PWTimeTZSearchViewController.h"

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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

@end
