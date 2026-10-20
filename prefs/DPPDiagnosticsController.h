#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DPPDiagnosticsController : UITableViewController

- (instancetype)initWithProfile:(NSDictionary<NSString *, id> *)profile
                         enabled:(BOOL)enabled
         targetBundleIdentifiers:(NSArray<NSString *> *)targetBundleIdentifiers
         advancedHardwareEnabled:(BOOL)advancedHardwareEnabled;

@end

NS_ASSUME_NONNULL_END
