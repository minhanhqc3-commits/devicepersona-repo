#import "DPPApplicationPickerController.h"
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <objc/message.h>

@interface DPPInstalledApplication : NSObject
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *bundleIdentifier;
@end

@implementation DPPInstalledApplication
@end

static id DPPCallObjectMethod(id receiver, SEL selector) {
    id (*sendMessage)(id, SEL) = (void *)objc_msgSend;
    return sendMessage(receiver, selector);
}

static BOOL DPPCallBoolMethod(id receiver, SEL selector, BOOL fallback) {
    if (receiver == nil || ![receiver respondsToSelector:selector]) {
        return fallback;
    }
    BOOL (*sendMessage)(id, SEL) = (void *)objc_msgSend;
    return sendMessage(receiver, selector);
}

static void DPPLoadLaunchServices(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *frameworkPaths = @[
            @"/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices",
            @"/System/Library/Frameworks/CoreServices.framework/CoreServices",
            @"/System/Library/PrivateFrameworks/MobileCoreServices.framework/MobileCoreServices"
        ];

        for (NSString *path in frameworkPaths) {
            if (dlopen(path.fileSystemRepresentation, RTLD_LAZY | RTLD_GLOBAL) != NULL &&
                NSClassFromString(@"LSApplicationWorkspace") != Nil) {
                break;
            }
        }
    });
}

static BOOL DPPIsThirdPartyApplicationProxy(id proxy) {
    BOOL hasUserType = NO;
    SEL applicationTypeSelector = NSSelectorFromString(@"applicationType");
    if ([proxy respondsToSelector:applicationTypeSelector]) {
        id value = DPPCallObjectMethod(proxy, applicationTypeSelector);
        if (![value isKindOfClass:NSString.class] ||
            [(NSString *)value caseInsensitiveCompare:@"User"] != NSOrderedSame) {
            return NO;
        }
        hasUserType = YES;
    }

    if (!DPPCallBoolMethod(proxy, NSSelectorFromString(@"isInstalled"), YES) ||
        DPPCallBoolMethod(proxy, NSSelectorFromString(@"isPlaceholder"), NO)) {
        return NO;
    }

    NSURL *bundleURL = nil;
    SEL bundleURLSelector = NSSelectorFromString(@"bundleURL");
    if ([proxy respondsToSelector:bundleURLSelector]) {
        id value = DPPCallObjectMethod(proxy, bundleURLSelector);
        if ([value isKindOfClass:NSURL.class]) {
            bundleURL = value;
        }
    }

    NSString *path = bundleURL.path.stringByStandardizingPath;
    if (path.length > 0) {
        return [path hasPrefix:@"/var/containers/Bundle/Application/"] ||
               [path hasPrefix:@"/private/var/containers/Bundle/Application/"];
    }

    return hasUserType;
}

static NSArray<DPPInstalledApplication *> *DPPInstalledApplications(void) {
    DPPLoadLaunchServices();

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
    if (workspaceClass == Nil || ![workspaceClass respondsToSelector:defaultWorkspaceSelector]) {
        return @[];
    }

    id workspace = DPPCallObjectMethod(workspaceClass, defaultWorkspaceSelector);
    NSMutableArray *applicationProxies = [NSMutableArray array];
    SEL enumerateSelector = NSSelectorFromString(@"enumerateApplicationsOfType:block:");
    if ([workspace respondsToSelector:enumerateSelector]) {
        void (*enumerate)(id, SEL, NSUInteger, void (^)(id)) = (void *)objc_msgSend;
        enumerate(workspace, enumerateSelector, 0, ^(id proxy) {
            if (proxy != nil) {
                [applicationProxies addObject:proxy];
            }
        });
    }

    if (applicationProxies.count == 0) {
        SEL applicationsOfTypeSelector = NSSelectorFromString(@"applicationsOfType:");
        if ([workspace respondsToSelector:applicationsOfTypeSelector]) {
            id (*applicationsOfType)(id, SEL, NSUInteger) = (void *)objc_msgSend;
            id value = applicationsOfType(workspace, applicationsOfTypeSelector, 0);
            if ([value isKindOfClass:NSArray.class]) {
                [applicationProxies addObjectsFromArray:value];
            }
        }
    }

    for (NSString *selectorName in @[@"allInstalledApplications", @"allApplications"]) {
        if (applicationProxies.count > 0) {
            break;
        }
        SEL selector = NSSelectorFromString(selectorName);
        if ([workspace respondsToSelector:selector]) {
            id value = DPPCallObjectMethod(workspace, selector);
            if ([value isKindOfClass:NSArray.class]) {
                [applicationProxies addObjectsFromArray:value];
            }
        }
    }

    if (applicationProxies.count == 0) {
        return @[];
    }

    NSMutableDictionary<NSString *, DPPInstalledApplication *> *applicationsByIdentifier =
        [NSMutableDictionary dictionary];
    NSString *ownBundleIdentifier = NSBundle.mainBundle.bundleIdentifier;

    for (id proxy in applicationProxies) {
        if (!DPPIsThirdPartyApplicationProxy(proxy)) {
            continue;
        }

        NSString *bundleIdentifier = nil;
        for (NSString *selectorName in @[@"bundleIdentifier", @"applicationIdentifier"]) {
            SEL selector = NSSelectorFromString(selectorName);
            if ([proxy respondsToSelector:selector]) {
                id value = DPPCallObjectMethod(proxy, selector);
                if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
                    bundleIdentifier = value;
                    break;
                }
            }
        }

        if (bundleIdentifier.length == 0 ||
            [bundleIdentifier isEqualToString:ownBundleIdentifier] ||
            [bundleIdentifier isEqualToString:@"io.github.minhanhqc3-commits.devicepersona.app"]) {
            continue;
        }

        NSString *displayName = nil;
        SEL localizedNameSelector = NSSelectorFromString(@"localizedName");
        if ([proxy respondsToSelector:localizedNameSelector]) {
            id value = DPPCallObjectMethod(proxy, localizedNameSelector);
            if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
                displayName = value;
            }
        }

        DPPInstalledApplication *application = [[DPPInstalledApplication alloc] init];
        application.displayName = displayName ?: bundleIdentifier;
        application.bundleIdentifier = bundleIdentifier;
        applicationsByIdentifier[bundleIdentifier] = application;
    }

    return [applicationsByIdentifier.allValues sortedArrayUsingComparator:
            ^NSComparisonResult(DPPInstalledApplication *first, DPPInstalledApplication *second) {
        NSComparisonResult result = [first.displayName localizedCaseInsensitiveCompare:second.displayName];
        return result == NSOrderedSame
            ? [first.bundleIdentifier compare:second.bundleIdentifier]
            : result;
    }];
}

