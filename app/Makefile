ARCHS = arm64
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = DevicePersonaApp

DevicePersonaApp_BUNDLE_NAME = DevicePersona
DevicePersonaApp_INSTALL_PATH = /Applications
DevicePersonaApp_FILES = main.m DPPAppDelegate.m ../prefs/DPPRootListController.m
DevicePersonaApp_CFLAGS = -fobjc-arc -Wall -Wextra -I../prefs
DevicePersonaApp_FRAMEWORKS = Foundation UIKit
DevicePersonaApp_PRIVATE_FRAMEWORKS = Preferences
DevicePersonaApp_EXTRA_FRAMEWORKS = Cephei
DevicePersonaApp_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
