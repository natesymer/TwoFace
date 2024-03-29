//
//  NSArray+RemoveDuplicates.h
//  TwoFace
//
//  Created by Nathaniel Symer on 10/7/12.
//  Copyright (c) 2012 Nathaniel Symer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray (removeDuplicates)

- (void)removeDuplicates;

@end

@interface NSArray (arrayByRemovingDuplicates)

- (NSArray *)arrayByRemovingDuplicates;

@end
