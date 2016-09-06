//
//  ZJJDownloadSessionManager.m
//  ZJJDownloadManager
//
//  Created by baijf on 8/31/16.
//  Copyright © 2016 Junne. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZJJDownloadSessionManager.h"
#import <CommonCrypto/CommonDigest.h>


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
@property (nonatomic, strong) NSDate *downloadDate;
@property (nonatomic, assign) BOOL manualCancel;


@end


@interface ZJJDownloadProgress ()

@property (nonatomic, assign) int64_t resumeBytesWritten;

@property (nonatomic, assign) int64_t bytesWritten;

@property (nonatomic, assign) int64_t totalBytesWritten;

@property (nonatomic, assign) int64_t totalBytesExpectedToWrite;

@property (nonatomic, assign) float progress;

@property (nonatomic, assign) float speed;

@property (nonatomic, assign) int remainTime;

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

- (void)suspendDownloadModel:(ZJJDownloadSessionModel *)downloadModel
{
    if (!downloadModel.manualCancel) {
        downloadModel.manualCancel = YES;
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
        NSData *resumeData = [self resumeDownloadFileDataWithDownloadModel:downloadModel];
        
        if (resumeData.length > 0) {
            downloadModel.sessionTask = [self.session downloadTaskWithResumeData:resumeData];
        } else {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:downloadModel.downloadURL]];
            downloadModel.sessionTask = [self.session downloadTaskWithRequest:request];
        }
        downloadModel.sessionTask.taskDescription = downloadModel.downloadURL;
        downloadModel.downloadDate = [NSDate date];
    }
    
    if (!downloadModel.downloadDate) {
        downloadModel.downloadDate = [NSDate date];
    }
    
    if (![self.downloadModelDictionary objectForKey:downloadModel.downloadURL]) {
        self.downloadModelDictionary[downloadModel.downloadURL] = downloadModel;
    }
    
    [downloadModel.sessionTask resume];
    
    downloadModel.state = ZJJDownloadStateInProgress;
    [self downloadModel:downloadModel changeState:ZJJDownloadStateInProgress filePath:nil error:nil];
}


- (void)cancelFileDownloadModel:(ZJJDownloadSessionModel *)downloadModel
{
    if (downloadModel.state != ZJJDownloadStateCompleted && downloadModel.state != ZJJDownloadStateFailed) {
        [self cancelDownloadModel:downloadModel clearResumeData:NO];
    }
}

- (void)deleteFileDownload:(ZJJDownloadSessionModel *)downloadModel
{
    if (!downloadModel || !downloadModel.filePath) {
        return;
    }
    [self cancelDownloadModel:downloadModel clearResumeData:YES];
    [self deleteFileIfExist:downloadModel.filePath];
}

