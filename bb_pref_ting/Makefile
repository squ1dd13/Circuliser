include $(THEOS)/makefiles/common.mk
GO_EASY_ON_ME = 1
ARCHS = arm64 arm64e
TARGET = iphone:11.2:11.2
BUNDLE_NAME = bb_pref_ting

bb_pref_ting_FILES = BPTRootListController.xm BPTVisualizationSettingsController.mm SQPrefBannerAnimatedView.m BPTCreditsListController.mm BPTPositionSettingsController.mm BPTMiscSettingsController.mm
bb_pref_ting_INSTALL_PATH = /Library/PreferenceBundles
bb_pref_ting_FRAMEWORKS = UIKit AVFoundation
bb_pref_ting_PRIVATE_FRAMEWORKS = Preferences PreferencesUI
bb_pref_ting_CFLAGS = -fobjc-arc -std=c++17 -stdlib=libc++ -Wno-unused-function -Wno-arc-performSelector-leaks
bb_pref_ting_LIBRARIES += mryipc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/bb_pref_ting.plist$(ECHO_END)
