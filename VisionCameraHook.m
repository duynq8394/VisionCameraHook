#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Utility: Top View Controller

static UIViewController *VC_TopMostViewController(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState != UISceneActivationStateForegroundActive) continue;

        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                UIViewController *root = window.rootViewController;
                while (root.presentedViewController) {
                    root = root.presentedViewController;
                }
                return root;
            }
        }
    }
    return nil;
}

#pragma mark - Verification

__attribute__((constructor))
static void init_verify() {

    dispatch_async(dispatch_get_main_queue(), ^{

        NSMutableString *status = [NSMutableString stringWithString:@"VisionCameraHook VERIFY\n\n"];

        // ✅ 1. Dylib loaded
        [status appendString:@"✅ Dylib Loaded\n"];

        // ✅ 2. Check class existence
        Class cls = objc_getClass("CameraViewManager");
        if (cls) {
            [status appendString:@"✅ CameraViewManager found\n"];
        } else {
            [status appendString:@"❌ CameraViewManager NOT found\n"];
        }

        // ✅ 3. Check selector existence
        SEL sel = sel_registerName("takePhoto:options:resolve:reject:");
        if (cls && class_getInstanceMethod(cls, sel)) {
            [status appendString:@"✅ takePhoto method found\n"];
        } else {
            [status appendString:@"❌ takePhoto method NOT found\n"];
        }

        // ✅ 4. Show IMP address (optional debug)
        if (cls) {
            Method m = class_getInstanceMethod(cls, sel);
            if (m) {
                IMP imp = method_getImplementation(m);
                [status appendFormat:@"\nIMP: %p\n", imp];
            }
        }

        // ✅ Show Alert
        UIViewController *topVC = VC_TopMostViewController();
        if (!topVC) return;

        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"DYLIB STATUS"
                                            message:status
                                     preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *ok =
        [UIAlertAction actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                               handler:nil];

        [alert addAction:ok];

        [topVC presentViewController:alert animated:YES completion:nil];
    });
}
