#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL gDylibLoaded = NO;

#pragma mark - Show Alert Safely

static void VC_ShowAlert(void) {
    if (!gDylibLoaded) return;

    dispatch_async(dispatch_get_main_queue(), ^{

        NSMutableString *status = [NSMutableString stringWithString:@"✅ VisionCameraHook Loaded\n\n"];

        Class cls = objc_getClass("CameraViewManager");
        if (cls) {
            [status appendString:@"✅ CameraViewManager found\n"];
        } else {
            [status appendString:@"❌ CameraViewManager NOT found\n"];
        }

        SEL sel = sel_registerName("takePhoto:options:resolve:reject:");
        if (cls && class_getInstanceMethod(cls, sel)) {
            [status appendString:@"✅ takePhoto method found\n"];
        } else {
            [status appendString:@"❌ takePhoto method NOT found\n"];
        }

        // Lấy window hiện tại
        UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
        if (!window) return;

        UIViewController *root = window.rootViewController;
        if (!root) return;

        while (root.presentedViewController) {
            root = root.presentedViewController;
        }

        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"DYLIB VERIFY"
                                            message:status
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];

        [root presentViewController:alert animated:YES completion:nil];

        // Chỉ hiển thị 1 lần
        gDylibLoaded = NO;
    });
}

#pragma mark - Constructor

__attribute__((constructor))
static void init_verify(void) {

    gDylibLoaded = YES;

    NSLog(@"✅ VisionCameraHook dylib injected");

    // Đợi app active rồi mới show alert
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationDidBecomeActiveNotification
     object:nil
     queue:[NSOperationQueue mainQueue]
     usingBlock:^(NSNotification * _Nonnull note) {

        VC_ShowAlert();
    }];
}
