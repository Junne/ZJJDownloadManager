//
//  ZJJDownloadSessionManager.h
//  ZJJDownloadManager
//
//  Created by baijf on 8/31/16.
//  Copyright © 2016 Junne. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZJJDownloadSessionModel.h"


@protocol ZJJDownloadDelegate <NSObject>

- (void)downloadModel:(ZJJDownloadSessionModel *)downloadModel updateProgress:(ZJJDownloadProgress *)progress;

- (void)downloadModel:(ZJJDownloadSessionModel *)downloadModel changeState:(ZJJDownloadState)state filePath:(NSString *)filePath error:(NSError *)error;

@end

@interface ZJJDownloadSessionManager : NSObject<NSURLSessionDownloadDelegate>


@property (nonatomic, strong) NSString *backgroundConfigure;
@property (nonatomic, assign) NSInteger maxDownloadCount;
@property (nonatomic, assign) BOOL isBatchDownload;

@property (nonatomic, copy) void (^backgroundSessionCompletionHandler)();

@property (nonatomic, copy) NSString *(^backgroundSessionDownloadCompletedBlock)(NSString *downloadURL);

@property (nonatomic, weak) id<ZJJDownloadDelegate> delegate;


+ (ZJJDownloadSessionManager *)sharedManager;

- (void)setupBackgroundConfigureSession;

- (void)cancelBackgroundSessionTasks;

- (void)suspendDownloadModel:(ZJJDownloadSessionModel *)downloadModel;

- (void)resumeDownloadModel:(ZJJDownloadSessionModel *)downloadModel;

- (void)cancelFileDownloadModel:(ZJJDownloadSessionModel *)downloadModel;

- (void)deleteFileDownload:(ZJJDownloadSessionModel *)downloadModel;

- (void)deleteAllFiledWithDownloadDirectory:(NSString *)downloadDirectory;

- (ZJJDownloadSessionModel *)startDownloadWithURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(ZJJDownloadProgressBlock)downloadProgress state:(ZJJDownloadStateBlock)state;

- (void)startDownloadModel:(ZJJDownloadSessionModel *)downloadModel;

- (void)startDownloadModel:(ZJJDownloadSessionModel *)downloadModel progress:(ZJJDownloadProgressBlock)downloadProgress state:(ZJJDownloadStateBlock)state;



@end
