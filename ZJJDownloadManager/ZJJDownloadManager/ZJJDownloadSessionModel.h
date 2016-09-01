//
//  ZJJDownloadSessionModel.h
//  ZJJDownloadManager
//
//  Created by baijf on 8/31/16.
//  Copyright © 2016 Junne. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, ZJJDownloadState) {
    ZJJDownloadStateNone,
    ZJJDownloadStateReady,
    ZJJDownloadStateInProgress,
    ZJJDownloadStatePause,
    ZJJDownloadStateCompleted,
    ZJJDownloadStateFailed
};

@class ZJJDownloadProgress;

typedef void (^ZJJDownloadProgressBlock)(ZJJDownloadProgress *progress);
typedef void (^ZJJDownloadStateBlock)(ZJJDownloadState state, NSString *filePath, NSError *error);

@interface ZJJDownloadSessionModel : NSObject

@property (nonatomic, strong, readonly) NSString *downloadURL;
@property (nonatomic, strong, readonly) NSString *fileName;
@property (nonatomic, strong, readonly) NSString *downloadPath;
@property (nonatomic, strong, readonly) NSString *filePath;
@property (nonatomic, strong, readonly) NSURLSessionDownloadTask *sessionTask;
@property (nonatomic, assign, readonly) ZJJDownloadState state;
@property (nonatomic, strong, readonly) ZJJDownloadProgress *progress;
@property (nonatomic, copy) ZJJDownloadProgressBlock progressBlock;
@property (nonatomic, copy) ZJJDownloadStateBlock stateBlock;

- (instancetype)initWithDownloadURLString:(NSString *)URLString;

- (instancetype)initWithDownLoadURLString:(NSString *)URLString filePath:(NSString *)filePath;


@end


@interface ZJJDownloadProgress : NSObject

@property (nonatomic, assign, readonly) int64_t fileOffset;
@property (nonatomic, assign, readonly) int64_t bytesWritten;
@property (nonatomic, assign, readonly) int64_t totalBytesWritten;
@property (nonatomic, assign, readonly) int64_t totalBytesExpectedToWrite;
@property (nonatomic, assign, readonly) float progress;
@property (nonatomic, assign, readonly) float speed;


@end
