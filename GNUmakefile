#
# DiagramKit on GNUstep: the frameworks (DiagramKit, DiagramKitUI) and their
# tests. Built out of the tree, under build/gnustep/ (scripts/gnustep.make).
#
#   make                        both frameworks
#   make check                  the tests (under Xvfb when there is no
#                               display: the canvas's drive a window)
#   make install DESTDIR=<dir>  the frameworks, into the GNUstep prefix
#
ifeq ($(GNUSTEP_MAKEFILES),)
  $(error Set GNUSTEP_MAKEFILES (source GNUstep.sh).)
endif

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = DiagramKit
SUBPROJECTS = DiagramKit DiagramKitUI Tests

include $(GNUSTEP_MAKEFILES)/aggregate.make

XVFB = $(if $(DISPLAY),,$(shell command -v xvfb-run >/dev/null 2>&1 && echo "xvfb-run -a -s '-screen 0 1280x1024x24'"))
check::
	$(XVFB) $(MAKE) -C Tests run-tests
