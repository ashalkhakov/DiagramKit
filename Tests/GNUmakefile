#
# DiagramKitTests: both frameworks' tests, against the frameworks built in
# the tree. The canvas's drive a window: run under Xvfb where there is no
# display (the root GNUmakefile's make check does).
#
#   make run-tests
#
BUNDLE_NAME = DiagramKitTests
DiagramKitTests_STANDARD_INSTALL = no

include ../scripts/gnustep.make
include $(GNUSTEP_MAKEFILES)/common.make

DiagramKitTests_OBJC_FILES = $(sort $(wildcard *.m))
DiagramKitTests_NEEDS_GUI = yes

DK_LIBS = $(call DK_FRAMEWORK_LIB,DiagramKit,DiagramKit) $(call DK_FRAMEWORK_LIB,DiagramKitUI,DiagramKitUI)
DiagramKitTests_INCLUDE_DIRS = -I$(DK_INCLUDE) -I.
ADDITIONAL_LIB_DIRS += $(addprefix -L,$(DK_LIBS))
ADDITIONAL_OBJCFLAGS += -Wall -include $(CURDIR)/../DiagramKitUI/DiagramKitUICompat.h
# Libraries, not linker flags: on Windows the flags are linked whole.
DiagramKitTests_BUNDLE_LIBS += -lDiagramKitUI -lDiagramKit -lXCTest

XCTEST ?= xctest
# Bounded: a modal waiting for an event that never comes would otherwise
# hang the run.
TEST_TIMEOUT ?= 600

include $(GNUSTEP_MAKEFILES)/bundle.make

space := $(empty) $(empty)
.PHONY: run-tests
run-tests: all
	. $(GNUSTEP_MAKEFILES)/GNUstep.sh; \
	$(call DK_RUN_WITH,$(subst $(space),:,$(DK_LIBS))) \
	timeout -s ABRT $(TEST_TIMEOUT) $(XCTEST) "$(GNUSTEP_BUILD_DIR)/$(BUNDLE_NAME).bundle"
