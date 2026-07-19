#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL gHasShownAlert = NO;

#pragma mark - Get Top View Controller Safely

static UIViewController *VC_TopViewController(void) {

    UIApplication *app = UIApplication.sharedApplication;

    // iOS 13+ (Scene-based)
    if (@available(iOS 13.0, *)) {

        for (UIScene *scene in app.connectedScenes) {

            if (scene.activationState != UISceneActivationStateForegroundActive)
                continue;

            if (![scene isKindOfClass:[UIWindowScene class]])
                continue;

            UIWindowScene *windowScene = (UIWindowScene *)scene;

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
    }

    // Fallback iOS 12
    UIWindow *keyWindow = app.keyWindow;
    UIViewController *root = keyWindow.rootViewController;

    while (root.presentedViewController) {
        root = root.presentedViewController;
    }

    return root;
}

#pragma mark - Show Verify Alert

static void VC_ShowVerifyAlert(void) {

    if (gHasShownAlert) return;
    gHasShownAlert = YES;

    dispatch_async(dispatch_get_main_queue(), ^{

        NSMutableString *status =
        [NSMutableString stringWithString:@"✅ VisionCameraHook Loaded\n\n"];

        // Check class
        Class cls = objc_getClass("CameraViewManager");
        if (cls) {
            [status appendString:@"✅ CameraViewManager found\n"];
        } else {
            [status appendString:@"❌ CameraViewManager NOT found\n"];
        }

        // Check selector
        SEL sel = sel_registerName("takePhoto:options:resolve:reject:");
        if (cls && class_getInstanceMethod(cls, sel)) {
            [status appendString:@"✅ takePhoto method found\n"];
        } else {
            [status appendString:@"❌ takePhoto method NOT found\n"];
        }

        UIViewController *topVC = VC_TopViewController();
        if (!topVC) {
            NSLog(@"VisionCameraHook: Top VC not found");
            return;
        }

        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"DYLIB VERIFY"
                                            message:status
                                     preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *okAction =
        [UIAlertAction actionWithTitle:@"OK"
                                 style:UIAlertActionStyleCancel
                               handler:nil];

        [alert addAction:okAction];

        [topVC presentViewController:alert animated:YES completion:nil];

        NSLog(@"✅ VisionCameraHook alert presented");
    });
}

#pragma mark - Constructor (Entry Point)

__attribute__((constructor))
static void VisionCameraHook_Init(void) {

    NSLog(@"✅ VisionCameraHook dylib injected");

    dispatch_async(dispatch_get_main_queue(), ^{

        // Nếu app đã active thì show luôn
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
            VC_ShowVerifyAlert();
        }

        // Nếu chưa active thì đợi
        [[NSNotificationCenter defaultCenter]
         addObserverForName:UIApplicationDidBecomeActiveNotification
         object:nil
         queue:[NSOperationQueue mainQueue]
         usingBlock:^(NSNotification * _Nonnull note) {

            VC_ShowVerifyAlert();
        }];
    });
}
