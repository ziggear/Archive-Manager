//
//  LzmaPort.m
//  lzma_test2
//
//  Created by ziggear on 13-5-27.
//  Copyright (c) 2013年 ziggear. All rights reserved.
//

#import "LzmaPort.h"
#import "Extractor7z.h"

#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Alloc.h"
#include "7zFile.h"
#include "7zVersion.h"
#include "LzmaDec.h"
#include "LzmaEnc.h"

const char *kCantReadMessage = "Can not read input file";
const char *kCantWriteMessage = "Can not write output file";
const char *kCantAllocateMessage = "Can not allocate memory";
const char *kDataErrorMessage = "Data error";

static void *SzAlloc(void *p, size_t size) { p = p; return MyAlloc(size); }
static void SzFree(void *p, void *address) { p = p; MyFree(address); }
static ISzAlloc g_Alloc = { SzAlloc, SzFree };

void PrintHelp(char *buffer)
{
    strcat(buffer, "\nLZMA Utility " MY_VERSION_COPYRIGHT_DATE "\n"
           "\nUsage:  lzma <e|d> inputFile outputFile\n"
           "  e: encode file\n"
           "  d: decode file\n");
}

int PrintError(char *buffer, const char *message)
{
    NSLog(@"Error: %s",message);
    return 1;
}

int PrintErrorNumber(char *buffer, SRes val)
{
    NSLog(@"Error code: %x, %s", (unsigned)val, buffer);
    return 1;
}

int PrintUserError(char *buffer)
{
    return PrintError(buffer, "Incorrect command");
}

#define IN_BUF_SIZE (1 << 16)
#define OUT_BUF_SIZE (1 << 16)

static SRes Decode2(CLzmaDec *state, ISeqOutStream *outStream, ISeqInStream *inStream,
                    UInt64 unpackSize)
{
    int thereIsSize = (unpackSize != (UInt64)(Int64)-1);
    Byte inBuf[IN_BUF_SIZE];
    Byte outBuf[OUT_BUF_SIZE];
    size_t inPos = 0, inSize = 0, outPos = 0;
    LzmaDec_Init(state);
    for (;;)
    {
        if (inPos == inSize)
        {
            inSize = IN_BUF_SIZE;
            RINOK(inStream->Read(inStream, inBuf, &inSize));
            inPos = 0;
        }
        {
            SRes res;
            SizeT inProcessed = inSize - inPos;
            SizeT outProcessed = OUT_BUF_SIZE - outPos;
            ELzmaFinishMode finishMode = LZMA_FINISH_ANY;
            ELzmaStatus status;
            if (thereIsSize && outProcessed > unpackSize)
            {
                outProcessed = (SizeT)unpackSize;
                finishMode = LZMA_FINISH_END;
            }
            
            res = LzmaDec_DecodeToBuf(state, outBuf + outPos, &outProcessed,
                                      inBuf + inPos, &inProcessed, finishMode, &status);
            inPos += inProcessed;
            outPos += outProcessed;
            unpackSize -= outProcessed;
            
            if (outStream)
                if (outStream->Write(outStream, outBuf, outPos) != outPos)
                    return SZ_ERROR_WRITE;
            
            outPos = 0;
            
            if (res != SZ_OK || thereIsSize && unpackSize == 0)
                return res;
            
            if (inProcessed == 0 && outProcessed == 0)
            {
                if (thereIsSize || status != LZMA_STATUS_FINISHED_WITH_MARK)
                    return SZ_ERROR_DATA;
                return res;
            }
        }
    }
}

static SRes Decode(ISeqOutStream *outStream, ISeqInStream *inStream)
{
    UInt64 unpackSize;
    int i;
    SRes res = 0;
    
    CLzmaDec state;
    
    /* header: 5 bytes of LZMA properties and 8 bytes of uncompressed size */
    unsigned char header[LZMA_PROPS_SIZE + 8];
    
    /* Read and parse header */
    
    RINOK(SeqInStream_Read(inStream, header, sizeof(header)));
    
    unpackSize = 0;
    for (i = 0; i < 8; i++)
        unpackSize += (UInt64)header[LZMA_PROPS_SIZE + i] << (i * 8);
    
    LzmaDec_Construct(&state);
    RINOK(LzmaDec_Allocate(&state, header, LZMA_PROPS_SIZE, &g_Alloc));
    res = Decode2(&state, outStream, inStream, unpackSize);
    LzmaDec_Free(&state, &g_Alloc);
    return res;
}

