#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <objc/runtime.h>

#pragma mark - Utilities

static UIViewController *topMostViewController(void) {
    UIWindow *keyWindow = nil;

    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            keyWindow = scene.windows.firstObject;
            break;
        }
    }

    UIViewController *root = keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    return root;
}

#pragma mark - Delegate

@interface VCPhotoDelegate : NSObject <PHPickerViewControllerDelegate>
@property (nonatomic, copy) void (^resolveBlock)(id result);
@end

@implementation VCPhotoDelegate

- (void)picker:(PHPickerViewController *)picker
didFinishPicking:(NSArray<PHPickerResult *> *)results {

    UIViewController *presentingVC = picker.presentingViewController;
    [picker dismissViewControllerAnimated:YES completion:nil];

    // ✅ CASE C: Cancel → đóng luôn camera
    if (results.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [presentingVC dismissViewControllerAnimated:YES completion:nil];
        });
        return;
    }

    PHPickerResult *result = results.firstObject;

    if (![result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        return;
    }

    [result.itemProvider loadObjectOfClass:[UIImage class]
                         completionHandler:^(UIImage *image, NSError *error) {

        if (!image || error) {
            return;
        }

        NSData *data = UIImageJPEGRepresentation(image, 0.9);
        if (!data) return;

        NSString *filePath =
        [NSTemporaryDirectory()
         stringByAppendingPathComponent:
         [NSString stringWithFormat:@"picked_%@.jpg",
          [[NSUUID UUID] UUIDString]]];

        if (![data writeToFile:filePath atomically:YES]) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.resolveBlock) {
                self.resolveBlock(@{
                    @"path": filePath,
                    @"width": @(image.size.width),
                    @"height": @(image.size.height)
                });
            }
        });
    }];
}

@end

#pragma mark - Hook

static void (*orig_takePhoto)(id, SEL, id, id, id);

static void replaced_takePhoto(id self,
                               SEL _cmd,
                               id options,
                               id resolve,
                               id reject) {

    dispatch_async(dispatch_get_main_queue(), ^{

        if (@available(iOS 14.0, *)) {

            PHPickerConfiguration *config =
            [[PHPickerConfiguration alloc] init];
            config.filter = [PHPickerFilter imagesFilter];
            config.selectionLimit = 1;

            PHPickerViewController *picker =
            [[PHPickerViewController alloc] initWithConfiguration:config];

            VCPhotoDelegate *delegate = [VCPhotoDelegate new];
            delegate.resolveBlock = resolve;
            picker.delegate = delegate;

            // giữ delegate sống
            objc_setAssociatedObject(picker,
                                     @"vc_delegate",
                                     delegate,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            UIViewController *topVC = topMostViewController();
            [topVC presentViewController:picker
                                animated:YES
                              completion:nil];
        }
    });
}

#pragma mark - Constructor

__attribute__((constructor))
static void init_hook() {

    Class cls = objc_getClass("CameraViewManager");
    if (!cls) return;

    SEL sel = sel_registerName("takePhoto:options:resolve:reject:");
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    orig_takePhoto = (void *)method_getImplementation(method);
    method_setImplementation(method, (IMP)replaced_takePhoto);
}