//
//  PWTimeTZController.m
//  Pebble World Time
//
//  Created by Don Krause on 5/31/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PWTimeTZController.h"
#import "PWTimeViewController.h"

@interface PWTimeTZController ()

@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) NSTimeZone *clockTZ;
@property (weak, nonatomic) NSArray *tzList;

@end

@implementation PWTimeTZController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
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
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:startPos inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.tzList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TZCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    cell.textLabel.text = [self.tzList objectAtIndex:[indexPath row]];
    if ([cell.textLabel.text isEqualToString:[self.clockTZ name]]) {
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.backgroundColor = [UIColor blueColor];
    } else {
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.backgroundColor = [UIColor whiteColor];
    }
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
    
    [self.delegate setClockTZ:[NSTimeZone timeZoneWithName:[self.tzList objectAtIndex:indexPath.row]]];
    [self dismissViewControllerAnimated:YES completion:nil];

}

@end
