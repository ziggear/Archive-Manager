//
//  LzmaPort.h
//  lzma_test2
//
//  Created by ziggear on 13-5-27.
//  Copyright (c) 2013年 ziggear. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LzmaPort : NSObject
+(id)share;
- (void)LzEncodeWithFile:(NSString *)file;
- (void)LzDecodeWithFile:(NSString *)file;
- (void)Extract7zWithFile:(NSString *)file;
@end
