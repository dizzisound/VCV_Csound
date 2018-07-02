SLUG = VCV_Csound
VERSION = 0.6.1

RACK_DIR ?= ../..

CSOUND_INCLUDE ?= /usr/local/csound/include/csound
CSOUND_LIBRARY ?= /usr/local/csound/lib/

FLAGS +=
CFLAGS +=
CXXFLAGS +=

include $(RACK_DIR)/arch.mk

# linking to libraries
LDFLAGS += -L "/usr/local/lib/" -lcsound64

ifeq ($(ARCH), win)
	FLAGS += -DUSE_DOUBLE -I$(CSOUND_INCLUDE)
	CXXFLAGS += -I $(CSOUND_INCLUDE)
	LDFLAGS +=  -L"$(CSOUND_LIBRARY)" -lcsound64
else
	LDFLAGS += -L"$(CSOUND_LIBRARY)" -lcsound64
endif

SOURCES += $(wildcard src/*.cpp)

DISTRIBUTABLES += $(wildcard LICENSE*) res csd

include $(RACK_DIR)/plugin.mk
