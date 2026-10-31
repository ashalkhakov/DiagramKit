#
# DiagramKitUI.framework on GNUstep: the AppKit surface and the canvas.
# Links DiagramKit, built first, in the tree.
#
FRAMEWORK_NAME = DiagramKitUI

include ../scripts/gnustep.make
include $(GNUSTEP_MAKEFILES)/common.make

# <DiagramKitUI/X.h> from the tree (gnustep.make's DK_LINK_HEADERS).
DK_LINKED := $(shell $(call DK_LINK_HEADERS,DiagramKitUI,$(CURDIR)))

DiagramKitUI_OBJC_FILES = $(sort $(wildcard *.m))
DiagramKitUI_HEADER_FILES = $(filter-out DiagramKitUICompat.h,$(sort $(wildcard *.h)))
DiagramKitUI_INCLUDE_DIRS = -I$(DK_INCLUDE) -I.
DiagramKitUI_LIB_DIRS = -L$(call DK_FRAMEWORK_LIB,DiagramKit,DiagramKit)
DiagramKitUI_LIBRARIES_DEPEND_UPON = -lDiagramKit $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) -lm
# AppKit's newer names, by the ones gnustep-gui has.
ADDITIONAL_OBJCFLAGS += -Wall -include $(CURDIR)/DiagramKitUICompat.h

# Windows: DIAGRAMKITUI_EXPORT is "export" while it is built (see DiagramKit's).
ifneq ($(DK_WINDOWS),)
DiagramKitUI_CPPFLAGS += "-DDIAGRAMKITUI_EXPORT=__declspec(dllexport) extern"
endif

include $(GNUSTEP_MAKEFILES)/framework.make
