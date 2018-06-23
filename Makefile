SLUG = VCV_Csound
VERSION = 0.6.0

# linking to libraries
LDFLAGS += -L "/usr/local/lib/" -lcsound64

SOURCES += $(wildcard src/*.cpp)

DISTRIBUTABLES += $(wildcard LICENSE*) res

RACK_DIR ?= ../..
include $(RACK_DIR)/plugin.mk

