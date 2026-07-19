#import <UIKit/UIKit.h>
#import <objc/runtime.h>

typedef void (^RCTPromiseResolveBlock)(id result);
typedef void (^RCTPromiseRejectBlock)(NSString *code, NSString *message, NSError *error);

static void (*orig_takePhoto)(id, SEL, id, id, RCTPromiseResolveBlock, RCTPromiseRejectBlock);

#pragma mark - Overlay Window

static UIWindow *gOverlayWindow;

static void ShowOverlayMessage(NSString *text) {

    dispatch_async(dispatch_get_main_queue(), ^{

        if (gOverlayWindow) {
            gOverlayWindow.hidden = YES;
            gOverlayWindow = nil;
        }

        UIWindowScene *activeScene = nil;

        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive &&
                    [scene isKindOfClass:[UIWindowScene class]]) {
                    activeScene = (UIWindowScene *)scene;
                    break;
                }
            }
        }

        gOverlayWindow = [[UIWindow alloc] initWithWindowScene:activeScene];
        gOverlayWindow.frame = UIScreen.mainScreen.bounds;
        gOverlayWindow.backgroundColor = UIColor.clearColor;
        gOverlayWindow.windowLevel = UIWindowLevelAlert + 1;
        gOverlayWindow.hidden = NO;

        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = UIColor.clearColor;
        gOverlayWindow.rootViewController = vc;

        UIView *box = [[UIView alloc] initWithFrame:CGRectMake(20, 80,
                            UIScreen.mainScreen.bounds.size.width - 40, 200)];

        box.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
        box.layer.cornerRadius = 12;
        box.clipsToBounds = YES;

        UITextView *label = [[UITextView alloc] initWithFrame:CGRectInset(box.bounds, 10, 10)];
        label.backgroundColor = UIColor.clearColor;
        label.textColor = UIColor.greenColor;
        label.font = [UIFont systemFontOfSize:12];
        label.editable = NO;
        label.text = text;

        [box addSubview:label];
        [vc.view addSubview:box];

        // Auto hide sau 6 giây
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 6 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            gOverlayWindow.hidden = YES;
            gOverlayWindow = nil;
        });
    });
}

#pragma mark - Hook

static void hook_takePhoto(id self,
                           SEL _cmd,
                           id arg1,
                           id options,
                           RCTPromiseResolveBlock resolve,
                           RCTPromiseRejectBlock reject)
{
    NSString *optionsText = [NSString stringWithFormat:@"Options:\n%@\n\n", options];

    RCTPromiseResolveBlock wrappedResolve = ^(id result) {

        NSString *resultText =
        [NSString stringWithFormat:@"Result:\n%@", result];

        NSString *fullText =
        [NSString stringWithFormat:@"📸 takePhoto called\n\n%@%@", optionsText, resultText];

        ShowOverlayMessage(fullText);

        resolve(result);
    };

    orig_takePhoto(self, _cmd, arg1, options, wrappedResolve, reject);
}

#pragma mark - Install Hook

static void InstallHook(void) {

    Class cls = objc_getClass("CameraViewManager");
    if (!cls) return;

    SEL sel = sel_getUid("takePhoto:options:resolve:reject:");
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;

    orig_takePhoto = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_takePhoto);
}

#pragma mark - Entry

__attribute__((constructor))
static void Init(void) {

    dispatch_async(dispatch_get_main_queue(), ^{
        InstallHook();
    });
}