@interface DPPApplicationPickerController () <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<DPPInstalledApplication *> *applications;
@property (nonatomic, copy) NSArray<DPPInstalledApplication *> *filteredApplications;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedBundleIdentifiers;
@property (nonatomic, copy) DPPApplicationSelectionHandler selectionHandler;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, assign) BOOL loadingApplications;
@end

@implementation DPPApplicationPickerController

- (instancetype)initWithSelectedBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                                  selectionHandler:(DPPApplicationSelectionHandler)selectionHandler {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _selectedBundleIdentifiers = [NSMutableSet setWithArray:bundleIdentifiers ?: @[]];
        _selectionHandler = [selectionHandler copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Chọn ứng dụng";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                    target:self
                                                    action:@selector(closePicker)];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.placeholder = @"Tìm theo tên hoặc bundle ID";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    self.applications = @[];
    self.filteredApplications = @[];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(loadApplications)
                  forControlEvents:UIControlEventValueChanged];
    [self loadApplications];
}

- (void)loadApplications {
    if (self.loadingApplications) {
        return;
    }

    self.loadingApplications = YES;
    [self updateEmptyState];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<DPPInstalledApplication *> *applications = DPPInstalledApplications();
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            strongSelf.loadingApplications = NO;
            strongSelf.applications = applications;
            [strongSelf.refreshControl endRefreshing];
            [strongSelf updateSearchResultsForSearchController:strongSelf.searchController];
        });
    });
}

- (void)closePicker {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)updateEmptyState {
    if (self.filteredApplications.count > 0) {
        self.tableView.backgroundView = nil;
        return;
    }

    UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    messageLabel.numberOfLines = 0;
    messageLabel.textAlignment = NSTextAlignmentCenter;
    messageLabel.textColor = UIColor.secondaryLabelColor;
    messageLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    if (self.loadingApplications) {
        messageLabel.text = @"Đang đọc danh sách ứng dụng…";
    } else if (self.searchController.searchBar.text.length > 0) {
        messageLabel.text = @"Không tìm thấy ứng dụng phù hợp.";
    } else {
        messageLabel.text = @"Không tìm thấy ứng dụng người dùng. Kéo xuống để thử lại hoặc nhập bundle ID thủ công.";
    }
    messageLabel.frame = CGRectInset(self.tableView.bounds, 32.0, 32.0);
    self.tableView.backgroundView = messageLabel;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if (query.length == 0) {
        self.filteredApplications = self.applications;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:
            ^BOOL(DPPInstalledApplication *application, NSDictionary *bindings) {
                (void)bindings;
                return [application.displayName localizedCaseInsensitiveContainsString:query] ||
                       [application.bundleIdentifier localizedCaseInsensitiveContainsString:query];
            }];
        self.filteredApplications = [self.applications filteredArrayUsingPredicate:predicate];
    }

    [self.tableView reloadData];
    [self updateEmptyState];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.filteredApplications.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return [NSString stringWithFormat:@"ỨNG DỤNG NGƯỜI DÙNG (%lu)",
            (unsigned long)self.applications.count];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return @"Dấu ✓ cho biết ứng dụng sẽ dùng profile DevicePersona sau khi được đóng hẳn và mở lại.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const reuseIdentifier = @"InstalledApplication";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:reuseIdentifier];
        cell.textLabel.adjustsFontForContentSizeCategory = YES;
        cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        cell.detailTextLabel.numberOfLines = 1;
    }

    DPPInstalledApplication *application = self.filteredApplications[indexPath.row];
    cell.textLabel.text = application.displayName;
    cell.detailTextLabel.text = application.bundleIdentifier;
    cell.accessoryType = [self.selectedBundleIdentifiers containsObject:application.bundleIdentifier]
        ? UITableViewCellAccessoryCheckmark
        : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    DPPInstalledApplication *application = self.filteredApplications[indexPath.row];
    if ([self.selectedBundleIdentifiers containsObject:application.bundleIdentifier]) {
        [self.selectedBundleIdentifiers removeObject:application.bundleIdentifier];
    } else {
        [self.selectedBundleIdentifiers addObject:application.bundleIdentifier];
    }

    NSArray<NSString *> *selected = [self.selectedBundleIdentifiers.allObjects
        sortedArrayUsingSelector:@selector(compare:)];
    if (self.selectionHandler != nil) {
        self.selectionHandler(selected);
    }

    [tableView reloadRowsAtIndexPaths:@[indexPath]
                     withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end
