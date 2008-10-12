NAME = Backgrounder

# These paths must be changed to match the compilation environment
SYS_PATH = /opt/iPhone/sys
SUB_PATH = /files/Platforms/iPhone/build/Users/saurik/mobilesubstrate

CXX = arm-apple-darwin9-g++
CXXFLAGS = -ggdb -O2 -Wall -Werror -I$(SUB_PATH) 
LDFLAGS = -lobjc \
		  -framework CoreFoundation \
		  -framework Foundation \
		  -framework UIKit \
		  -framework GraphicsServices \
		  -framework CoreGraphics \
		  -F$(SYS_PATH)/System/Library/PrivateFrameworks \
		  -L$(SUB_PATH) -lsubstrate

SRCS = \
	ApplicationHooks.mm \
	main.mm \
	SimplePopup.mm \
	SpringBoardHooks.mm \
	TaskMenuPopup.mm

all: $(NAME).dylib $(control)

clean:
	rm -f $(NAME).dylib

$(NAME).dylib: $(SRCS)
	$(CXX) -dynamiclib $(CXXFLAGS) -o $@ $(filter %.mm,$^) -init _$(NAME)Initialize $(LDFLAGS)

.PHONY: all clean
