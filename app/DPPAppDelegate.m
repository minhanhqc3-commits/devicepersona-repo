#import "DPPAppDelegate.h"
#import "DPPRootListController.h"

@implementation DPPAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    DPPRootListController *rootController = [[DPPRootListController alloc] init];
    rootController.title = @"DevicePersona";

    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:rootController];
    if (@available(iOS 11.0, *)) {
        navigationController.navigationBar.prefersLargeTitles = YES;
        rootController.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    }

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = navigationController;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
