PKG_ROOT=/opt/iPhone/sys
SUB_PATH=/files/Platforms/iPhone/build/Users/saurik/mobilesubstrate

name = Backgrounder
target = arm-apple-darwin9-

all: $(name).dylib $(control)

clean:
	rm -f $(name).dylib

$(name).dylib: Backgrounder.mm SimplePopup.mm
	$(target)g++ -dynamiclib -ggdb -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -init _BackgrounderInitialize -lobjc -framework CoreFoundation -framework Foundation -framework UIKit -framework GraphicsServices -F${PKG_ROOT}/System/Library/PrivateFrameworks -I$(SUB_PATH) -L$(SUB_PATH) -lsubstrate

.PHONY: all clean
