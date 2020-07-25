THEOS_DEVICE_IP = ...
GO_EASY_ON_ME = 1
ARCHS = arm64 arm64e
TARGET = iphone:11.2:11.2
#FINALPACKAGE = 1

include ~/theos/makefiles/common.mk

# There was a time...
TWEAK_NAME = BounceBass

BounceBass_FILES = tweak.xm server.xm

# @_@ more warnings lol
BounceBass_CFLAGS = -fobjc-arc -Ofast -Wno-format-security -Wno-auto-var-id -Wno-deprecated -Wno-deprecated-declarations -Wno-unused-function
BounceBass_FRAMEWORKS = Accelerate 
BounceBass_PRIVATE_FRAMEWORKS = MediaRemote
BounceBass_CFLAGS += -std=c++17 -stdlib=libc++ 
BounceBass_LIBRARIES = c++ mryipc

after-install::
	install.exec "killall -9 backboardd"

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += bb_pref_ting
include $(THEOS_MAKE_PATH)/aggregate.mk
