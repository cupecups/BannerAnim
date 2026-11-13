TARGET := iphone:clang:latest:16.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BannerAnim
BannerAnim_FILES = Tweak.x
BannerAnim_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk