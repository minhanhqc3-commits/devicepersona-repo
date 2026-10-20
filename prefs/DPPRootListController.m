#import "DPPRootListController.h"
#import "DPPApplicationPickerController.h"
#import "DPPDiagnosticsController.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <Cephei/HBPreferences.h>
#import <dispatch/dispatch.h>
#import <stdint.h>
#import <stdlib.h>

static NSString *const DPPrefsDomain = @"io.github.minhanhqc3-commits.devicepersona";

static HBPreferences *DPPreferenceStore(void) {
    static HBPreferences *preferences;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        preferences = [[HBPreferences alloc] initWithIdentifier:DPPrefsDomain];
    });
    return preferences;
}

static NSSet<NSString *> *DPPProfilePreferenceKeys(void) {
    static NSSet<NSString *> *keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = [NSSet setWithArray:@[
            @"deviceName", @"deviceModel", @"localizedModel", @"systemName",
            @"systemVersion", @"vendorIdentifier", @"localeIdentifier",
            @"preferredLanguages", @"timeZoneIdentifier", @"carrierName",
            @"mobileCountryCode", @"mobileNetworkCode", @"isoCountryCode",
            @"carrierAllowsVOIP", @"productType", @"hardwareModel"
        ]];
    });
    return keys;
}

static NSDictionary *DPPStoredActiveProfile(void) {
    id value = [DPPreferenceStore() objectForKey:@"activeProfile"];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSDictionary *DPPSanitizedProfile(NSDictionary *profile) {
    if (![profile isKindOfClass:NSDictionary.class]) {
        return @{};
    }

    NSMutableDictionary *sanitized = [NSMutableDictionary dictionary];
    for (NSString *key in DPPProfilePreferenceKeys()) {
        id value = profile[key];
        if (value != nil) {
            sanitized[key] = value;
        }
    }
    return sanitized.copy;
}

static id DPPReadProfileValue(NSString *key) {
    id value = DPPStoredActiveProfile()[key];
    return value != nil ? value : [DPPreferenceStore() objectForKey:key];
}

static void DPPWriteProfileValue(NSString *key, id value) {
    id storedValue = value ?: @"";
    NSMutableDictionary *profile = [DPPSanitizedProfile(DPPStoredActiveProfile()) mutableCopy];
    profile[key] = storedValue;

    // The dictionary is the atomic snapshot used by 0.4.0 and later. The
    // legacy key is also kept in sync so a downgrade can read the latest value.
    [DPPreferenceStore() setObject:profile.copy forKey:@"activeProfile"];
    [DPPreferenceStore() setObject:storedValue forKey:key];
}

static void DPPWriteProfile(NSDictionary *profile) {
    NSDictionary *sanitized = DPPSanitizedProfile(profile);
    for (NSString *key in DPPProfilePreferenceKeys()) {
        [DPPreferenceStore() removeObjectForKey:key];
    }
    [DPPreferenceStore() setObject:sanitized forKey:@"activeProfile"];
    [sanitized enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        (void)stop;
        [DPPreferenceStore() setObject:value forKey:key];
    }];
}

static NSDictionary *DPPCurrentProfile(void) {
    NSMutableDictionary *profile = [NSMutableDictionary dictionary];
    for (NSString *key in DPPProfilePreferenceKeys()) {
        id value = DPPReadProfileValue(key);
        if (value != nil) {
            profile[key] = value;
        }
    }
    return profile.copy;
}

static id DPPRandomObject(NSArray *values) {
    if (values.count == 0) {
        return nil;
    }
    return values[arc4random_uniform((uint32_t)values.count)];
}

@implementation DPPRootListController

- (void)presentDelayedStatusWithTitle:(NSString *)title message:(NSString *)message {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf.view.window == nil) {
            return;
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [strongSelf presentViewController:alert animated:YES completion:nil];
    });
}

