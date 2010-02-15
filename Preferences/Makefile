APPLICATION_NAME = Preferences
APP_ID = jp.ashikase.backgrounder

Preferences_BUNDLE_NAME = Backgrounder
Preferences_CFLAGS = -std=gnu99 -DMAX_PAGES=9
Preferences_OBJC_FILES = main.m \
						 ApplicationCell.m \
						 ApplicationListController.m \
						 Application.m \
						 AppSpecificPrefsController.m \
						 BlacklistedApplicationsController.m \
						 ControlController.m \
						 DocumentationController.m \
						 EnabledApplicationsController.m \
						 GlobalPrefsController.m \
						 HtmlDocController.m \
						 Preferences.m \
						 RootController.m
Preferences_CFLAGS = -DAPP_ID=\"$(APP_ID)\"
Preferences_LDFLAGS = -lactivator
Preferences_FRAMEWORKS = UIKit CoreGraphics
Preferences_PRIVATE_FRAMEWORKS = SpringBoardServices

include ../framework/makefiles/common.mk
include ../framework/makefiles/application.mk
