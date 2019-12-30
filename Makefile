TARGET = iphone:13.0:9.0
ARCHS = armv7 arm64 arm64e
export TARGET ARCHS

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ButNobodyCame

ButNobodyCame_FILES = Tweak.xm $(wildcard *.m)
ButNobodyCame_CFLAGS = -fobjc-arc -include macros.h -Wno-unguarded-availability-new -Wno-arc-performSelector-leaks
ButNobodyCame_FRAMEWORKS = AVFoundation UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += bncd
include $(THEOS_MAKE_PATH)/aggregate.mk