- (void)deleteAllFiledWithDownloadDirectory:(NSString *)downloadDirectory
{
    if (!downloadDirectory) {
        downloadDirectory = self.downloadPath;
    }
    
    for (ZJJDownloadSessionModel *downloadModel in [self.downloadModelDictionary allValues]) {
        if ([downloadModel.downloadPath isEqualToString:downloadDirectory]) {
            [self cancelDownloadModel:downloadModel clearResumeData:YES];
        }
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

- (NSMutableArray *)downloadingModels
{
    if (!_downloadingModels) {
        _downloadingModels = [NSMutableArray array];
    }
    return _downloadingModels;
}


- (NSMutableDictionary *)downloadModelDictionary
{
    if (!_downloadModelDictionary) {
        _downloadModelDictionary = [[NSMutableDictionary alloc] init];
    }
    return _downloadModelDictionary;
}

- (NSMutableArray *)waitingDownloadModels
{
    if (!_waitingDownloadModels) {
        _waitingDownloadModels = [NSMutableArray array];
    }
    return _waitingDownloadModels;
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

- (void)downloadModel:(ZJJDownloadSessionModel *)downloadModel updateProgress:(ZJJDownloadProgress *)progress
{
    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:updateProgress:)]) {
        [_delegate downloadModel:downloadModel updateProgress:progress];
    }
    if (downloadModel.progressBlock) {
        downloadModel.progressBlock(progress);
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

- (NSData *)resumeDownloadFileDataWithDownloadModel:(ZJJDownloadSessionModel *)downloadModel
{
    if (downloadModel.resumeData) {
        return downloadModel.resumeData;
    }
    
    NSString *resumeFileDataPath = [self resumeFileDataWithDownloadURL:downloadModel.downloadURL];
    if ([self.fileManager fileExistsAtPath:resumeFileDataPath]) {
        NSData *resumeData = [NSData dataWithContentsOfFile:resumeFileDataPath];
        return resumeData;
    }
    return nil;
}

- (NSString *)resumeFileDataWithDownloadURL:(NSString *)downloadURL
{
    NSString *resumeFileName = [[self class] md5:downloadURL];
    return [self.downloadPath stringByAppendingPathComponent:resumeFileName];
}

- (void)cancelDownloadModel:(ZJJDownloadSessionModel *)downloadModel clearResumeData:(BOOL)clearResumeData
{
    if (!downloadModel.sessionTask && downloadModel.state == ZJJDownloadStateReady) {
        [self removeDownloadModelForURLString:downloadModel.downloadURL];
        @synchronized (self) {
            [self.waitingDownloadModels removeObject:downloadModel];
        }
        downloadModel.state = ZJJDownloadStateNone;
        [self downloadModel:downloadModel changeState:ZJJDownloadStateNone filePath:nil error:nil];
        return;
    }
    
    if (clearResumeData) {
        downloadModel.resumeData = nil;
        [downloadModel.sessionTask cancel];
    } else {
        [downloadModel.sessionTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            
        }];
    }
}

- (void)willResumeNextDownloadModel:(ZJJDownloadSessionModel *)downloadModel
{
    if (_isBatchDownload) {
        return;
    }
    
    @synchronized (self) {
        [self.downloadingModels removeObject:downloadModel];
        if (self.waitingDownloadModels.count > 0) {
            [self resumeDownloadModel:self.waitingDownloadModels.firstObject];
        }
    }
}


- (void)removeDownloadModelForURLString:(NSString *)URLString
{
    [self.downloadModelDictionary removeObjectForKey:URLString];
}

- (void)deleteFileIfExist:(NSString *)filePath
{
    if ([self.fileManager fileExistsAtPath:filePath]) {
        NSError *error = nil;
        [self.fileManager removeItemAtPath:filePath error:&error];
        if (error) {
            NSAssert(error == nil, @"delete field");
        }
    }
}


+ (NSString *)md5:(NSString *)inputString
{
    const char *cStr = [inputString UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i ++) {
        [result appendFormat:@"%02X", digest[i]];
    }
    return result;
}

- (void)creatDirectory:(NSString *)directory
{
    if (![self.fileManager fileExistsAtPath:directory]) {
        [self.fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

- (void)moveFileAtURL:(NSURL *)sourceURL toPath:(NSString *)desitinationPath
{
    NSError *error = nil;
    if ([self.fileManager fileExistsAtPath:desitinationPath]) {
        [self.fileManager removeItemAtPath:desitinationPath error:&error];
        if (error) {
            NSAssert(error == nil, @"removeItem error");
        }
    }
    
    NSURL *desitinationURL = [NSURL fileURLWithPath:desitinationPath];
    [self.fileManager moveItemAtURL:sourceURL toURL:desitinationURL error:&error];
    if (error) {
        NSAssert(error == nil, @"moveItem error");
    }
}


- (ZJJDownloadSessionModel *)downloadModelForURLString:(NSString *)URLString
{
    return [self.downloadModelDictionary objectForKey:URLString];
}


#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    ZJJDownloadSessionModel *downloadModel = [self downloadModelForURLString:downloadTask.taskDescription];
    if (!downloadModel || downloadModel.state == ZJJDownloadStatePause) {
        return;
    }
    downloadModel.progress.resumeBytesWritten = fileOffset;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    ZJJDownloadSessionModel *downloadModel = [self downloadModelForURLString:downloadModel.sessionTask.taskDescription];
    
    if (!downloadModel || downloadModel.state == ZJJDownloadStatePause) {
        return;
    }
    
    float progress = (double)totalBytesWritten / totalBytesExpectedToWrite;
    int64_t resumeBytesWritten = downloadModel.progress.resumeBytesWritten;
    NSTimeInterval downloadTime = -1 * [downloadModel.downloadDate timeIntervalSinceNow];
    float speed = (totalBytesWritten - resumeBytesWritten) / downloadTime;
    
    int64_t remainContentLength = totalBytesExpectedToWrite - totalBytesWritten;
    int remainTime = ceilf(remainContentLength / speed);
    
    downloadModel.progress.bytesWritten = bytesWritten;
    downloadModel.progress.totalBytesWritten = totalBytesWritten;
    downloadModel.progress.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    downloadModel.progress.speed =  speed;
    downloadModel.progress.progress = progress;
    downloadModel.progress.remainTime = remainTime;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self downloadModel:downloadModel updateProgress:downloadModel.progress];
    });
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    ZJJDownloadSessionModel *downloadModel = [self downloadModelForURLString:downloadTask.taskDescription];
    
    if (!downloadModel && _backgroundSessionDownloadCompletedBlock) {
        NSString *filePath = _backgroundSessionDownloadCompletedBlock(downloadTask.taskDescription);
        [self creatDirectory:filePath.stringByDeletingLastPathComponent];
        [self moveFileAtURL:location toPath:filePath];
        return;
    }
    
    if (location) {
        [self  creatDirectory:downloadModel.downloadPath];
        [self moveFileAtURL:location toPath:downloadModel.filePath];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    ZJJDownloadSessionModel *downloadModel = [self downloadModelForURLString:task.taskDescription];
    
    if (!downloadModel) {
        NSData *resumeData = error ? [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData] : nil;
        if (resumeData) {
            [self creatDirectory:_downloadPath];
            [resumeData writeToFile:[self resumeFileDataWithDownloadURL:task.taskDescription] atomically:YES];
        } else {
            [self deleteFileIfExist:[self resumeFileDataWithDownloadURL:task.taskDescription]];
        }
        return;
    }
    
    NSData *resumeData = nil;
    if (error) {
        resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
    }
    
    if (resumeData) {
        downloadModel.resumeData = resumeData;
        [self creatDirectory:_downloadPath];
        [downloadModel.resumeData writeToFile:[self resumeFileDataWithDownloadURL:downloadModel.downloadURL] atomically:YES];
    } else {
        downloadModel.resumeData = nil;
        [self deleteFileIfExist:[self resumeFileDataWithDownloadURL:downloadModel.downloadURL]];
    }
    
    downloadModel.progress.resumeBytesWritten = 0;
    downloadModel.sessionTask = nil;
    [self removeDownloadModelForURLString:downloadModel.downloadURL];
    
    if (downloadModel.manualCancel) {
        dispatch_async(dispatch_get_main_queue(), ^{
            downloadModel.manualCancel = NO;
            downloadModel.state = ZJJDownloadStatePause;
            [self downloadModel:downloadModel changeState:ZJJDownloadStatePause filePath:nil error:nil];
        });
    } else if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            downloadModel.state = ZJJDownloadStateFailed;
            [self downloadModel:downloadModel changeState:ZJJDownloadStateFailed filePath:nil error:error];
            [self willResumeNextDownloadModel:downloadModel];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            downloadModel.state = ZJJDownloadStateCompleted;
            [self downloadModel:downloadModel changeState:ZJJDownloadStateCompleted filePath:downloadModel.filePath error:nil];
            [self willResumeNextDownloadModel:downloadModel];
        });
    }
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    if (self.backgroundSessionCompletionHandler) {
        self.backgroundSessionCompletionHandler();
    }
}

@end
