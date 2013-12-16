//
//  Cache.h
//  TwoFace
//
//  Created by Nathaniel Symer on 6/5/13.
//  Copyright (c) 2013 Nathaniel Symer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Cache : NSObject

@property (nonatomic, strong) NSMutableArray *timeline;
@property (nonatomic, strong) NSMutableArray *nonTimelineTweets;

- (void)cache;

- (void)sortTimeline;

+ (Cache *)shared;

+ (void)clearImageCache;
+ (UIImage *)imageFromCache:(NSString *)imageName;
+ (void)setImage:(UIImage *)image forName:(NSString *)name;

- (void)clearImageURLCache;
- (void)setImageURL:(NSString *)imageURL forLinkURL:(NSString *)linkURL;
- (NSString *)getImageURLForLinkURL:(NSString *)linkURL;

- (NSMutableDictionary *)twitterFriendsFromCache;
- (void)cacheTwitterFriendsDict:(NSMutableDictionary *)dict;

- (NSMutableDictionary *)facebookFriendsFromCache:(NSMutableArray **)array;
- (void)cacheFacebookDicts:(NSArray *)array;
- (NSString *)nameForFacebookID:(NSString *)uid;

@end
