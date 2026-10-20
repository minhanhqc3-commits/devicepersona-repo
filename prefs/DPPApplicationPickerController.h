#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DPPApplicationSelectionHandler)(NSArray<NSString *> *bundleIdentifiers);

@interface DPPApplicationPickerController : UITableViewController

- (instancetype)initWithSelectedBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                                  selectionHandler:(DPPApplicationSelectionHandler)selectionHandler;

@end

NS_ASSUME_NONNULL_END
