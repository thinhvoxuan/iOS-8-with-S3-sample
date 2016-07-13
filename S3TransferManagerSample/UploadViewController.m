/*
 * Copyright 2010-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

#import "UploadViewController.h"
#import "Constants.h"
@import AWSS3;

@import AssetsLibrary;


@interface UploadViewController ()<UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong) NSMutableArray *collection;
@property (nonatomic, strong) S3UploadHelper *s3UploadHelper;
@end

@implementation UploadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.s3UploadHelper = [S3UploadHelper sharedManager];
    self.collection = [NSMutableArray new];
}

#pragma mark - User action methods

- (IBAction)showAlertController:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Available Actions"
                                                                             message:@"Choose your action."
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];

    __weak UploadViewController *weakSelf = self;
    UIAlertAction *selectPictureAction = [UIAlertAction actionWithTitle:@"Select Pictures"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *action) {
                                                                    UploadViewController *strongSelf = weakSelf;
                                                                    [strongSelf selectPictures];
                                                                }];
    [alertController addAction:selectPictureAction];

    UIAlertAction *cancelAllUploadsAction = [UIAlertAction actionWithTitle:@"Cancel All Uploads"
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction *action) {
                                                                       UploadViewController *strongSelf = weakSelf;
                                                                       [strongSelf cancelAllUploads:self];
                                                                   }];
    [alertController addAction:cancelAllUploadsAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alertController addAction:cancelAction];

    [self presentViewController:alertController
                       animated:YES
                     completion:nil];
}

- (void)selectPictures {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    [self presentViewController:picker animated:YES completion:NULL];
    
}


- (void)cancelAllUploads:(id)sender {
    [self.collection enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[AWSS3TransferManagerUploadRequest class]]) {
            AWSS3TransferManagerUploadRequest *uploadRequest = obj;
            [[uploadRequest cancel] continueWithBlock:^id(AWSTask *task) {
                __weak UploadViewController *weakSelf = self;
                if (task.error) {
                    NSLog(@"The cancel request failed: [%@]", task.error);
                }
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:idx inSection:0];
                [weakSelf.collectionView reloadItemsAtIndexPaths:@[indexPath]];
                return nil;
            }];
        }
    }];
}

#pragma mark - Collection View methods

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return [self.collection count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UploadCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"UploadCollectionViewCell" forIndexPath:indexPath];
    id object = [self.collection objectAtIndex:indexPath.row];
    if ([object isKindOfClass:[AWSS3TransferManagerUploadRequest class]]) {
        AWSS3TransferManagerUploadRequest *uploadRequest = object;

        switch (uploadRequest.state) {
            case AWSS3TransferManagerRequestStateRunning: {
                cell.imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:uploadRequest.body]];
                cell.label.hidden = YES;

                uploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (totalBytesExpectedToSend > 0) {
                            cell.progressView.progress = (float)((double) totalBytesSent / totalBytesExpectedToSend);
                        }
                    });
                };
            }
                break;

            case AWSS3TransferManagerRequestStateCanceling:
            {
                cell.imageView.image = nil;
                cell.label.hidden = NO;
                cell.label.text = @"Cancelled";
            }
                break;

            case AWSS3TransferManagerRequestStatePaused:
            {
                cell.imageView.image = nil;
                cell.label.hidden = NO;
                cell.label.text = @"Paused";
            }
                break;

            default:
            {
                cell.imageView.image = nil;
                cell.label.hidden = YES;
            }
                break;
        }
    } else if ([object isKindOfClass:[NSURL class]]) {
        NSURL *downloadFileURL = object;
        cell.imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:downloadFileURL]];
        cell.label.hidden = NO;
        cell.label.text = @"Uploaded";
        cell.progressView.progress = 1.0f;
    }

    return cell;
}

#pragma mark - image picker controller delegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)imageDictionary{
    [self dismissViewControllerAnimated:YES completion:nil];
    UIImage *image = imageDictionary[UIImagePickerControllerEditedImage];
    
    NSString *fileName = [self.s3UploadHelper getGlobalFileName];
    AWSS3TransferManagerUploadRequest *uploadRequest =  [self.s3UploadHelper fileName:fileName uploadImage:image completion:^(AWSS3TransferManagerUploadRequest *uploadResponse) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __weak UploadViewController *weakSelf = self;
            NSUInteger index = [weakSelf.collection indexOfObject:uploadResponse];
            [weakSelf.collection replaceObjectAtIndex:index withObject:uploadResponse.body];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            [weakSelf.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        });
    }];
    
    [self.collection insertObject:uploadRequest atIndex:0];
    [self.collectionView reloadData];
};
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [self dismissViewControllerAnimated:YES completion:nil];
};

@end

@implementation UploadCollectionViewCell

@end
