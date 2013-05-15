include $(GNUSTEP_MAKEFILES)/common.make

VERSION = 0.1
FRAMEWORK_NAME = SourceCodeKit

ifeq ($(test), yes)
  BUNDLE_NAME = ${FRAMEWORK_NAME}
endif

${FRAMEWORK_NAME}_OBJC_FILES = \
	SCKCodeCompletionResult.m\
	SCKClangSourceFile.m\
	SCKIntrospection.m\
	SCKSourceCollection.m\
	SCKSourceFile.m\
	SCKSyntaxHighlighter.m\
	SCKTextTypes.m

${BUNDLE_NAME}_OBJC_FILES += \
	Tests/ParsingTestFiles/AB.m\
	Tests/TestClangParsing.m\
	Tests/TestCommon.m

${FRAMEWORK_NAME}_HEADER_FILES = \
	SourceCodeKit.h\
	SCKCodeCompletionResult.h\
	SCKIntrospection.h\
	SCKSourceCollection.h\
	SCKSourceFile.h\
	SCKSyntaxHighlighter.h\
	SCKTextTypes.h

${FRAMEWORK_NAME}_RESOURCE_FILES = \
	Resources/DefaultArguments.plist

${BUNDLE_NAME}_RESOURCE_FILES += \
	Tests/ParsingTestFiles/AB.h\
	Tests/ParsingTestFiles/AB.m

${FRAMEWORK_NAME}_OBJCFLAGS = -fobjc-nonfragile-abi -fblocks -fobjc-arc
${FRAMEWORK_NAME}_CPPFLAGS = -I`llvm-config --src-root`/tools/clang/include/ -I`llvm-config --includedir` -DSCKKIT_INTERNAL
${FRAMEWORK_NAME}_LDFLAGS += -L`llvm-config --libdir` -lclang -lstdc++ -lEtoileFoundation
${BUNDLE_NAME}_LDFLAGS += -lUnitKit

CC=clang
#CFLAGS += -load=/home/theraven/llvm/Debug+Asserts/lib/libGNUObjCRuntime.so -gnu-objc

ifeq ($(test), yes)
  include $(GNUSTEP_MAKEFILES)/bundle.make
else
  include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include ../../etoile.make
-include etoile.make
#-include ../../documentation.make
