#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <objc/runtime.h>

typedef void (^RCTPromiseResolveBlock)(id result);
typedef void (^RCTPromiseRejectBlock)(NSString *code, NSString *message, NSError *error);

static void (*orig_takePhoto)(id, SEL, id, id, RCTPromiseResolveBlock, RCTPromiseRejectBlock);

#pragma mark - Top ViewController

static UIViewController *TopVC(void) {

    UIApplication *app = UIApplication.sharedApplication;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {

            if (scene.activationState != UISceneActivationStateForegroundActive)
                continue;

            if (![scene isKindOfClass:[UIWindowScene class]])
                continue;

            UIWindowScene *ws = (UIWindowScene *)scene;

            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) {
                    UIViewController *root = w.rootViewController;
                    while (root.presentedViewController)
                        root = root.presentedViewController;
                    return root;
                }
            }
        }
    }

    return nil;
}

#pragma mark - Picker Delegate

@interface VC_PickerDelegate : NSObject
<UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, copy) RCTPromiseResolveBlock resolve;
@property (nonatomic, copy) RCTPromiseRejectBlock reject;

@end

@implementation VC_PickerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {

    UIImage *image = info[UIImagePickerControllerOriginalImage];

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"vc_hook.jpg"];
    NSData *data = UIImageJPEGRepresentation(image, 0.9);
    [data writeToFile:path atomically:YES];

    [picker dismissViewControllerAnimated:YES completion:nil];

    if (self.resolve) {
        self.resolve(@{
            @"path": path
        });
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {

    [picker dismissViewControllerAnimated:YES completion:nil];

    if (self.reject) {
        self.reject(@"cancelled", @"User cancelled", nil);
    }
}

@end

static VC_PickerDelegate *gDelegate;

#pragma mark - Hook Implementation

static void hook_takePhoto(id self,
                           SEL _cmd,
                           id arg1,
                           id arg2,
                           RCTPromiseResolveBlock resolve,
                           RCTPromiseRejectBlock reject)
{
    NSLog(@"📸 takePhoto intercepted -> Using Photo Library");

    dispatch_async(dispatch_get_main_queue(), ^{

        UIViewController *vc = TopVC();
        if (!vc) {
            if (reject)
                reject(@"no_vc", @"No active ViewController", nil);
            return;
        }

        UIImagePickerController *picker = [UIImagePickerController new];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

        gDelegate = [VC_PickerDelegate new];
        gDelegate.resolve = resolve;
        gDelegate.reject = reject;

        picker.delegate = gDelegate;

        [vc presentViewController:picker animated:YES completion:nil];
    });
}

#pragma mark - Install Hook

static void InstallHook(void) {

    Class cls = objc_getClass("CameraViewManager");
    if (!cls) {
        NSLog(@"❌ CameraViewManager not found");
        return;
    }

    SEL sel = sel_getUid("takePhoto:options:resolve:reject:");
    Method m = class_getInstanceMethod(cls, sel);

    if (!m) {
        NSLog(@"❌ Method not found");
        return;
    }

    orig_takePhoto = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_takePhoto);

    NSLog(@"✅ takePhoto hook installed");
}

#pragma mark - Entry

__attribute__((constructor))
static void Init(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        InstallHook();
    });
}
