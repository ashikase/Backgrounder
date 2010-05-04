APPLICATION_NAME = Preferences
APP_ID = jp.ashikase.backgrounder

Preferences_BUNDLE_NAME = Backgrounder
Preferences_OBJC_FILES = main.m \
						 ApplicationCell.m \
						 ApplicationPickerController.m \
						 Application.m \
						 DocumentationController.m \
						 HtmlDocController.m \
						 OverridesController.m \
						 Preferences.m \
						 PreferencesController.m \
						 RootController.m \
						 ToggleButton.m
Preferences_CFLAGS = -std=gnu99 -DAPP_ID=\"$(APP_ID)\"
Preferences_LDFLAGS = -lactivator
Preferences_FRAMEWORKS = UIKit CoreGraphics
Preferences_PRIVATE_FRAMEWORKS = GraphicsServices SpringBoardServices

include ../framework/makefiles/common.mk
include ../framework/makefiles/application.mk
