NAME = Backgrounder

# These paths must be changed to match the compilation environment
SYS_PATH = /opt/iPhone/sys
SUB_PATH = /files/Platforms/iPhone/Projects/Others/saurik/mobilesubstrate

CXX = arm-apple-darwin9-g++
CXXFLAGS = -g0 -O2 -Wall -Werror -I$(SUB_PATH) -IClasses
LDFLAGS = -lobjc \
		  -framework CoreFoundation \
		  -framework Foundation \
		  -framework UIKit \
		  -framework GraphicsServices \
		  -framework CoreGraphics \
		  -F$(SYS_PATH)/System/Library/PrivateFrameworks \
		  -L$(SUB_PATH) -lsubstrate

SRCS = \
	   main.mm \
	   Classes/ApplicationHooks.mm \
	   Classes/SimplePopup.mm \
	   Classes/SpringBoardHooks.mm \
	   Classes/TaskMenuPopup.mm

all: $(NAME).dylib $(control)

clean:
	rm -f $(NAME).dylib

# Replace 'iphone' with the IP or hostname of your device
install:
	ssh root@iphone rm -f /Library/MobileSubstrate/DynamicLibraries/$(NAME).{dylib,plist}
	scp $(NAME).dylib $(NAME).plist root@iphone:/Library/MobileSubstrate/DynamicLibraries/

$(NAME).dylib: $(SRCS)
	$(CXX) -dynamiclib $(CXXFLAGS) -o $@ $(filter %.mm,$^) -init _$(NAME)Initialize $(LDFLAGS)

.PHONY: all clean
