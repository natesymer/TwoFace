//
//  Reply View Controller.m
//  TwoFace
//
//  Created by Nathaniel Symer on 6/6/12.
//  Copyright (c) 2012 Nathaniel Symer. All rights reserved.
//

#import "ReplyViewController.h"
#import "FHSTwitterEngine.h"

@implementation ReplyViewController

- (void)saveToID:(NSNotification *)notif {
    self.toID = notif.object;
    _navBar.topItem.title = [NSString stringWithFormat:@"To %@",[[[Cache.shared nameForFacebookID:_toID]componentsSeparatedByString:@" "]firstObject]];
}

- (void)loadView {
    [super loadView];
    CGRect screenBounds = [[UIScreen mainScreen]applicationFrame];
    self.view = [[UIView alloc]initWithFrame:screenBounds];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    self.navBar = [[UINavigationBar alloc]initWithFrame:CGRectMake(0, 0, screenBounds.size.width, 44)];
    UINavigationItem *topItem = [[UINavigationItem alloc]initWithTitle:@"Compose Tweet"];
    topItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:self action:@selector(close)];
    topItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Post" style:UIBarButtonItemStyleDone target:self action:@selector(sendReply)];
    [self.navBar pushNavigationItem:topItem animated:NO];
    [self.view addSubview:self.navBar];
    
    self.replyZone = [[UITextView alloc]initWithFrame:CGRectMake(0, _navBar.frame.size.height, screenBounds.size.width, screenBounds.size.height-_navBar.frame.size.height)];
    _replyZone.backgroundColor = [UIColor whiteColor];
    _replyZone.editable = YES;
    _replyZone.clipsToBounds = NO;
    _replyZone.font = [UIFont systemFontOfSize:14];
    _replyZone.delegate = self;
    _replyZone.text = @"";
    [self.view addSubview:_replyZone];
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(loadDraft:) name:@"draft" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(saveToID:) name:@"passFriendID" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    self.bar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 44)];
    
    UIBarButtonItem *space = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    space.width = 5;
    
    self.bar.items = @[[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemCamera target:self action:@selector(showImageSelector)], space, [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(showDraftsBrowser)]];
    
    if (!self.isFacebook) {
        self.charactersLeft = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 310, 44)];
        _charactersLeft.font = [UIFont boldSystemFontOfSize:20];
        _charactersLeft.textAlignment = UITextAlignmentRight;
        _charactersLeft.textColor = [UIColor blackColor];
        _charactersLeft.backgroundColor = [UIColor clearColor];
        [_bar addSubview:_charactersLeft];
    }
    
    _replyZone.inputAccessoryView = _bar;

    if (_tweet) {
        _replyZone.text = [NSString stringWithFormat:@"@%@ ",_tweet.user.screename];
        _navBar.topItem.title = @"Reply";
    }
    
    if (_isFacebook) {
        _navBar.topItem.title = @"Compose Status";
    }
    
    [_replyZone becomeFirstResponder];
    [self refreshCounter];
}

- (void)scaleImageFromCameraRoll {
    if (self.imageFromCameraRoll.size.width > 768 && self.imageFromCameraRoll.size.height > 768) {
        float ratio = MIN(768/self.imageFromCameraRoll.size.width, 768/self.imageFromCameraRoll.size.height);
        self.imageFromCameraRoll = [self.imageFromCameraRoll scaleToSize:CGSizeMake(ratio*self.imageFromCameraRoll.size.width, ratio*self.imageFromCameraRoll.size.height)];
    }
}

- (void)kickoffTweetPost {
    NSString *messageBody = [_replyZone.text stringByTrimmingWhitespace];
    [Settings showHUDWithTitle:@"Tweeting..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            NSError *error = nil;
            
            if (self.tweet) {
                error = [[FHSTwitterEngine sharedEngine]postTweet:messageBody inReplyTo:_tweet.identifier];
            } else {
                error = [[FHSTwitterEngine sharedEngine]postTweet:messageBody];
            }
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                [self dismissModalViewControllerAnimated:YES];
                
                if (error) {
                    qAlert([NSString stringWithFormat:@"Error %d",error.code], error.domain);
                    [self saveDraft];
                } else {
                    [self deletePostedDraft];
                }
            });
        }
    });
}

