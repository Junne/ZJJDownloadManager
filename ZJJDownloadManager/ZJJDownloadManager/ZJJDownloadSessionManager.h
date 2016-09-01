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

@property (nonatomic, weak) id<ZJJDownloadDelegate> delegate;


+ (ZJJDownloadSessionManager *)sharedManager;

- (void)setupBackgroundConfigureSession;

- (void)cancelBackgroundSessionTasks;

- (void)resumeDownloadModel:(ZJJDownloadSessionModel *)downloadModel;



- (ZJJDownloadSessionModel *)startDownloadWithURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(ZJJDownloadProgressBlock)downloadProgress state:(ZJJDownloadStateBlock)state;

- (void)startDownloadModel:(ZJJDownloadSessionModel *)downloadModel;

- (void)startDownloadModel:(ZJJDownloadSessionModel *)downloadModel progress:(ZJJDownloadProgressBlock)downloadProgress state:(ZJJDownloadStateBlock)state;



@end
