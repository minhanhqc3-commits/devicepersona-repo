#import "DPPDiagnosticsController.h"
#import <sys/sysctl.h>
#import <stdlib.h>

static NSString *DPPDisplayValue(id value) {
    if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
        return value;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value boolValue] ? @"Có" : @"Không";
    }
    return @"Chưa đặt";
}

static NSString *DPPSystemControlString(const char *name) {
    size_t length = 0;
    if (sysctlbyname(name, NULL, &length, NULL, 0) != 0 || length == 0) {
        return @"Không đọc được";
    }

    char *buffer = calloc(length, sizeof(char));
    if (buffer == NULL) {
        return @"Không đọc được";
    }

    NSString *value = @"Không đọc được";
    if (sysctlbyname(name, buffer, &length, NULL, 0) == 0) {
        NSString *decoded = [NSString stringWithUTF8String:buffer];
        if (decoded.length > 0) {
            value = decoded;
        }
    }
    free(buffer);
    return value;
}

@interface DPPDiagnosticsController ()
@property (nonatomic, copy) NSDictionary<NSString *, id> *profile;
@property (nonatomic, copy) NSArray<NSString *> *targetBundleIdentifiers;
@property (nonatomic, assign) BOOL tweakEnabled;
@property (nonatomic, assign) BOOL advancedHardwareEnabled;
@property (nonatomic, copy) NSArray<NSDictionary *> *sections;
@end

@implementation DPPDiagnosticsController

- (instancetype)initWithProfile:(NSDictionary<NSString *, id> *)profile
                         enabled:(BOOL)enabled
         targetBundleIdentifiers:(NSArray<NSString *> *)targetBundleIdentifiers
         advancedHardwareEnabled:(BOOL)advancedHardwareEnabled {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _profile = [profile copy] ?: @{};
        _targetBundleIdentifiers = [targetBundleIdentifiers copy] ?: @[];
        _tweakEnabled = enabled;
        _advancedHardwareEnabled = advancedHardwareEnabled;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Kiểm tra cấu hình";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                    target:self
                                                    action:@selector(closeDiagnostics)];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64.0;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(rebuildSections)
                  forControlEvents:UIControlEventValueChanged];
    [self rebuildSections];
}

- (void)closeDiagnostics {
    [self.navigationController popViewControllerAnimated:YES];
}

- (NSDictionary *)comparisonRowWithTitle:(NSString *)title
                                    real:(id)realValue
                                 profile:(id)profileValue {
    return @{
        @"title": title,
        @"detail": [NSString stringWithFormat:@"Trên máy: %@\nProfile: %@",
                    DPPDisplayValue(realValue), DPPDisplayValue(profileValue)]
    };
}

- (NSDictionary *)profileRowWithTitle:(NSString *)title value:(id)value {
    return @{
        @"title": title,
        @"detail": [NSString stringWithFormat:@"Profile: %@", DPPDisplayValue(value)]
    };
}

- (void)rebuildSections {
    UIDevice *device = UIDevice.currentDevice;
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    NSString *targets = self.targetBundleIdentifiers.count > 0
        ? [self.targetBundleIdentifiers componentsJoinedByString:@"\n"]
        : @"Chưa chọn ứng dụng";
    NSString *configuredCarrier = [NSString stringWithFormat:@"%@ · %@-%@ · %@",
        DPPDisplayValue(self.profile[@"carrierName"]),
        DPPDisplayValue(self.profile[@"mobileCountryCode"]),
        DPPDisplayValue(self.profile[@"mobileNetworkCode"]),
        DPPDisplayValue(self.profile[@"isoCountryCode"])];

    self.sections = @[
        @{
            @"title": @"TRẠNG THÁI",
            @"rows": @[
                @{@"title": @"DevicePersona", @"detail": self.tweakEnabled ? @"Đang bật" : @"Đang tắt"},
                @{@"title": @"Ứng dụng mục tiêu", @"detail": targets},
                @{@"title": @"Mô phỏng phần cứng", @"detail": self.advancedHardwareEnabled ? @"Đang bật" : @"Đang tắt"}
            ],
            @"footer": @"Màn hình cấu hình chạy ngoài ứng dụng mục tiêu; DevicePersona không can thiệp các giá trị “Trên máy” hiển thị ở đây."
        },
        @{
            @"title": @"THIẾT BỊ VÀ HỆ ĐIỀU HÀNH",
            @"rows": @[
                [self comparisonRowWithTitle:@"Tên thiết bị" real:device.name profile:self.profile[@"deviceName"]],
                [self comparisonRowWithTitle:@"Model hiển thị" real:device.model profile:self.profile[@"deviceModel"]],
                [self comparisonRowWithTitle:@"Phiên bản iOS" real:device.systemVersion profile:self.profile[@"systemVersion"]],
                [self comparisonRowWithTitle:@"NSProcessInfo" real:processInfo.operatingSystemVersionString profile:self.profile[@"systemVersion"]],
                [self profileRowWithTitle:@"IDFV thay thế" value:self.profile[@"vendorIdentifier"]]
            ]
        },
        @{
            @"title": @"VÙNG VÀ THỜI GIAN",
            @"rows": @[
                [self comparisonRowWithTitle:@"Locale" real:NSLocale.currentLocale.localeIdentifier profile:self.profile[@"localeIdentifier"]],
                [self comparisonRowWithTitle:@"Ngôn ngữ" real:[NSLocale.preferredLanguages componentsJoinedByString:@", "] profile:self.profile[@"preferredLanguages"]],
                [self comparisonRowWithTitle:@"Múi giờ" real:NSTimeZone.localTimeZone.name profile:self.profile[@"timeZoneIdentifier"]]
            ]
        },
        @{
            @"title": @"PHẦN CỨNG",
            @"rows": @[
                [self comparisonRowWithTitle:@"Product type" real:DPPSystemControlString("hw.machine") profile:self.profile[@"productType"]],
                [self comparisonRowWithTitle:@"Hardware model" real:DPPSystemControlString("hw.model") profile:self.profile[@"hardwareModel"]]
            ],
            @"footer": self.advancedHardwareEnabled
                ? @"Các giá trị profile phần cứng đang có hiệu lực trong ứng dụng mục tiêu."
                : @"Các giá trị profile phần cứng chưa có hiệu lực vì tùy chọn nâng cao đang tắt."
        },
        @{
            @"title": @"NHÀ MẠNG",
            @"rows": @[
                @{@"title": @"Profile nhà mạng", @"detail": configuredCarrier},
                [self profileRowWithTitle:@"Hỗ trợ VoIP" value:self.profile[@"carrierAllowsVOIP"]]
            ],
            @"footer": @"Khi máy không có SIM, một số ứng dụng có thể không nhận được đối tượng CTCarrier để đọc các giá trị này."
        }
    ];

    [self.refreshControl endRefreshing];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return [self.sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return self.sections[section][@"title"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    return self.sections[section][@"footer"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const reuseIdentifier = @"DiagnosticValue";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:reuseIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.adjustsFontForContentSizeCategory = YES;
        cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    }

    NSDictionary *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    cell.textLabel.text = row[@"title"];
    cell.detailTextLabel.text = row[@"detail"];
    return cell;
}

@end
