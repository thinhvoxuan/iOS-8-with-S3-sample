//
//  S3UploadHelper.m
//  S3TransferManagerSample
//
//  Created by thinhvoxuan on 7/13/16.
//  Copyright © 2016 Amazon Web Services. All rights reserved.
//

#import "S3UploadHelper.h"
#import "Constants.h"

@implementation S3UploadHelper
+ (id)sharedManager {
    static S3UploadHelper *sharedMyManager = nil;
    @synchronized(self) {
        if (sharedMyManager == nil)
            sharedMyManager = [[self alloc] init];
    }
    return sharedMyManager;
}

- (id) init {
    self = [super init];
    if (self){
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"uploadS3Folder"]
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error]) {
            NSLog(@"reating 'upload' directory failed: [%@]", error);
        }
    }
    return self;
}

- (NSString *) getGlobalFileName {
    NSString *fileName = [[[NSProcessInfo processInfo] globallyUniqueString] stringByAppendingString:@".png"];
    return fileName;
}


- (AWSS3TransferManagerUploadRequest *) fileName:(NSString *)fileName uploadImage:(UIImage *) image completion:(void (^)(AWSS3TransferManagerUploadRequest *uploadRequest))completionBlock {
    NSString *filePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"uploadS3Folder"] stringByAppendingPathComponent:fileName];
    NSData * imageData = UIImagePNGRepresentation(image);
    [imageData writeToFile:filePath atomically:YES];
    AWSS3TransferManagerUploadRequest *uploadRequest = [AWSS3TransferManagerUploadRequest new];
    uploadRequest.body = [NSURL fileURLWithPath:filePath];
    uploadRequest.key = fileName;
    uploadRequest.bucket = S3BucketName;
    [self upload:uploadRequest completion:completionBlock];
    return uploadRequest;
}


- (void)upload:(AWSS3TransferManagerUploadRequest *)uploadRequest completion:(void (^)(AWSS3TransferManagerUploadRequest *uploadRequest))completionBlock{
    AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];

    [[transferManager upload:uploadRequest] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            if ([task.error.domain isEqualToString:AWSS3TransferManagerErrorDomain]) {
                switch (task.error.code) {
                    case AWSS3TransferManagerErrorCancelled:
                        NSLog(@"Upload Error: [%@]", task.error);
                        break;
                    case AWSS3TransferManagerErrorPaused:
                        NSLog(@"Upload Paused: [%@]", task.error);
                        break;
                    default:
                        NSLog(@"Upload failed: [%@]", task.error);
                        break;
                }
            } else {
                NSLog(@"Upload failed: [%@]", task.error);
            }
        }
        
        if (task.result) {
            if (completionBlock) {
                completionBlock(uploadRequest);
            }   
        }
        return nil;
    }];
}


@end
