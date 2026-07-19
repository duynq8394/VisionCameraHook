#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL gInspectorShown = NO;

#pragma mark - Utility: Top ViewController

static UIViewController *VC_TopViewController(void) {

    UIApplication *app = UIApplication.sharedApplication;

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

    return nil;
}

#pragma mark - Generic Hook Trampoline

typedef void (*GenericFunc)(id, SEL, ...);

static void GenericHook(id self, SEL _cmd, ...) {

    NSLog(@"🔥 Inspector: Method triggered -> %@", NSStringFromSelector(_cmd));

    // Gọi lại original
    Method m = class_getInstanceMethod([self class], _cmd);
    IMP originalImp = method_getImplementation(m);

    if (originalImp) {
        ((GenericFunc)originalImp)(self, _cmd);
    }
}

#pragma mark - Hook Methods Dynamically

static void VC_InstallInspectorHooks(void) {

    Class cls = objc_getClass("CameraViewManager");
    if (!cls) {
        NSLog(@"❌ CameraViewManager not found");
        return;
    }

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);

    NSLog(@"===== CameraViewManager Methods (%u) =====", count);

    for (unsigned int i = 0; i < count; i++) {

        SEL sel = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(sel);

        NSLog(@"Method: %@", name);

        if ([name containsString:@"takePhoto"]) {

            NSLog(@"✅ Installing inspector hook for %@", name);

            method_setImplementation(methods[i], (IMP)GenericHook);
        }
    }

    free(methods);
}

#pragma mark - UI Verify

static void VC_ShowInspectorAlert(void) {

    if (gInspectorShown) return;
    gInspectorShown = YES;

    dispatch_async(dispatch_get_main_queue(), ^{

        NSMutableString *msg =
        [NSMutableString stringWithString:@"✅ Inspector Loaded\n\n"];

        Class cls = objc_getClass("CameraViewManager");

        if (cls)
            [msg appendString:@"✅ CameraViewManager found\n"];
        else
            [msg appendString:@"❌ CameraViewManager NOT found\n"];

        UIViewController *top = VC_TopViewController();
        if (!top) return;

        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"VisionCamera Inspector"
                                            message:msg
                                     preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *ok =
        [UIAlertAction actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                               handler:nil];

        [alert addAction:ok];
        [top presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - Entry

__attribute__((constructor))
static void VisionCameraHook_Init(void) {

    NSLog(@"✅ Inspector dylib injected");

    dispatch_async(dispatch_get_main_queue(), ^{

        VC_ShowInspectorAlert();
        VC_InstallInspectorHooks();
    });
}
