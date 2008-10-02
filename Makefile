PKG_ROOT=/opt/iPhone/sys
SUB_PATH=/files/Platforms/iPhone/build/Users/saurik/mobilesubstrate
MSG_PATH=/files/Platforms/iPhone/build/SpringBoard/Tweaks/MsgSendLogger

name = Backgrounder
target = arm-apple-darwin9-

all: $(name).dylib $(control)

clean:
	rm -f $(name).dylib

strip:
	$(target)strip $(name).dylib

$(name).dylib: Backgrounder.mm
	$(target)g++ -dynamiclib -ggdb -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -init _BackgrounderInitialize -lobjc -framework CoreFoundation -framework Foundation -framework UIKit -framework GraphicsServices -F${PKG_ROOT}/System/Library/PrivateFrameworks -I$(SUB_PATH) -L$(SUB_PATH) -lsubstrate -L$(MSG_PATH) -lmsgsend_logger

.PHONY: all clean strip