- (void)showImageSelector {
    [self.replyZone resignFirstResponder];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        UIActionSheet *as = [[UIActionSheet alloc]initWithTitle:nil completionBlock:^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
            
            UIImagePickerController *imagePicker = [[UIImagePickerController alloc]init];
            imagePicker.delegate = self;
            
            if (buttonIndex == 0) {
                [imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
                [self presentModalViewController:imagePicker animated:YES];
            } else if (buttonIndex == 1) {
                [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
                [self presentModalViewController:imagePicker animated:YES];
            } else {
                [self.replyZone becomeFirstResponder];
            }
            
        } cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Take Photo", @"Choose from Library...", nil];
        as.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
        [as showInView:self.view];
    } else {
        UIImagePickerController *imagePicker = [[UIImagePickerController alloc]init];
        [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        imagePicker.delegate = self;
        [self.replyZone resignFirstResponder];
        [self presentModalViewController:imagePicker animated:YES];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    [self dismissModalViewControllerAnimated:YES];
    
    self.imageFromCameraRoll = info[UIImagePickerControllerOriginalImage];
    [self scaleImageFromCameraRoll];
    
    NSMutableArray *toolbarItems = [self.bar.items mutableCopy];
    
    for (UIBarButtonItem *item in [toolbarItems mutableCopy]) {
        if (item.customView) {
            if ([toolbarItems containsObject:item]) {
                [toolbarItems removeObject:item];
            }
        }
    }
    self.bar.items = toolbarItems;
    
    [self addImageToolbarItems];
    [self.replyZone becomeFirstResponder];
}

- (void)imageTouched {
    
    [self.replyZone resignFirstResponder];
    
    UIActionSheet *as = [[UIActionSheet alloc]initWithTitle:nil completionBlock:^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == 1) {
            ImageDetailViewController *idvc = [[ImageDetailViewController alloc]initWithImage:self.imageFromCameraRoll];
            idvc.shouldShowSaveButton = NO;
            [self presentModalViewController:idvc animated:YES];
        } else {
            [self.replyZone becomeFirstResponder];
        }

        if (buttonIndex == 0) {
            self.imageFromCameraRoll = nil;

            NSMutableArray *toolbarItems = [self.bar.items mutableCopy];
            [toolbarItems removeLastObject];
            [toolbarItems removeLastObject];
            self.bar.items = toolbarItems;
            
            self.isLoadedDraft = NO;
        }
        
        [self refreshCounter];
        
    } cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Remove Image" otherButtonTitles:@"View Image...", nil];
    as.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    [as showInView:self.view];
}

- (void)addImageToolbarItems {
    self.isLoadedDraft = NO;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *imageToBeSet = [self.imageFromCameraRoll scaleProportionallyToSize:CGSizeMake(36, 36)];
    [button setImage:imageToBeSet forState:UIControlStateNormal];
    button.frame = CGRectMake(274, 4, imageToBeSet.size.width, imageToBeSet.size.height);
    button.layer.cornerRadius = 5.0;
    button.layer.masksToBounds = YES;
    button.layer.borderColor = [UIColor darkGrayColor].CGColor;
    button.layer.borderWidth = 1.0;
    [button addTarget:self action:@selector(imageTouched) forControlEvents:UIControlEventTouchUpInside];

    NSMutableArray *newItems = [self.bar.items mutableCopy];
    
    UIBarButtonItem *bbiz = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    bbiz.width = 5;
    
    [newItems addObject:bbiz];
    [newItems addObject:[[UIBarButtonItem alloc]initWithCustomView:button]];
    self.bar.items = newItems;
    [self refreshCounter];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissModalViewControllerAnimated:YES];
    [self.replyZone becomeFirstResponder];
}

- (instancetype)initWithToID:(NSString *)toId {
    self = [super init];
    if (self) {
        self.toID = toId;
        self.isFacebook = YES;
    }
    return self;
}

- (id)initWithTweet:(Tweet *)aTweet {
    self = [super init];
    if (self) {
        self.isFacebook = NO;
        self.tweet = aTweet;
    }
    return self;
}

- (void)refreshCounter {
    int charsLeft = 140-(self.imageFromCameraRoll?self.replyZone.text.length+20:self.replyZone.text.length);
    
    self.charactersLeft.text = [NSString stringWithFormat:@"%d",charsLeft];
    
    if (charsLeft < 0) {
        self.charactersLeft.textColor = [UIColor redColor];
        self.navBar.topItem.rightBarButtonItem.enabled = NO;
    } else if (charsLeft == 140) {
        self.navBar.topItem.rightBarButtonItem.enabled = NO;
    } else {
        self.charactersLeft.textColor = [UIColor whiteColor];
        self.navBar.topItem.rightBarButtonItem.enabled = YES;
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    [self refreshCounter];
    self.isLoadedDraft = NO;
}

- (void)keyboardWillShow:(NSNotification *)notification {
    [self moveTextViewForKeyboard:notification up:YES];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self moveTextViewForKeyboard:notification up:NO];
}

- (void)moveTextViewForKeyboard:(NSNotification *)notification up:(BOOL)up {
    UIViewAnimationCurve animationCurve;

    [[notification userInfo][UIKeyboardAnimationCurveUserInfoKey]getValue:&animationCurve];
    NSTimeInterval animationDuration = [[notification userInfo][UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGRect keyboardRect = [self.view convertRect:[[notification userInfo][UIKeyboardFrameEndUserInfoKey]CGRectValue] fromView:nil];
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:animationDuration];
    [UIView setAnimationCurve:animationCurve];
    
    if (up) {
        CGRect newTextViewFrame = self.replyZone.frame;
        self.originalTextViewFrame = self.replyZone.frame;
        newTextViewFrame.size.height = keyboardRect.origin.y-self.replyZone.frame.origin.y;
        self.replyZone.frame = newTextViewFrame;
    } else {
        self.replyZone.frame = self.originalTextViewFrame;
    }
    
    [UIView commitAnimations];
}

- (void)dismissModalViewControllerAnimated:(BOOL)animated {
    [self purgeDraftImages];
    [Settings hideHUD];
    [self removeObservers];
    [super dismissModalViewControllerAnimated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.replyZone resignFirstResponder];
    [super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.replyZone becomeFirstResponder];
    [super viewWillAppear:animated];
}

- (void)deletePostedDraft {
    NSMutableArray *drafts = [Settings drafts];
    
    if ([drafts containsObject:_loadedDraft]) {
        [[NSFileManager defaultManager]removeItemAtPath:_loadedDraft[@"thumbnailImagePath"] error:nil];
        [[NSFileManager defaultManager]removeItemAtPath:_loadedDraft[@"imagePath"] error:nil];
        [drafts removeObject:_loadedDraft];
        [drafts writeToFile:[Settings draftsPath] atomically:YES];
    }
}

- (void)purgeDraftImages {
    NSString *imageDir = [[Settings documentsDirectory]stringByAppendingPathComponent:@"draftImages"];
    NSMutableArray *drafts = [Settings drafts];
    
    NSMutableArray *imagesToKeep = [NSMutableArray array];
    NSMutableArray *allFiles = [NSMutableArray arrayWithArray:[[NSFileManager defaultManager]contentsOfDirectoryAtPath:imageDir error:nil]];
    
    for (NSDictionary *dict in drafts) {
        
        NSString *imageName = [dict[@"imagePath"]lastPathComponent];
        NSString *thumbnailImageName = [dict[@"thumbnailImagePath"]lastPathComponent];

        if (imageName.length > 0) {
            [imagesToKeep addObject:imageName];
        }
        
        if (thumbnailImageName.length > 0) {
            [imagesToKeep addObject:thumbnailImageName];
        }
    }
    
    [allFiles removeObjectsInArray:imagesToKeep];
    
    for (NSString *filename in allFiles) {
        NSString *file = [imageDir stringByAppendingPathComponent:filename];
        [[NSFileManager defaultManager]removeItemAtPath:file error:nil];
    }
}

- (void)saveDraft {
    NSMutableArray *drafts = [Settings drafts];
    
    if (drafts == nil) {
        drafts = [NSMutableArray array];
    }
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    
    NSString *thetoID = _isFacebook?_toID:_loadedDraft[@"toID"];
    
    if (thetoID.length > 0) {
        dict[@"toID"] = thetoID;
    }
    
    if (_replyZone.text.length > 0) {
        dict[@"text"] = _replyZone.text;
    }
    
    if (self.imageFromCameraRoll) {
        NSString *filename = [NSString stringWithFormat:@"%lld.jpg",arc4random()%9999999999999999];
        NSString *path = [[[Settings documentsDirectory]stringByAppendingPathComponent:@"draftImages"]stringByAppendingPathComponent:filename];

        if (![[NSFileManager defaultManager]fileExistsAtPath:[[Settings documentsDirectory]stringByAppendingPathComponent:@"draftImages"] isDirectory:nil]) {
            [[NSFileManager defaultManager]createDirectoryAtPath:[[Settings documentsDirectory]stringByAppendingPathComponent:@"draftImages"] withIntermediateDirectories:NO attributes:nil error:nil];
        }
        
        do {
            filename = [NSString stringWithFormat:@"%lld.jpg",arc4random()%9999999999999999];
            path = [[[Settings documentsDirectory]stringByAppendingPathComponent:@"draftImages"]stringByAppendingPathComponent:filename];
        } while ([[NSFileManager defaultManager]fileExistsAtPath:path]);
        
        [UIImageJPEGRepresentation(self.imageFromCameraRoll, 1.0) writeToFile:path atomically:YES];
        dict[@"imagePath"] = path;
        
        // Thumbnail
        NSString *thumbnailFilename = [path stringByReplacingOccurrencesOfString:@".jpg" withString:@"-thumbnail.jpg"];
        UIImage *thumbnail = [self.imageFromCameraRoll thumbnailImageWithSideOfLength:35];
        
        [UIImageJPEGRepresentation(thumbnail, 1.0) writeToFile:thumbnailFilename atomically:YES];
        dict[@"thumbnailImagePath"] = thumbnailFilename;
    }
    
    if (self.tweet) {
        dict[@"tweet"] = self.tweet;
    }
    
    dict[@"time"] = [NSDate date];
    
    [drafts addObject:dict];
    [drafts writeToFile:[Settings draftsPath] atomically:YES];
}

- (void)loadDraft:(NSNotification *)notif {
    
    self.imageFromCameraRoll = nil;
    NSMutableArray *newItems = [self.bar.items mutableCopy];
    
    if ([(UIBarButtonItem *)[newItems lastObject]customView]) {
        [newItems removeLastObject];
    }
    
    if ([(UIBarButtonItem *)[newItems lastObject]width] == 5) {
        [newItems removeLastObject];
    }
    
    self.bar.items = newItems;
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]initWithDictionary:(NSDictionary *)notif.object];
    self.replyZone.text = dict[@"text"];
    
    self.imageFromCameraRoll = [UIImage imageWithContentsOfFile:dict[@"imagePath"]];
    self.tweet = dict[@"tweet"];
    self.toID = self.isFacebook?dict[@"toID"]:nil;
    
    if (self.imageFromCameraRoll) {
        [self addImageToolbarItems];
    }
    
    if (self.replyZone.text.length == 0 && !self.imageFromCameraRoll) {
        self.navBar.topItem.rightBarButtonItem.enabled = NO;
    } else {
        self.navBar.topItem.rightBarButtonItem.enabled = YES;
    }
    
    self.isLoadedDraft = YES;
    self.loadedDraft = dict;
    [self refreshCounter];
}