- (NSArray<NSString *> *)selectedBundleIdentifiers {
    id configuredTargets = [DPPreferenceStore() objectForKey:@"targetBundleIDs"];
    if ([configuredTargets isKindOfClass:NSArray.class]) {
        return configuredTargets;
    }

    if (![configuredTargets isKindOfClass:NSString.class]) {
        return @[];
    }

    NSMutableOrderedSet<NSString *> *identifiers = [NSMutableOrderedSet orderedSet];
    NSCharacterSet *whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    for (NSString *candidate in [(NSString *)configuredTargets componentsSeparatedByString:@","]) {
        NSString *trimmed = [candidate stringByTrimmingCharactersInSet:whitespace];
        if (trimmed.length > 0) {
            [identifiers addObject:trimmed];
        }
    }
    return identifiers.array;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root"
                                                 target:self
                                                 bundle:[NSBundle bundleForClass:self.class]];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (key.length == 0) {
        return specifier.properties[@"default"];
    }

    id value = [DPPProfilePreferenceKeys() containsObject:key]
        ? DPPReadProfileValue(key)
        : [DPPreferenceStore() objectForKey:key];
    return value ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (key.length == 0) {
        return;
    }

    if ([DPPProfilePreferenceKeys() containsObject:key]) {
        DPPWriteProfileValue(key, value);
    } else {
        [DPPreferenceStore() setObject:value forKey:key];
    }
}

- (void)generateVendorIdentifier {
    NSString *identifier = NSUUID.UUID.UUIDString;
    DPPWriteProfileValue(@"vendorIdentifier", identifier);
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DevicePersona"
                                                                   message:@"Đã tạo IDFV mới. Hãy đóng hẳn rồi mở lại ứng dụng mục tiêu."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)randomizeProfile {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Tạo profile ngẫu nhiên?"
                         message:@"Các trường profile hiện tại sẽ được thay bằng một bộ thông tin nhất quán cho iOS 15. Danh sách ứng dụng, trạng thái bật tweak và tùy chọn phần cứng nâng cao sẽ được giữ nguyên."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Tạo mới"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [weakSelf applyRandomProfile];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyRandomProfile {
    // These product/board pairs all belong to iPhones that support the iOS
    // 15.8.x branch. Selecting a tuple keeps hw.machine and hw.model aligned.
    NSArray<NSDictionary *> *deviceProfiles = @[
        @{@"name": @"iPhone 6s", @"productType": @"iPhone8,1", @"hardwareModel": @"N71AP"},
        @{@"name": @"iPhone 6s Plus", @"productType": @"iPhone8,2", @"hardwareModel": @"N66AP"},
        @{@"name": @"iPhone SE (thế hệ 1)", @"productType": @"iPhone8,4", @"hardwareModel": @"N69AP"},
        @{@"name": @"iPhone 7", @"productType": @"iPhone9,1", @"hardwareModel": @"D10AP"},
        @{@"name": @"iPhone 7 Plus", @"productType": @"iPhone9,2", @"hardwareModel": @"D11AP"}
    ];

    NSArray<NSDictionary *> *regionalProfiles = @[
        @{@"name": @"Việt Nam / Viettel", @"locale": @"vi_VN", @"languages": @"vi-VN, en-US", @"timeZone": @"Asia/Ho_Chi_Minh", @"carrier": @"Viettel", @"mcc": @"452", @"mnc": @"04", @"iso": @"vn"},
        @{@"name": @"Việt Nam / VinaPhone", @"locale": @"vi_VN", @"languages": @"vi-VN, en-US", @"timeZone": @"Asia/Ho_Chi_Minh", @"carrier": @"VinaPhone", @"mcc": @"452", @"mnc": @"02", @"iso": @"vn"},
        @{@"name": @"Việt Nam / MobiFone", @"locale": @"vi_VN", @"languages": @"vi-VN, en-US", @"timeZone": @"Asia/Ho_Chi_Minh", @"carrier": @"MobiFone", @"mcc": @"452", @"mnc": @"01", @"iso": @"vn"},
        @{@"name": @"Hoa Kỳ / T-Mobile", @"locale": @"en_US", @"languages": @"en-US, es-US", @"timeZone": @"America/New_York", @"carrier": @"T-Mobile", @"mcc": @"310", @"mnc": @"260", @"iso": @"us"},
        @{@"name": @"Nhật Bản / NTT DOCOMO", @"locale": @"ja_JP", @"languages": @"ja-JP, en-US", @"timeZone": @"Asia/Tokyo", @"carrier": @"NTT DOCOMO", @"mcc": @"440", @"mnc": @"10", @"iso": @"jp"},
        @{@"name": @"Singapore / Singtel", @"locale": @"en_SG", @"languages": @"en-SG, en-US", @"timeZone": @"Asia/Singapore", @"carrier": @"Singtel", @"mcc": @"525", @"mnc": @"01", @"iso": @"sg"},
        @{@"name": @"Vương quốc Anh / EE", @"locale": @"en_GB", @"languages": @"en-GB, en-US", @"timeZone": @"Europe/London", @"carrier": @"EE", @"mcc": @"234", @"mnc": @"30", @"iso": @"gb"}
    ];

    NSDictionary *device = DPPRandomObject(deviceProfiles);
    NSDictionary *region = DPPRandomObject(regionalProfiles);
    NSString *deviceName = [NSString stringWithFormat:@"iPhone-%06u", arc4random_uniform(1000000)];
    NSString *systemVersion = UIDevice.currentDevice.systemVersion ?: @"15.8.8";

    NSDictionary *profile = @{
        @"deviceName": deviceName,
        @"deviceModel": @"iPhone",
        @"localizedModel": @"iPhone",
        @"systemName": @"iOS",
        @"systemVersion": systemVersion,
        @"vendorIdentifier": NSUUID.UUID.UUIDString,
        @"localeIdentifier": region[@"locale"],
        @"preferredLanguages": region[@"languages"],
        @"timeZoneIdentifier": region[@"timeZone"],
        @"carrierName": region[@"carrier"],
        @"mobileCountryCode": region[@"mcc"],
        @"mobileNetworkCode": region[@"mnc"],
        @"isoCountryCode": region[@"iso"],
        @"carrierAllowsVOIP": @YES,
        @"productType": device[@"productType"],
        @"hardwareModel": device[@"hardwareModel"]
    };

    DPPWriteProfile(profile);
    [self reloadSpecifiers];

    NSString *summary = [NSString stringWithFormat:
        @"%@\n%@ / %@\niOS %@ · %@\n%@ · %@-%@\n\nĐã tạo tên máy và IDFV mới. Hãy đóng hẳn rồi mở lại ứng dụng mục tiêu.",
        device[@"name"], device[@"productType"], device[@"hardwareModel"],
        systemVersion, region[@"locale"], region[@"carrier"], region[@"mcc"], region[@"mnc"]];
    [self presentDelayedStatusWithTitle:@"Đã tạo profile" message:summary];
}

