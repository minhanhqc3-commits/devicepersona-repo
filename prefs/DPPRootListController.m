#import "DPPRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CFPreferences.h>

static CFStringRef const DPPrefsDomain = CFSTR("io.github.minhanhqc3-commits.devicepersona");

@implementation DPPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (key.length == 0) {
        return specifier.properties[@"default"];
    }

    CFPreferencesSynchronize(DPPrefsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    id value = CFBridgingRelease(CFPreferencesCopyValue(
        (__bridge CFStringRef)key,
        DPPrefsDomain,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    ));
    return value ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (key.length == 0) {
        return;
    }

    CFPreferencesSetValue(
        (__bridge CFStringRef)key,
        (__bridge CFPropertyListRef)value,
        DPPrefsDomain,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    );
    CFPreferencesSynchronize(DPPrefsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}

- (void)generateVendorIdentifier {
    NSString *identifier = NSUUID.UUID.UUIDString;
    CFPreferencesSetValue(
        CFSTR("vendorIdentifier"),
        (__bridge CFStringRef)identifier,
        DPPrefsDomain,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    );
    CFPreferencesSynchronize(DPPrefsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DevicePersona"
                                                                   message:@"Đã tạo IDFV mới. Hãy đóng hẳn rồi mở lại ứng dụng mục tiêu."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

