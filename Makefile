TARGET = iphone:11.2:9.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ButNobodyCame

ButNobodyCame_FILES = Tweak.x $(wildcard *.m)
ButNobodyCame_CFLAGS = -fobjc-arc
ButNobodyCame_LIBRARIES = rocketbootstrap
ButNobodyCame_FRAMEWORKS = AVFoundation UIKit Foundation
ButNobodyCame_PRIVATE_FRAMEWORKS = AppSupport

include $(THEOS_MAKE_PATH)/tweak.mk