- (void)showDiagnostics {
    BOOL enabled = [[DPPreferenceStore() objectForKey:@"enabled"] boolValue];
    BOOL advanced = [[DPPreferenceStore() objectForKey:@"advancedHardwareEnabled"] boolValue];
    DPPDiagnosticsController *controller = [[DPPDiagnosticsController alloc]
        initWithProfile:DPPCurrentProfile()
        enabled:enabled
        targetBundleIdentifiers:[self selectedBundleIdentifiers]
        advancedHardwareEnabled:advanced];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)backupProfile {
    [self.view endEditing:YES];
    NSDictionary *profile = DPPCurrentProfile();
    if (profile.count == 0) {
        UIAlertController *emptyAlert = [UIAlertController
            alertControllerWithTitle:@"Chưa có profile"
                             message:@"Hãy nhập hoặc tạo profile trước khi sao lưu."
                      preferredStyle:UIAlertControllerStyleAlert];
        [emptyAlert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil]];
        [self presentViewController:emptyAlert animated:YES completion:nil];
        return;
    }

    id existingBackup = [DPPreferenceStore() objectForKey:@"profileBackup"];
    if ([existingBackup isKindOfClass:NSDictionary.class]) {
        UIAlertController *confirm = [UIAlertController
            alertControllerWithTitle:@"Ghi đè bản sao lưu?"
                             message:@"DevicePersona chỉ giữ một bản sao profile cục bộ."
                      preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Hủy"
                                                    style:UIAlertActionStyleCancel
                                                  handler:nil]];
        __weak typeof(self) weakSelf = self;
        [confirm addAction:[UIAlertAction actionWithTitle:@"Ghi đè"
                                                    style:UIAlertActionStyleDestructive
                                                  handler:^(__unused UIAlertAction *action) {
            [weakSelf storeProfileBackup:profile];
        }]];
        [self presentViewController:confirm animated:YES completion:nil];
        return;
    }

    [self storeProfileBackup:profile];
}

