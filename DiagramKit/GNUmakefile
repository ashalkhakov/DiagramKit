#
# DiagramKit.framework on GNUstep: drawing, layout and routing, Foundation
# only.
#
FRAMEWORK_NAME = DiagramKit

include ../scripts/gnustep.make
include $(GNUSTEP_MAKEFILES)/common.make

# <DiagramKit/X.h> from the tree (gnustep.make's DK_LINK_HEADERS).
DK_LINKED := $(shell $(call DK_LINK_HEADERS,DiagramKit,$(CURDIR)))

DiagramKit_OBJC_FILES = $(sort $(wildcard *.m))
DiagramKit_HEADER_FILES = $(sort $(wildcard *.h))
DiagramKit_INCLUDE_DIRS = -I$(DK_INCLUDE) -I.
DiagramKit_LIBRARIES_DEPEND_UPON = $(FND_LIBS) $(OBJC_LIBS) -lm
ADDITIONAL_OBJCFLAGS += -Wall

# Windows: a DLL exports what it marks, and once the runtime marks its
# classes, its C constants and functions must be marked too: DIAGRAMKIT_EXPORT
# (in its headers) is "export" while it is built, an import elsewhere.
ifneq ($(DK_WINDOWS),)
DiagramKit_CPPFLAGS += "-DDIAGRAMKIT_EXPORT=__declspec(dllexport) extern"
endif

include $(GNUSTEP_MAKEFILES)/framework.make
