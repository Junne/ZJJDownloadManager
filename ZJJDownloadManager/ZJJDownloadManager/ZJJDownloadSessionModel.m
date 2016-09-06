//
//  ZJJDownloadSessionModel.m
//  ZJJDownloadManager
//
//  Created by baijf on 8/31/16.
//  Copyright © 2016 Junne. All rights reserved.
//

#import "ZJJDownloadSessionModel.h"


@interface ZJJDownloadSessionModel ()

@property (nonatomic, strong) NSString *downloadURL;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *downloadPath;
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSDate   *downloadDate;
@property (nonatomic, assign) ZJJDownloadState downloadState;
@property (nonatomic, strong) NSURLSessionDownloadTask *sessionTask;

@end

@interface ZJJDownloadProgress ()

@property (nonatomic, assign) int64_t fileOffset;
@property (nonatomic, assign) int64_t bytesWritten;
@property (nonatomic, assign) int64_t totalBytesWritten;
@property (nonatomic, assign) int64_t totalBytesExpectedToWrite;
@property (nonatomic, assign) float progress;
@property (nonatomic, assign) float speed;
@property (nonatomic, assign) int remainTime;

@end

@implementation ZJJDownloadSessionModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _progress = [[ZJJDownloadProgress alloc] init];
    }
    return self;
}

- (instancetype)initWithDownloadURLString:(NSString *)URLString
{
    return [self initWithDownLoadURLString:URLString filePath:nil];
}

- (instancetype)initWithDownLoadURLString:(NSString *)URLString filePath:(NSString *)filePath
{
    self = [super init];
    if (self) {
        _downloadURL  = URLString;
        _fileName     = filePath.lastPathComponent;
        _downloadPath = filePath.stringByDeletingLastPathComponent;
        _filePath     = filePath;
    }
    return self;
}

- (NSString *)fileName
{
    if (!_fileName) {
        _fileName = _downloadURL.lastPathComponent;
    }
    return _fileName;
}

- (NSString *)downloadPath
{
    if (_downloadPath) {
        _downloadPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"ZJJDownloadCache"];
    }
    return _downloadPath;
}

- (NSString *)filePath
{
    if (_filePath) {
        _filePath = [self.downloadPath stringByAppendingPathComponent:_fileName];
    }
    return _filePath;
}

@end


@implementation ZJJDownloadProgress



@end