- (void)sendReply {
    if (_replyZone.text.length == 0 && _isFacebook) {
        return;
    }

    [_replyZone resignFirstResponder];
    
    if (_isFacebook) {
        [Settings showHUDWithTitle:@"Posting..."];
        
        NSMutableDictionary *params = @{ @"message":_replyZone.text }.mutableCopy;
        
        NSString *graphURL = [NSString stringWithFormat:@"https://graph.facebook.com/%@/%@",(_toID.length == 0)?@"me":_toID, (_imageFromCameraRoll != nil)?@"photos":@"feed"];
        
        if (_imageFromCameraRoll) {
            params[@"source"] = UIImagePNGRepresentation(_imageFromCameraRoll);
        }
        
        NSMutableURLRequest *request = [FHSFacebook.shared generateRequestWithURL:graphURL params:params HTTPMethod:@"POST"];
        
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            [self dismissModalViewControllerAnimated:YES];
            
            if (error) {
                qAlert(@"Status Update Error", (error.localizedDescription.length == 0)?@"Confirm that you are logged in correctly and try again.":error.localizedDescription);
                [self saveDraft];
            } else {
                [self deletePostedDraft];
            }
        }];
        
    } else {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        
        if (self.imageFromCameraRoll) {
            [self scaleImageFromCameraRoll];
            [Settings showHUDWithTitle:@"Uploading..."];
            NSString *message = [self.replyZone.text stringByTrimmingWhitespace];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @autoreleasepool {
                    id returnValue = [[FHSTwitterEngine sharedEngine]uploadImageToTwitPic:UIImageJPEGRepresentation(self.imageFromCameraRoll, 0.8) withMessage:message twitPicAPIKey:@"264b928f14482c7ad2ec20f35f3ead22"];
                    
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        @autoreleasepool {
                            if ([returnValue isKindOfClass:[NSError class]]) {
                                [Settings hideHUD];
                                [self.replyZone becomeFirstResponder];
                                qAlert(@"Image Upload Failed", [NSString stringWithFormat:@"%@",[(NSError *)returnValue localizedDescription]]);
                            } else if ([returnValue isKindOfClass:[NSDictionary class]]) {
                                NSString *link = ((NSDictionary *)returnValue)[@"url"];
                                self.replyZone.text = [[self.replyZone.text stringByTrimmingWhitespace]stringByAppendingFormat:@" %@",link];
                                [self kickoffTweetPost];
                            }
                        }
                    });
                }
            });
        } else {
            [self kickoffTweetPost];
        }
    }
}

