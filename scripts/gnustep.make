#
# What the GNUstep makefiles share; each includes it before common.make.
#
# Everything is built under build/gnustep/, out of the source tree: Xcode's
# synchronized folders would otherwise pick up the objects and dependency
# files as sources.
#
# <Framework/X.h> must reach the very file a quoted "X.h" does, or #import
# sees two headers (gnustep-make copies a framework's headers). So
# build/gnustep/include/<Framework> links to the framework's source
# folder, and everything that includes a framework from the tree puts
# $(DK_INCLUDE) first.
#
DK_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
DK_BUILD := $(DK_ROOT)/build/gnustep
DK_INCLUDE := $(DK_BUILD)/include

# This makefile's own build folder: build/gnustep/<path from the root>.
override GNUSTEP_BUILD_DIR := $(DK_BUILD)/$(patsubst $(DK_ROOT)/%,%,$(abspath $(CURDIR)))

# Where a framework built in the tree keeps its library: $(call DK_FRAMEWORK_LIB,<dir>,<Name>).
# Windows lays a framework out flat: its DLL and import library at its top.
ifeq ($(OS),Windows_NT)
DK_FRAMEWORK_LIB = $(DK_BUILD)/$(1)/$(2).framework
DK_WINDOWS = yes
else
DK_FRAMEWORK_LIB = $(DK_BUILD)/$(1)/$(2).framework/Versions/Current
DK_WINDOWS =
endif
# A test run with the tree's libraries found: $(call DK_RUN_WITH,<dirs, :-separated>).
DK_RUN_WITH = LD_LIBRARY_PATH="$(1)$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}" PATH="$(1):$$PATH"

# The include link for a framework, made as its makefile is read (before
# make -j compiles anything that needs it):
#   DK_LINKED := $(shell $(call DK_LINK_HEADERS,<Name>,<source folder>))
# On Windows a directory junction, made when it is not there yet: MSYS2's
# ln -s copies the folder, and the copy's headers are other files to
# #import. A junction needs no privilege.
ifeq ($(OS),Windows_NT)
DK_LINK_HEADERS = mkdir -p $(DK_INCLUDE) && { [ -e $(DK_INCLUDE)/$(1) ] \
  || cmd //c "mklink /J $$(cygpath -w $(DK_INCLUDE)/$(1)) $$(cygpath -w $(2))" > /dev/null; }
else
DK_LINK_HEADERS = mkdir -p $(DK_INCLUDE) && ln -sfn $(2) $(DK_INCLUDE)/$(1)
endif

OBJC_RUNTIME_LIB = ng
RUNTIME_VERSION = gnustep-2.0
GS_WITH_ARC = 1
