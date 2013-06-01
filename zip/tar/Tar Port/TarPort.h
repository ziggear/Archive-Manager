//
//  TarMan.h
//  TarTool
//
//  Created by ziggear on 13-5-29.
//  Copyright (c) 2013年 ziggear. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kTarTypeNormal,
    kTarTypeGzip,
    kTarTypeBZip2
}kTarType;

@interface TarPort : NSObject
+(int)tarWithType:(kTarType)type andFile:(NSString *)file;
+(int)unTarWithType:(kTarType)type andFile:(NSString *)file;
@end
