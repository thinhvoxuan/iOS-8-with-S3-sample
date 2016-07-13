//
//  S3UploadHelper.h
//  S3TransferManagerSample
//
//  Created by thinhvoxuan on 7/13/16.
//  Copyright © 2016 Amazon Web Services. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AWSS3;

@interface S3UploadHelper : NSObject
+ (id)sharedManager;
- (NSString *) getGlobalFileName;
- (AWSS3TransferManagerUploadRequest *) fileName:(NSString *) fileName uploadImage:(UIImage *) image completion:(void (^)(AWSS3TransferManagerUploadRequest *uploadRequest))completionBlock;
@end
