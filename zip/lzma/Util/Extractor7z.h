//
//  Extractor7z.h
//  lzma_test2
//
//  Created by ziggear on 13-5-27.
//  Copyright (c) 2013年 ziggear. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Extractor7z : NSObject {
}

// Extract all the contents of a .7z archive into the indicated temp dir
// and return an array of the fully qualified filenames.

+ (NSArray*) extract7zArchive:(NSString*)archivePath
                   tmpDirName:(NSString*)tmpDirName;

// Extract just one entry from an archive and save it at the
// path indicated by outPath.

+ (BOOL) extractArchiveEntry:(NSString*)archivePath
                archiveEntry:(NSString*)archiveEntry
                     outPath:(NSString*)outPath;

@end

