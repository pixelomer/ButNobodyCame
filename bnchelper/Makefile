include $(THEOS)/makefiles/common.mk

TOOL_NAME = bnchelper

bnchelper_FILES = main.m
bnchelper_CFLAGS = -fobjc-arc -include ../macros.h
bnchelper_INSTALL_PATH = /usr/local/bin
bnchelper_CODESIGN_FLAGS = -Sentitlements.xml

include $(THEOS_MAKE_PATH)/tool.mk
