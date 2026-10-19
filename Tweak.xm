#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTCarrier.h>
#import <Cephei/HBPreferences.h>
#import <dispatch/dispatch.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <errno.h>
#import <string.h>

static NSString *const DPPrefsDomain = @"io.github.minhanhqc3-commits.devicepersona";
static HBPreferences *DPPreferencesStore;
static NSDictionary *DPPreferences;
static BOOL DPProcessEnabled;

static NSString *DPString(NSString *key) {
    id value = DPPreferences[key];
    if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
        return value;
    }
    return nil;
}

static BOOL DPBool(NSString *key, BOOL fallback) {
    id value = DPPreferences[key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}

static BOOL DPIsEligibleThirdPartyProcess(void) {
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
    if (bundleIdentifier.length == 0) {
        return NO;
    }

    // Only regular third-party App Store/sideloaded app containers are eligible.
    // This excludes SpringBoard, Preferences, daemons, and system applications
    // even though the Substrate filter causes this dylib to be considered broadly.
    NSString *bundlePath = NSBundle.mainBundle.bundlePath.stringByStandardizingPath;
    return [bundlePath hasPrefix:@"/var/containers/Bundle/Application/"] ||
           [bundlePath hasPrefix:@"/private/var/containers/Bundle/Application/"];
}

static NSArray<NSString *> *DPTargetBundleIdentifiers(void) {
    id configuredTargets = DPPreferences[@"targetBundleIDs"];
    if ([configuredTargets isKindOfClass:NSArray.class]) {
        return configuredTargets;
    }

    if (![configuredTargets isKindOfClass:NSString.class]) {
        return @[];
    }

    NSMutableArray<NSString *> *targets = [NSMutableArray array];
    NSCharacterSet *whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    for (NSString *candidate in [(NSString *)configuredTargets componentsSeparatedByString:@","]) {
        NSString *trimmed = [candidate stringByTrimmingCharactersInSet:whitespace];
        if (trimmed.length > 0) {
            [targets addObject:trimmed];
        }
    }
    return targets.copy;
}

static BOOL DPShouldEnableForCurrentProcess(void) {
    if (!DPBool(@"enabled", NO)) {
        return NO;
    }

    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
    if (bundleIdentifier.length == 0) {
        return NO;
    }

    if (!DPIsEligibleThirdPartyProcess()) {
        return NO;
    }

    return [DPTargetBundleIdentifiers() containsObject:bundleIdentifier];
}

static void DPLoadConfiguration(void) {
    // HBPreferences reads the mobile user's tweak preferences even when this
    // dylib runs inside an App Store application's sandbox.
    DPPreferencesStore = [[HBPreferences alloc] initWithIdentifier:DPPrefsDomain];
    NSDictionary *loaded = DPPreferencesStore.dictionaryRepresentation;
    DPPreferences = [loaded isKindOfClass:NSDictionary.class] ? loaded.copy : @{};
    DPProcessEnabled = DPShouldEnableForCurrentProcess();
}

static NSUUID *DPUUID(NSString *key) {
    NSString *value = DPString(key);
    return value ? [[NSUUID alloc] initWithUUIDString:value] : nil;
}

static int DPWriteSysctlString(NSString *value, void *oldValue, size_t *oldLength) {
    NSData *utf8 = [value dataUsingEncoding:NSUTF8StringEncoding];
    size_t requiredLength = utf8.length + 1;

    if (oldValue == NULL) {
        if (oldLength != NULL) {
            *oldLength = requiredLength;
        }
        return 0;
    }

    if (oldLength == NULL) {
        errno = EFAULT;
        return -1;
    }

    if (*oldLength < requiredLength) {
        size_t availableLength = *oldLength;
        if (availableLength > 0) {
            size_t characterCount = MIN(utf8.length, availableLength - 1);
            memcpy(oldValue, utf8.bytes, characterCount);
            ((char *)oldValue)[characterCount] = '\0';
        }
        *oldLength = requiredLength;
        errno = ENOMEM;
        return -1;
    }

    memcpy(oldValue, utf8.bytes, utf8.length);
    ((char *)oldValue)[utf8.length] = '\0';
    *oldLength = requiredLength;
    return 0;
}

%group DeviceIdentity

%hook UIDevice

- (NSString *)name {
    return DPString(@"deviceName") ?: %orig;
}

- (NSString *)model {
    return DPString(@"deviceModel") ?: %orig;
}

- (NSString *)localizedModel {
    return DPString(@"localizedModel") ?: %orig;
}

- (NSString *)systemName {
    return DPString(@"systemName") ?: %orig;
}

- (NSString *)systemVersion {
    return DPString(@"systemVersion") ?: %orig;
}

- (NSUUID *)identifierForVendor {
    return DPUUID(@"vendorIdentifier") ?: %orig;
}

%end

%end

%group LocaleAndTime

%hook NSLocale

+ (NSLocale *)currentLocale {
    NSString *identifier = DPString(@"localeIdentifier");
    return identifier ? [[NSLocale alloc] initWithLocaleIdentifier:identifier] : %orig;
}

+ (NSLocale *)autoupdatingCurrentLocale {
    NSString *identifier = DPString(@"localeIdentifier");
    return identifier ? [[NSLocale alloc] initWithLocaleIdentifier:identifier] : %orig;
}

+ (NSArray<NSString *> *)preferredLanguages {
    NSString *configured = DPString(@"preferredLanguages");
    if (!configured) {
        return %orig;
    }

    NSMutableArray<NSString *> *languages = [NSMutableArray array];
    NSCharacterSet *whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    for (NSString *candidate in [configured componentsSeparatedByString:@","]) {
        NSString *trimmed = [candidate stringByTrimmingCharactersInSet:whitespace];
        if (trimmed.length > 0) {
            [languages addObject:trimmed];
        }
    }
    return languages.count > 0 ? languages.copy : %orig;
}

%end

%hook NSTimeZone

+ (NSTimeZone *)localTimeZone {
    NSTimeZone *zone = [NSTimeZone timeZoneWithName:DPString(@"timeZoneIdentifier") ?: @""];
    return zone ?: %orig;
}

+ (NSTimeZone *)defaultTimeZone {
    NSTimeZone *zone = [NSTimeZone timeZoneWithName:DPString(@"timeZoneIdentifier") ?: @""];
    return zone ?: %orig;
}

+ (NSTimeZone *)systemTimeZone {
    NSTimeZone *zone = [NSTimeZone timeZoneWithName:DPString(@"timeZoneIdentifier") ?: @""];
    return zone ?: %orig;
}

%end

%end

%group Carrier

%hook CTCarrier

- (NSString *)carrierName {
    return DPString(@"carrierName") ?: %orig;
}

- (NSString *)mobileCountryCode {
    return DPString(@"mobileCountryCode") ?: %orig;
}

- (NSString *)mobileNetworkCode {
    return DPString(@"mobileNetworkCode") ?: %orig;
}

- (NSString *)isoCountryCode {
    return DPString(@"isoCountryCode") ?: %orig;
}

- (BOOL)allowsVOIP {
    return DPPreferences[@"carrierAllowsVOIP"] ? DPBool(@"carrierAllowsVOIP", YES) : %orig;
}

%end


%end


%group AdvancedHardware

%hookf(int, uname, struct utsname *name) {
    int result = %orig;
    NSString *productType = DPString(@"productType");
    if (result == 0 && name != NULL && productType.length > 0) {
        const char *replacement = productType.UTF8String;
        if (replacement != NULL) {
            strlcpy(name->machine, replacement, sizeof(name->machine));
        }
    }
    return result;
}

%hookf(int, sysctlbyname, const char *name, void *oldValue, size_t *oldLength, void *newValue, size_t newLength) {
    if (newValue == NULL && name != NULL) {
        if (strcmp(name, "hw.machine") == 0) {
            NSString *productType = DPString(@"productType");
            if (productType.length > 0) {
                return DPWriteSysctlString(productType, oldValue, oldLength);
            }
        } else if (strcmp(name, "hw.model") == 0) {
            NSString *hardwareModel = DPString(@"hardwareModel");
            if (hardwareModel.length > 0) {
                return DPWriteSysctlString(hardwareModel, oldValue, oldLength);
            }
        }
    }
    return %orig;
}

%end

%ctor {
    @autoreleasepool {
        if (!DPIsEligibleThirdPartyProcess()) {
            return;
        }

        DPLoadConfiguration();
        if (!DPProcessEnabled) {
            return;
        }

        %init(DeviceIdentity);
        %init(LocaleAndTime);
        %init(Carrier);

        if (DPBool(@"advancedHardwareEnabled", NO)) {
            %init(AdvancedHardware);
        }
    }
}


