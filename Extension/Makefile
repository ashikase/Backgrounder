TWEAK_NAME = Backgrounder
APP_ID = jp.ashikase.backgrounder

Backgrounder_OBJCC_FILES = main.mm \
						   ApplicationHooks.mm \
						   BackgrounderActivator.mm \
						   SimplePopup.mm \
						   SpringBoardHooks.mm
Backgrounder_CFLAGS = -F$(SYSROOT)/System/Library/CoreServices -DAPP_ID=\"$(APP_ID)\"
Backgrounder_LDFLAGS = -lactivator
Backgrounder_FRAMEWORKS = UIKit CoreGraphics
Backgrounder_PRIVATE_FRAMEWORKS = GraphicsServices

# NOTE: For some unknown reason, optimization flag -O2 causes fallbackToNative
#       check to fail in ApplicationHooks' applicationSuspend: method.
OPTFLAG = -O1

include ../framework/makefiles/common.mk
include ../framework/makefiles/tweak.mk