- (void)storeProfileBackup:(NSDictionary *)profile {
    NSDictionary *backup = @{
        @"profile": profile.copy,
        @"createdAt": @([NSDate.date timeIntervalSince1970])
    };
    [DPPreferenceStore() setObject:backup forKey:@"profileBackup"];

    [self presentDelayedStatusWithTitle:@"Đã sao lưu profile"
                                message:@"Bản sao được lưu cục bộ trên iPhone và không gồm danh sách ứng dụng hay trạng thái bật tweak."];
}

- (void)restoreProfile {
    [self.view endEditing:YES];
    id storedBackup = [DPPreferenceStore() objectForKey:@"profileBackup"];
    NSDictionary *backup = [storedBackup isKindOfClass:NSDictionary.class] ? storedBackup : nil;
    id storedProfile = backup[@"profile"];
    NSDictionary *profile = [storedProfile isKindOfClass:NSDictionary.class] ? storedProfile : nil;
    if (profile.count == 0) {
        UIAlertController *missingAlert = [UIAlertController
            alertControllerWithTitle:@"Không có bản sao lưu"
                             message:@"Hãy dùng “Sao lưu profile” trước."
                      preferredStyle:UIAlertControllerStyleAlert];
        [missingAlert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                         style:UIAlertActionStyleDefault
                                                       handler:nil]];
        [self presentViewController:missingAlert animated:YES completion:nil];
        return;
    }

    NSString *dateText = @"không rõ thời gian";
    id timestamp = backup[@"createdAt"];
    if ([timestamp respondsToSelector:@selector(doubleValue)]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
        dateText = [formatter stringFromDate:date] ?: dateText;
    }

    UIAlertController *confirm = [UIAlertController
        alertControllerWithTitle:@"Khôi phục profile?"
                         message:[NSString stringWithFormat:@"Bản sao lưu: %@. Profile hiện tại sẽ được thay thế; phạm vi ứng dụng và các công tắc được giữ nguyên.", dateText]
                  preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Hủy"
                                                style:UIAlertActionStyleCancel
                                              handler:nil]];
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Khôi phục"
                                                style:UIAlertActionStyleDefault
                                              handler:^(__unused UIAlertAction *action) {
        DPPWriteProfile(profile);
        [weakSelf reloadSpecifiers];
        [weakSelf presentDelayedStatusWithTitle:@"Đã khôi phục profile"
                                        message:@"Hãy đóng hẳn rồi mở lại ứng dụng mục tiêu để nạp cấu hình đã khôi phục."];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)resetProfile {
    [self.view endEditing:YES];
    UIAlertController *confirm = [UIAlertController
        alertControllerWithTitle:@"Xóa profile DevicePersona?"
                         message:@"Chỉ các giá trị thay thế của DevicePersona bị xóa. Dữ liệu và keychain của ứng dụng mục tiêu không bị đụng tới. Bản sao lưu cục bộ vẫn được giữ."
                  preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Hủy"
                                                style:UIAlertActionStyleCancel
                                              handler:nil]];
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Xóa profile"
                                                style:UIAlertActionStyleDestructive
                                              handler:^(__unused UIAlertAction *action) {
        for (NSString *key in DPPProfilePreferenceKeys()) {
            [DPPreferenceStore() removeObjectForKey:key];
        }
        // Keep the complete active snapshot readable until all fallback keys
        // are gone, then remove it as the final reset operation.
        [DPPreferenceStore() removeObjectForKey:@"activeProfile"];
        [weakSelf reloadSpecifiers];
        [weakSelf presentDelayedStatusWithTitle:@"Đã xóa profile"
                                        message:@"Danh sách ứng dụng, các công tắc và bản sao lưu vẫn được giữ. Hãy đóng hẳn rồi mở lại ứng dụng mục tiêu."];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)openApplicationPicker {
    __weak typeof(self) weakSelf = self;
    DPPApplicationPickerController *picker =
        [[DPPApplicationPickerController alloc]
            initWithSelectedBundleIdentifiers:[self selectedBundleIdentifiers]
            selectionHandler:^(NSArray<NSString *> *bundleIdentifiers) {
                NSString *value = [bundleIdentifiers componentsJoinedByString:@", "];
                [DPPreferenceStore() setObject:value forKey:@"targetBundleIDs"];
                [weakSelf reloadSpecifiers];
            }];
    [self.navigationController pushViewController:picker animated:YES];
}

@end

