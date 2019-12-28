TARGET = iphone:13.0:9.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ButNobodyCame

ButNobodyCame_FILES = Tweak.x $(wildcard *.m)
ButNobodyCame_CFLAGS = -fobjc-arc -include macros.h -Wno-unguarded-availability-new
ButNobodyCame_FRAMEWORKS = AVFoundation UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