- (void)showDraftsBrowser {
    
    [self.replyZone resignFirstResponder];
    
    void (^completionHandler)(NSUInteger, UIActionSheet *) = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        
        if (buttonIndex == 0) {
            DraftsViewController *vc = [[DraftsViewController alloc]init];
            [self presentModalViewController:vc animated:YES];
        } else if (buttonIndex == 1) {
            if (self.isFacebook) {
                UserSelectorViewController *vc = [[UserSelectorViewController alloc]initWithIsFacebook:YES isImmediateSelection:YES];
                [self presentModalViewController:vc animated:YES];
            } else {
                [self.replyZone becomeFirstResponder];
            }
        } else {
            [self.replyZone becomeFirstResponder];
        }
    };
    
    UIActionSheet *as = nil;
    
    if (self.isFacebook) {
        as = [[UIActionSheet alloc]initWithTitle:nil completionBlock:completionHandler cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Load Draft...", @"Post on Friend's Wall", nil];
    } else {
        as = [[UIActionSheet alloc]initWithTitle:nil completionBlock:completionHandler cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Load Draft...", nil];
    }
    
    as.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    [as showInView:self.view];
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter]removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:@"draft" object:nil];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:@"passFriendID" object:nil];
}

- (void)close {
    [self.replyZone resignFirstResponder];
    
    if (self.isLoadedDraft && [[Settings drafts]containsObject:_loadedDraft]) {
        [self dismissModalViewControllerAnimated:YES];
        return;
    }

    BOOL isJustMention = ([self.replyZone.text componentsSeparatedByString:@" "].count == 1) && (self.replyZone.text.length > 0)?[[self.replyZone.text substringToIndex:1]isEqualToString:@"@"]:NO;
    
    if (any(self.imageFromCameraRoll != nil, (self.replyZone.text.length > 0 && !isJustMention))) {
        UIActionSheet *as = [[UIActionSheet alloc]initWithTitle:nil completionBlock:^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
            
            if (buttonIndex == 1) {
                [self saveDraft];
                [self dismissModalViewControllerAnimated:YES];
            } else if (buttonIndex == 0) {
                [self dismissModalViewControllerAnimated:YES];
            } else {
                [self.replyZone becomeFirstResponder];
            }
                             
        } cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles:@"Save as Draft", nil];
        as.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
        [as showInView:self.view];
    } else {
        [self dismissModalViewControllerAnimated:YES];
    }
}

@end
