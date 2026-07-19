#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL gShown = NO;

#pragma mark - Top View Controller

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

#pragma mark - Inspector

static void ShowInspector(void) {

    if (gShown) return;
    gShown = YES;

    Class cls = objc_getClass("CameraViewManager");
    if (!cls) {
        NSLog(@"❌ CameraViewManager not found");
        return;
    }

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);

    NSMutableString *output =
    [NSMutableString stringWithString:@"CameraViewManager\n\n"];

    for (unsigned int i = 0; i < count; i++) {

        SEL sel = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(sel);

        if ([name containsString:@"takePhoto"]) {

            const char *types = method_getTypeEncoding(methods[i]);

            [output appendFormat:@"SEL: %@\n", name];
            [output appendFormat:@"TypeEncoding: %s\n\n", types];
        }
    }

    free(methods);

    dispatch_async(dispatch_get_main_queue(), ^{

        UIViewController *vc = TopVC();
        if (!vc) return;

        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Method Inspector"
                                            message:output
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];

        [vc presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - Entry

__attribute__((constructor))
static void Init(void) {

    dispatch_async(dispatch_get_main_queue(), ^{

        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
            ShowInspector();
        }

        [[NSNotificationCenter defaultCenter]
         addObserverForName:UIApplicationDidBecomeActiveNotification
         object:nil
         queue:[NSOperationQueue mainQueue]
         usingBlock:^(NSNotification * _Nonnull note) {
            ShowInspector();
        }];
    });
}
