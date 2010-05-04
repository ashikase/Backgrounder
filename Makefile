SUBPROJECTS = Extension Preferences Updater
export ADDITIONAL_CFLAGS += -I../Common

include framework/makefiles/common.mk
include framework/makefiles/aggregate.mk
