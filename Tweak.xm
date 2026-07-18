#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>

@interface CameraViewManager : NSObject
- (void)takePhoto:(id)options
          resolve:(id)resolve
           reject:(id)reject;
@end

@interface PhotoPickerDelegate : NSObject <PHPickerViewControllerDelegate>
@property (nonatomic, copy) void (^resolveBlock)(id result);
@property (nonatomic, copy) void (^rejectBlock)(NSString *code, NSString *message, NSError *error);
@end

@implementation PhotoPickerDelegate

- (void)picker:(PHPickerViewController *)picker
didFinishPicking:(NSArray<PHPickerResult *> *)results {

    [picker dismissViewControllerAnimated:YES completion:nil];

    if (results.count == 0) {
        if (self.rejectBlock) {
            self.rejectBlock(@"cancelled", @"User cancelled", nil);
        }
        return;
    }

    PHPickerResult *result = results.firstObject;

    if ([result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        [result.itemProvider loadObjectOfClass:[UIImage class]
                             completionHandler:^(UIImage *image, NSError *error) {

            if (error || !image) {
                if (self.rejectBlock) {
                    self.rejectBlock(@"error", @"Failed to load image", error);
                }
                return;
            }

            NSData *data = UIImageJPEGRepresentation(image, 0.9);

            NSString *filePath =
                [NSTemporaryDirectory()
                 stringByAppendingPathComponent:
                 [NSString stringWithFormat:@"picked_%@.jpg",
                  [[NSUUID UUID] UUIDString]]];

            [data writeToFile:filePath atomically:YES];

            if (self.resolveBlock) {
                self.resolveBlock(@{
                    @"path": filePath,
                    @"width": @(image.size.width),
                    @"height": @(image.size.height)
                });
            }
        }];
    }
}

@end


%hook CameraViewManager

- (void)takePhoto:(id)options
          resolve:(id)resolve
           reject:(id)reject {

    dispatch_async(dispatch_get_main_queue(), ^{

        PHPickerConfiguration *config =
            [[PHPickerConfiguration alloc] init];
        config.filter = [PHPickerFilter imagesFilter];
        config.selectionLimit = 1;

        PHPickerViewController *picker =
            [[PHPickerViewController alloc] initWithConfiguration:config];

        PhotoPickerDelegate *delegate =
            [PhotoPickerDelegate new];

        delegate.resolveBlock = resolve;
        delegate.rejectBlock = reject;

        picker.delegate = delegate;

        UIViewController *root =
            [UIApplication sharedApplication].keyWindow.rootViewController;

        [root presentViewController:picker
                           animated:YES
                         completion:nil];
    });
}

%end
