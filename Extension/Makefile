TWEAK_NAME = Backgrounder
APP_ID = jp.ashikase.backgrounder

Backgrounder_OBJCC_FILES = main.mm \
						   ApplicationHooks.mm \
						   SpringBoardHooks.mm \
						   SimplePopup.mm
Backgrounder_CFLAGS = -F$(SYSROOT)/System/Library/CoreServices -DAPP_ID=\"$(APP_ID)\"
Backgrounder_FRAMEWORKS = UIKit CoreGraphics

include ../framework/makefiles/common.mk
include ../framework/makefiles/tweak.mk
