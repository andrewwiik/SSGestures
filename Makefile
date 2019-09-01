export ADDITIONAL_CFLAGS += -I$(THEOS_PROJECT_DIR)/headers -fobjc-arc

ifeq ($(SIMULATOR),1)
	export TARGET = simulator:latest:11.0
else
	export TARGET = iphone:latest:11.0
endif

ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SSGestures
SSGestures_CFLAGS = -I$(THEOS_PROJECT_DIR)/headers -fobjc-arc
SSGestures_FILES = $(wildcard *.m) $(wildcard *.xm)

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 ScreenshotServicesService"
	install.exec "killall -9 SpringBoard"
