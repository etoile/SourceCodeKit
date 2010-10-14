include $(GNUSTEP_MAKEFILES)/common.make

# We reset PROJECT_DIR provided by etoile.make to match the subproject since 
# etoile.make doesn't detect and handle such embedded project
PROJECT_DIR = $(CURDIR)

#
# Library
#
VERSION = 0.1
FRAMEWORK_NAME = IDEKit

${FRAMEWORK_NAME}_OBJC_FILES = \
	IDESyntaxHighlighter.m\
	IDETextTypes.m

${FRAMEWORK_NAME}_HEADER_FILES = \
	IDESyntaxHighlighter.h\
	IDETextTypes.h

${FRAMEWORK_NAME}_OBJCFLAGS = -fobjc-nonfragile-abi
${FRAMEWORK_NAME}_CPPFLAGS = -I`llvm-config --src-root`/tools/clang/include/ -DIDEKIT_INTERNAL
${FRAMEWORK_NAME}_LDFLAGS = -L`llvm-config --libdir` -lclang

CC=clang

include $(GNUSTEP_MAKEFILES)/framework.make
-include ../../etoile.make
#-include ../../documentation.make
