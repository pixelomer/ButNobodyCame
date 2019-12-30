include $(THEOS)/makefiles/common.mk

TOOL_NAME = bncd

bncd_FILES = main.m
bncd_CFLAGS = -fobjc-arc -include ../macros.h
bncd_INSTALL_PATH = /usr/local/bin
bncd_CODESIGN_FLAGS = -Sentitlements.xml

include $(THEOS_MAKE_PATH)/tool.mk
