//
//  DraftsViewController.h
//  TwoFace
//
//  Created by Nathaniel Symer on 10/9/12.
//  Copyright (c) 2012 Nathaniel Symer. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DraftsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) UITableView *theTableView;

@end
