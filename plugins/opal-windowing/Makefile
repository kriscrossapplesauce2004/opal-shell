# Builds against the installed Hyprland headers (pkg-config hyprland). Rebuild after every Hyprland update.
ifeq ($(CXX),g++)
    EXTRA_FLAGS = --no-gnu-unique
else
    EXTRA_FLAGS =
endif

CXXFLAGS ?= -O2
CXXFLAGS += -shared -fPIC -std=c++2b -Wno-c++11-narrowing
INCLUDES = `pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon`

TARGET = opal-windowing.so

all: $(TARGET)

$(TARGET): main.cpp
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $(EXTRA_FLAGS) $(INCLUDES) $^ -o $@

clean:
	rm -f ./$(TARGET)

.PHONY: all clean