static SRes Encode(ISeqOutStream *outStream, ISeqInStream *inStream, UInt64 fileSize, char *rs)
{
    CLzmaEncHandle enc;
    SRes res;
    CLzmaEncProps props;
    
    rs = rs;
    
    enc = LzmaEnc_Create(&g_Alloc);
    if (enc == 0)
        return SZ_ERROR_MEM;
    
    LzmaEncProps_Init(&props);
    res = LzmaEnc_SetProps(enc, &props);
    
    if (res == SZ_OK)
    {
        Byte header[LZMA_PROPS_SIZE + 8];
        size_t headerSize = LZMA_PROPS_SIZE;
        int i;
        
        res = LzmaEnc_WriteProperties(enc, header, &headerSize);
        for (i = 0; i < 8; i++)
            header[headerSize++] = (Byte)(fileSize >> (8 * i));
        if (outStream->Write(outStream, header, headerSize) != headerSize)
            res = SZ_ERROR_WRITE;
        else
        {
            if (res == SZ_OK)
                res = LzmaEnc_Encode(enc, outStream, inStream, NULL, &g_Alloc, &g_Alloc);
        }
    }
    LzmaEnc_Destroy(enc, &g_Alloc, &g_Alloc);
    return res;
}


@implementation LzmaPort

//lifecycle

- (id) init {
    self = [super init];
    if(self){
        
    }
    return self;
}

+ (id)share { 
    static id sharedManager = nil;
    if (self == [LzmaPort class]) {
        sharedManager = [[LzmaPort alloc] init];
    }
    return sharedManager;
}

//encoding & decoding

- (void)LzEncodeWithFile:(NSString *)file {
    [self LzmaWithFile:file oFile:[NSString stringWithFormat:@"%@.lzma",file] encodeMode:@"e"];
}

- (void)LzDecodeWithFile:(NSString *)file {
    NSString *outName = nil;
    if([file hasSuffix:@".lzma"]){
        NSRange range = NSMakeRange(0, [file length] - 5);
        outName = [file substringWithRange:range];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",[self getDocumentPath],outName]]) {
            outName = [NSString stringWithFormat:@"%@.out",file];
        }
        
    } else {
        outName = [NSString stringWithFormat:@"%@.out",file];
    }
    
    [self LzmaWithFile:file oFile:outName encodeMode:@"d"];
}

- (void)Extract7zWithFile:(NSString *)file {
    [Extractor7z extract7zArchive:[NSString stringWithFormat:@"%@/%@",[self getDocumentPath],file] tmpDirName:@"Extract"];
}

//private methods
- (int) LzmaWithFile:(NSString *)ifile oFile:(NSString *)ofile encodeMode:(NSString *)mode
{
    
    NSString *doc = [self getDocumentPath];
    NSString *infile = [NSString stringWithFormat:@"%@/%@",doc,ifile];
    NSString *outfile = [NSString stringWithFormat:@"%@/%@",doc,ofile];
    
    int numArgs = 4;
    char *args[5];
    
    args[1]=(char *)"";
    args[2]=(char *)[infile cStringUsingEncoding:NSASCIIStringEncoding];
    args[3]=(char *)[outfile cStringUsingEncoding:NSASCIIStringEncoding];
    
    char rs[800] = { 0 };
    
    CFileSeqInStream inStream;
    CFileOutStream outStream;
    char c;
    int res;
    int encodeMode;
    Bool useOutFile = False;
    
    FileSeqInStream_CreateVTable(&inStream);
    File_Construct(&inStream.file);
    
    FileOutStream_CreateVTable(&outStream);
    File_Construct(&outStream.file);
    
    if([mode isEqualToString:@"e"]) {
        numArgs = 4;
        c = 'e';
    }
    
    if([mode isEqualToString:@"d"]) {
        numArgs = 4;
        c = 'd';
    }
    
    encodeMode = (c == 'e' || c == 'E');
    if (!encodeMode && c != 'd' && c != 'D')
        return PrintUserError(rs);
    {
        size_t t4 = sizeof(UInt32);
        size_t t8 = sizeof(UInt64);
        if (t4 != 4 || t8 != 8)
            return PrintError(rs, "Incorrect UInt32 or UInt64");
    }
    
    if (InFile_Open(&inStream.file, args[2]) != 0)
        return PrintError(rs, "Can not open input file");
    
    if (numArgs > 3)
    {
        useOutFile = True;
        if (OutFile_Open(&outStream.file, args[3]) != 0)
            return PrintError(rs, "Can not open output file");
    }
    else if (encodeMode)
        PrintUserError(rs);
    
    if (encodeMode)
    {
        UInt64 fileSize;
        File_GetLength(&inStream.file, &fileSize);
        res = Encode(&outStream.s, &inStream.s, fileSize, rs);
    }
    else
    {
        res = Decode(&outStream.s, useOutFile ? &inStream.s : NULL);
        //res = Decode(&outStream.s,NULL);
    }
    
    if (useOutFile)
        File_Close(&outStream.file);
    File_Close(&inStream.file);
    
    if (res != SZ_OK)
    {
        if (res == SZ_ERROR_MEM)
            return PrintError(rs, kCantAllocateMessage);
        else if (res == SZ_ERROR_DATA)
            return PrintError(rs, kDataErrorMessage);
        else if (res == SZ_ERROR_WRITE)
            return PrintError(rs, kCantWriteMessage);
        else if (res == SZ_ERROR_READ)
            return PrintError(rs, kCantReadMessage);
        return PrintErrorNumber(rs, res);
    }
    return 0;
}

-(NSString *)getDocumentPath{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

@end

