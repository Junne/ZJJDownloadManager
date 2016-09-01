//
//  ZJJDownloadSessionManager.m
//  ZJJDownloadManager
//
//  Created by baijf on 8/31/16.
//  Copyright © 2016 Junne. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZJJDownloadSessionManager.h"


@interface ZJJDownloadSessionManager ()

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSString *downloadPath;
@property (nonatomic, strong) NSFileManager *fileManager;

@property (nonatomic, strong) NSMutableDictionary *downloadModelDictionary;
@property (nonatomic, strong) NSMutableArray *waitingDownloadModels;
@property (nonatomic, strong) NSMutableArray *downloadingModels;


@end

@interface ZJJDownloadSessionModel ()

@property (nonatomic, assign) ZJJDownloadState state;
@property (nonatomic, strong) NSURLSessionDownloadTask *sessionTask;
@property (nonatomic, strong) NSData *resumeData;


@end

@implementation ZJJDownloadSessionManager

+ (ZJJDownloadSessionManager *)sharedManager
{
    static ZJJDownloadSessionManager *service = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[ZJJDownloadSessionManager alloc] init];
    });
    return service;
}

- (instancetype)init
{
    self =  [super init];
    if (self) {
        _backgroundConfigure = @"ZJJDownloadSessionManager.backgroundConfigure";
        _maxDownloadCount = 1;
        _isBatchDownload = NO;
    }
    return self;
}

- (void)setupBackgroundConfigureSession
{
    if (!_backgroundConfigure) {
        return;
    }
    [self session];
}

- (void)cancelBackgroundSessionTasks
{
    if (!_backgroundConfigure) {
        return;
    }
    
    for(NSURLSessionDownloadTask *task in [self sessionDownloadTasks]) {
        [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            
        }];
    }
}


- (void)resumeDownloadModel:(ZJJDownloadSessionModel *)downloadModel
{
    if (!downloadModel) {
        return;
    }
    
    if (![self canResumeDownloadModel:downloadModel]) {
        return;
    }
    
    if (!downloadModel.sessionTask || downloadModel.sessionTask.state == NSURLSessionTaskStateCanceling) {
//        NSData *resumeData = [self resu]
    }
}





- (NSFileManager *)fileManager
{
    if (!_fileManager) {
        _fileManager = [[NSFileManager alloc] init];
    }
    return _fileManager;
}

- (NSURLSession *)session
{
    if (!_session) {
        if (_backgroundConfigure) {
            if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
                _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:_backgroundConfigure] delegate:self delegateQueue:self.queue];
            } else {
                _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfiguration:_backgroundConfigure] delegate:self delegateQueue:self.queue];
            }
        } else {
            _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
        }
    }
    return _session;
}

- (NSOperationQueue *)queue
{
    if (!_queue) {
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1;
    }
    return _queue;
}

- (NSString *)downloadPath
{
    if (_downloadPath) {
        _downloadPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"ZJJDownloadCache"];
        [self creatCacheFileWithPath:_downloadPath];
    }
    return _downloadPath;
}


