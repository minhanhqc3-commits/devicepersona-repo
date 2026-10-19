#import "DPPRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <Cephei/HBPreferences.h>
#import <dispatch/dispatch.h>

static NSString *const DPPrefsDomain = @"io.github.minhanhqc3-commits.devicepersona";

static HBPreferences *DPPreferenceStore(void) {
    static HBPreferences *preferences;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        preferences = [[HBPreferences alloc] initWithIdentifier:DPPrefsDomain];
    });
    return preferences;
}

@implementation DPPRootListController

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

    id value = [DPPreferenceStore() objectForKey:key];
    return value ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (key.length == 0) {
        return;
    }

    [DPPreferenceStore() setObject:value forKey:key];
}

- (void)generateVendorIdentifier {
    NSString *identifier = NSUUID.UUID.UUIDString;
    [DPPreferenceStore() setObject:identifier forKey:@"vendorIdentifier"];
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DevicePersona"
                                                                   message:@"Đã tạo IDFV mới. Hãy đóng hẳn rồi mở lại ứng dụng mục tiêu."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

