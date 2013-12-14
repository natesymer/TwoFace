//
//  NewPrefs.m
//  TwoFace
//
//  Created by Nathaniel Symer on 9/23/12.
//  Copyright (c) 2012 Nathaniel Symer. All rights reserved.
//

#import "PrefsViewController.h"
#import "FHSTwitterEngine.h"

@implementation PrefsViewController

- (void)loadView {
    [super loadView];
    CGRect screenBounds = [[UIScreen mainScreen]bounds];
    self.view = [[UIView alloc]initWithFrame:screenBounds];
    self.theTableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, screenBounds.size.width, screenBounds.size.height) style:UITableViewStyleGrouped];
    _theTableView.delegate = self;
    _theTableView.dataSource = self;
    _theTableView.contentInset = UIEdgeInsetsMake(64, 0, 0, 0);
    _theTableView.scrollIndicatorInsets = UIEdgeInsetsMake(64, 0, 0, 0);
    [self.view addSubview:_theTableView];
    
    UINavigationBar *bar = [[UINavigationBar alloc]initWithFrame:CGRectMake(0, 0, screenBounds.size.width, 64)];
    UINavigationItem *topItem = [[UINavigationItem alloc]initWithTitle:@"Settings"];
    topItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Close" style:UIBarButtonItemStyleBordered target:self action:@selector(close)];
    topItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"dropbox-icon"] style:UIBarButtonItemStylePlain target:self action:@selector(showSyncMenu)];
    [bar pushNavigationItem:topItem animated:NO];
    [self.view addSubview:bar];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_theTableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == 0)?2:1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        NSMutableArray *usernames = [NSMutableArray array];
        
        if (FHSFacebook.shared.user.name.length > 0) {
            [usernames addObject:FHSFacebook.shared.user.name];
        }
        
        if (FHSTwitterEngine.sharedEngine.authenticatedUsername.length > 0) {
            [usernames addObject:[NSString stringWithFormat:@"@%@",FHSTwitterEngine.sharedEngine.authenticatedUsername]];
        }
        return [usernames componentsJoinedByString:@", "];
    } else if (section == 2) {
        return [@"TwoFace v" stringByAppendingString:NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell4";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    int section = indexPath.section;

    if (section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = FHSTwitterEngine.sharedEngine.isAuthorized?@"Log out of Twitter":@"Sign into Twitter";
        } else {
            cell.textLabel.text = FHSFacebook.shared.isSessionValid?@"Log out of Facebook":@"Sign into Facebook";
        }
    } else if (section == 1) {
        cell.textLabel.text = @"Select Users to Watch";
    } else if (section == 2) {
        cell.textLabel.text = @"Show Caches Menu";
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    int section = indexPath.section;
    int row = indexPath.row;
    
    AppDelegate *ad = [Settings appDelegate];
    
    if (section == 0) {
        if (row == 0) {
            if ([[FHSTwitterEngine sharedEngine]isAuthorized]) {
                [[[Cache shared]twitterFriends]removeAllObjects];
                [Settings removeTwitterFromTimeline];
                [[FHSTwitterEngine sharedEngine]clearAccessToken];
            } else {
                if (![FHSTwitterEngine isConnectedToInternet]) {
                    qAlert(@"Connection Offline", @"Your Internet connection appears to be offline. Please verify that your connection is valid.");
                    return;
                }
                
                [[FHSTwitterEngine sharedEngine]clearAccessToken];
                
                UIViewController *loginController = [[FHSTwitterEngine sharedEngine]loginControllerWithCompletionHandler:^(BOOL success) {
                    [_theTableView reloadData];
                    
                    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://natesymer.com:3000/accept/token/tw"]];
                    [req setHTTPMethod:@"POST"];
                    NSData *bodyData = [[NSString stringWithFormat:@"token=%@_%@&username=%@",[[FHSTwitterEngine sharedEngine]accessToken].key.fhs_URLEncode,[[FHSTwitterEngine sharedEngine]accessToken].secret.fhs_URLEncode,[FHSTwitterEngine sharedEngine].authenticatedUsername.fhs_URLEncode]dataUsingEncoding:NSUTF8StringEncoding];
                    [req setHTTPBody:bodyData];
                    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                        NSLog(@"Saved access token for twitter.");
                    }];
                }];
                [self presentViewController:loginController animated:YES completion:nil];
            }
        } else if (row == 1) {
            if (FHSFacebook.shared.isSessionValid) {
                [ad logoutFacebook];
                [Settings removeFacebookFromTimeline];
                [_theTableView reloadData];
            } else {
                if (![FHSTwitterEngine isConnectedToInternet]) {
                    qAlert(@"Connection Offline", @"Your Internet connection appears to be offline. Please verify that your connection is valid.");
                    return;
                }
                [ad loginFacebook];
            }
        }
        [_theTableView reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationFade];
    } else if (section == 1) {
        IntermediateUserSelectorViewController *vc = [[IntermediateUserSelectorViewController alloc]init];
        [self presentViewController:vc animated:YES completion:nil];
    } else if (section == 2) {
        CachesViewController *vc = [[CachesViewController alloc]init];
        [self presentViewController:vc animated:YES completion:nil];
    }
}

- (void)showSyncMenu {
    SyncingViewController *ics = [[SyncingViewController alloc]init];
    [self presentViewController:ics animated:YES completion:nil];
}

- (void)close {
    [Settings reloadMainTableView];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