- (void)creatCacheFileWithPath:(NSString *)path
{
    if (![self.fileManager fileExistsAtPath:path]) {
        [self.fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

#pragma mark - Download Method

- (ZJJDownloadSessionModel *)startDownloadWithURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(ZJJDownloadProgressBlock)downloadProgress state:(ZJJDownloadStateBlock)state
{
    if (!URLString) {
        NSAssert(URLString != nil, @"URLString must is not equal nil");
        return nil;
    }
    
    ZJJDownloadSessionModel *downloadModel = [self downloadingModelForURLString:URLString];
    if (!downloadModel || ![downloadModel.filePath isEqualToString:destinationPath]) {
        downloadModel = [[ZJJDownloadSessionModel alloc] initWithDownLoadURLString:URLString filePath:destinationPath];
    }
    [self startDownloadModel:downloadModel progress:downloadProgress state:state];
    return downloadModel;
}

- (void)startDownloadModel:(ZJJDownloadSessionModel *)downloadModel progress:(ZJJDownloadProgressBlock)downloadProgress state:(ZJJDownloadStateBlock)state
{
    downloadModel.progressBlock = downloadProgress;
    downloadModel.stateBlock = state;
    [self startDownloadModel:downloadModel];
}

- (void)startDownloadModel:(ZJJDownloadSessionModel *)downloadModel
{
    if (!downloadModel) {
        return;
    }
    
    if (downloadModel.state == ZJJDownloadStateReady) {
        [self downloadModel:downloadModel changeState:ZJJDownloadStateReady filePath:nil error:nil];
        return;
    }
    
    if (downloadModel.sessionTask && downloadModel.sessionTask.state == NSURLSessionTaskStateRunning) {
        downloadModel.state =  ZJJDownloadStateInProgress;
        [self downloadModel:downloadModel changeState:ZJJDownloadStateInProgress filePath:nil error:nil];
        return;
    }
    
    
}

- (void)downloadModel:(ZJJDownloadSessionModel *)downloadModel changeState:(ZJJDownloadState)state filePath:(NSString *)filePath error:(NSError *)error
{
    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:changeState:filePath:error:)]) {
        [_delegate downloadModel:downloadModel changeState:state filePath:filePath error:error];
    }
    
    if (downloadModel.stateBlock) {
        downloadModel.stateBlock(state, filePath, error);
    }
}


- (ZJJDownloadSessionModel *)downloadingModelForURLString:(NSString *)URLString
{
    return [self.downloadModelDictionary objectForKey:URLString];
}


- (void)backgroundConfigireSessionTasksWithDownloadModel:(ZJJDownloadSessionModel *)downloadModel
{
    if (!_backgroundConfigure) {
        return;
    }
    
    NSURLSessionDownloadTask *task = [self backgroundSessionTasksWithDownloadModel:downloadModel];
    if (!task) {
        return;
    }
    
    downloadModel.sessionTask = task;
    if (task.state == NSURLSessionTaskStateRunning) {
        [task suspend];
    }
}

- (NSURLSessionDownloadTask *)backgroundSessionTasksWithDownloadModel:(ZJJDownloadSessionModel *)downloadModel
{
    NSArray *tasks = [self sessionDownloadTasks];
    for(NSURLSessionDownloadTask *task in tasks) {
        if (task.state == NSURLSessionTaskStateRunning || task.state == NSURLSessionTaskStateSuspended) {
            if ([downloadModel.downloadURL isEqualToString:task.taskDescription]) {
                return task;
            }
        }
    }
    return nil;
}

- (NSArray *)sessionDownloadTasks
{
    __block NSArray *tasks = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
        tasks = downloadTasks;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return tasks;
}

- (BOOL)canResumeDownloadModel:(ZJJDownloadSessionModel *)downloadModel
{
    if (_isBatchDownload) {
        return YES;
    }
    
    @synchronized (self) {
        if (self.downloadingModels.count >= self.maxDownloadCount) {
            if ([self.waitingDownloadModels indexOfObject:downloadModel] == NSNotFound) {
                [self.waitingDownloadModels addObject:downloadModel];
                self.downloadModelDictionary[downloadModel.downloadURL] = downloadModel;
            }
            downloadModel.state = ZJJDownloadStateReady;
            [self downloadModel:downloadModel changeState:ZJJDownloadStateReady filePath:nil error:nil];
            return NO;
        }
        
        if ([self.waitingDownloadModels indexOfObject:downloadModel] != NSNotFound) {
            [self.waitingDownloadModels removeObject:downloadModel];
        }
        
        if ([self.downloadingModels indexOfObject:downloadModel] == NSNotFound) {
            [self.downloadingModels addObject:downloadModel];
        }
        return YES;
    }
}

//- (NSData *)resumeDownloadFileDataWithDownloadModel:(ZJJDownloadSessionModel *)downloadModel
//{
//    if (downloadModel.resumeData) {
//        return downloadModel.resumeData;
//    }
//    
//    NSString *resumeFielDataPath = [self resumeFileDataWithDownloadURL:downloadModel.downloadURL];
//    
//}
//
//- (NSString *)resumeFileDataWithDownloadURL:(NSString *)downloadURL
//{
//    
//}

@end
