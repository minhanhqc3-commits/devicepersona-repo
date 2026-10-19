ARCHS = arm64
TARGET = iphone:clang:latest:15.0

INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DevicePersona

DevicePersona_FILES = Tweak.xm
DevicePersona_CFLAGS = -fobjc-arc -Wall -Wextra
DevicePersona_FRAMEWORKS = Foundation UIKit CoreTelephony
DevicePersona_EXTRA_FRAMEWORKS = Cephei

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

