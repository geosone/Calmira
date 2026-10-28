GDI ?= ../gdi
FPC ?= fpc
HOST_CC ?= cc
BUILD_DIR ?= build
FPC_TEST_DIR := $(BUILD_DIR)/tests/fpc
FPC_WIN16_ROOT ?= $(BUILD_DIR)/toolchains/fpc-win16
FPC_WIN16_VERSION ?= 3.3.1
FPC_WIN16 := $(FPC_WIN16_ROOT)/lib/fpc/$(FPC_WIN16_VERSION)/ppcross8086
FPC_WIN16_UNITS := $(FPC_WIN16_ROOT)/lib/fpc/$(FPC_WIN16_VERSION)/units/win16/rtl
# Huge data model: each unit's initialized data, VMTs and RTTI live in FAR_DATA
# segments, leaving DGROUP to the stack and local heap. Large-model PPUs are kept
# in a separate directory and must never be mixed with huge-model ones.
WIN16_MEMORY_MODEL ?= Huge
WIN16_GUI_FLAGS := -Wh -Wm$(WIN16_MEMORY_MODEL)
FPC_WIN16_GUI_RTL := $(BUILD_DIR)/win16-rtl/units-$(WIN16_MEMORY_MODEL)
FPC_FIXED_ROOT ?= $(BUILD_DIR)/toolchains/fpc-class-pointer
FPC_WIN16_FIXED := $(FPC_FIXED_ROOT)/ppcross8086
DRIVE_PROBE_DIR := $(BUILD_DIR)/drive-probe
WINFILE_PORT_SRC := vendor/reference/microsoft-winfile
WINFILE_PORT_DIR := $(BUILD_DIR)/winfile-port
WATCOM ?= /opt/watcom
WATCOM_BIN ?= $(WATCOM)/binl64
WCC ?= $(WATCOM_BIN)/wcc
OMF_BIN_DIR ?= $(BUILD_DIR)/toolchains/bin
JWASM ?= $(OMF_BIN_DIR)/jwasm
JWLINK ?= $(OMF_BIN_DIR)/jwlink
CTL3D_SRC := vendor/build-deps/open386max-ctl3d
CTL3D_DIR := $(BUILD_DIR)/win16/ctl3d
UPX_SRC := vendor/build-deps/upx
UPX_BUILD := $(BUILD_DIR)/tools/upx
UPX ?= $(UPX_BUILD)/upx
SEVENZIP_SRC := vendor/reference/7zip
SEVENZIP_PIN := 9128b80e3a471108678e2b3ec3c985861c8d7b0f
SEVENZIP_HOST_DIR := $(abspath $(BUILD_DIR)/tools/7zip-reference)
SEVENZIP_HOST_MAKEFILE ?= cmpl_clang.mak
# Gentoo's tested LLVM slot; fall back to PATH on other systems. Override both
# compilers (and BUILD_DIR when switching toolchains) for a different host.
SEVENZIP_HOST_CLANG_PREFIX ?= $(if $(wildcard /usr/lib/llvm/22/bin/clang),/usr/lib/llvm/22/bin/,)
SEVENZIP_HOST_CC ?= $(SEVENZIP_HOST_CLANG_PREFIX)clang
SEVENZIP_HOST_CXX ?= $(SEVENZIP_HOST_CLANG_PREFIX)clang++
SEVENZIP_HOST_JOBS ?= 4
CTL3D_EXPORTS = $(shell awk '$$2 ~ /^@[0-9]+$$/ { print "export " $$1 "." substr($$2,2) }' $(CTL3D_SRC)/CTL3DV2.DEF)

.PHONY: all compare verify-sources test fpc-test c-test toolchain-smoke doslfn \
	doslfn-test lfn-probe lfn-probe-test \
	toolchain-info omf-toolchain fpc-win16-toolchain fpc-win16-smoke \
	winfile16 winfile16-core winfile16-core-runtime-test drive-probe \
	win16-helpers ctl3d ctl3d-runtime-test languages calmira upx \
	pack-win16 pack-drive-probe clfn-hook clfn-hook-runtime-test clfn-office-runtime-test window-inventory \
	archive-host archive-host-test archive-dos archive-dos-runtime-test archive-reader-host archive-reader-host-test archive-viewer archive-preview-runtime-test archive-package \
	fpc-win16-gui-rtl fpc-win16-classes-runtime-test archive-package-runtime-test archive-office-runtime-test openlfn openlfn-package openlfn-dist dos-bridge-diagnose package clean

all: test

compare:
	python3 tools/compare_upstreams.py

verify-sources:
	sha256sum -c archives/original/SHA256SUMS

test: fpc-test c-test help-service-test
	python3 -m unittest discover -s tests -p 'test_*.py'

.PHONY: help-service-test
help-service-test: languages
	mkdir -p $(BUILD_DIR)/tests/help-service/units
	$(FPC) -Mdelphi -S2 -Futests/pascal/help_stubs -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/help-service/units -FE$(BUILD_DIR)/tests/help-service \
		tests/pascal/test_help_service.pas
	$(BUILD_DIR)/tests/help-service/test_help_service

c-test:
	mkdir -p $(BUILD_DIR)/tests/c
	$(HOST_CC) -std=c99 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror -pedantic \
		src/portable/lfn_store.c tests/c/test_lfn_store.c -o $(BUILD_DIR)/tests/c/test_lfn_store
	$(BUILD_DIR)/tests/c/test_lfn_store
	$(HOST_CC) -std=c99 -Wall -Wextra -Werror -pedantic \
		src/portable/archive_index.c tests/c/test_archive_index.c -o $(BUILD_DIR)/tests/c/test_archive_index
	$(BUILD_DIR)/tests/c/test_archive_index

languages:
	python3 tools/build_languages.py --output $(BUILD_DIR)/lang

.PHONY: help help-runtime-test
help:
	python3 tools/build_help.py --output $(BUILD_DIR)/help/calmira.hlp

help-runtime-test: help omf-toolchain
	HELP_FILE='$(abspath $(BUILD_DIR)/help/calmira.hlp)' sh tests/dos/test_help_win311.sh

.PHONY: help-path-runtime-test
help-path-runtime-test: help languages fpc-win16-toolchain upx
	FPC_WIN16='$(abspath $(FPC_WIN16))' FPC_WIN16_UNITS='$(abspath $(FPC_WIN16_UNITS))' \
		UPX='$(abspath $(UPX))' HELP_FILE='$(abspath $(BUILD_DIR)/help/calmira.hlp)' \
		sh tests/dos/test_help_path_win311.sh

fpc-test: languages
	mkdir -p $(FPC_TEST_DIR)/units
	$(FPC) -Mdelphi -S2 -Cr -Co -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_runtime_path_text.pas
	$(FPC_TEST_DIR)/test_runtime_path_text
	$(FPC) -Mdelphi -S2 -Cr -Co -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_help_jump.pas
	$(FPC_TEST_DIR)/test_help_jump
	$(FPC) -Mdelphi -S2 -Cr -Co -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_exception_text.pas
	$(FPC_TEST_DIR)/test_exception_text
	$(FPC) -Mdelphi -S2 -Cr -Co -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_legacy_password.pas
	$(FPC_TEST_DIR)/test_legacy_password
	$(FPC) -Mdelphi -S2 -Cr -Co -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_gui_error_buffer.pas
	$(FPC_TEST_DIR)/test_gui_error_buffer
	$(FPC) -Mdelphi -S2 -Cr -Co -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_word_tokens.pas
	$(FPC_TEST_DIR)/test_word_tokens
	$(FPC) -Mdelphi -S2 -Cr -Co -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_color_names.pas
	$(FPC_TEST_DIR)/test_color_names
	$(FPC) -Mdelphi -S2 -Cr -Co -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_bmp_reader.pas
	$(FPC_TEST_DIR)/test_bmp_reader bmp/*.bmp
	python3 tests/bitmap_fixtures.py $(FPC_TEST_DIR)
	$(FPC_TEST_DIR)/test_bmp_reader $(FPC_TEST_DIR)/BITS1.BMP $(FPC_TEST_DIR)/BITS8.BMP $(FPC_TEST_DIR)/BITS24.BMP
	$(FPC) -Mdelphi -S2 -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_drivechange.pas
	$(FPC_TEST_DIR)/test_drivechange
	$(FPC) -Mdelphi -S2 -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_virtual_lfn.pas
	$(FPC_TEST_DIR)/test_virtual_lfn
	$(FPC) -Mdelphi -S2 -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_program_groups.pas
	$(FPC_TEST_DIR)/test_program_groups
	$(FPC) -Mdelphi -S2 -Fu./src/portable -Fu./vcl -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_language_catalog.pas
	$(FPC_TEST_DIR)/test_language_catalog
	$(FPC) -Mdelphi -S2 -Fu./src/portable -Fu./vcl -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_langui.pas
	$(FPC_TEST_DIR)/test_langui

omf-toolchain:
	OMF_BIN_DIR='$(abspath $(OMF_BIN_DIR))' sh tools/build_omf_tools.sh

toolchain-smoke: omf-toolchain
	mkdir -p $(BUILD_DIR)/tests/toolchain
	WATCOM=$(WATCOM) INCLUDE='$(WATCOM)/h:$(WATCOM)/h/win' \
		$(WCC) -q -bt=windows -ml \
		-fo=$(BUILD_DIR)/tests/toolchain/win16_smoke.obj \
		tests/c/win16_smoke.c
	$(JWASM) -q -omf -Fo$(BUILD_DIR)/tests/toolchain/omf_smoke.obj \
		tests/asm/omf_smoke.asm

lfn-probe: omf-toolchain
	mkdir -p $(BUILD_DIR)/dos/lfn
	WATCOM=$(WATCOM) INCLUDE='$(WATCOM)/h' \
		$(WCC) -q -bt=dos -ms -0 -os -s -zq -wx \
		-fo=$(BUILD_DIR)/dos/lfn/lfnprobe.obj src/dos/lfn/lfnprobe.c
	$(JWLINK) option quiet format dos name $(BUILD_DIR)/dos/lfn/LFNPROBE.EXE \
		file $(BUILD_DIR)/dos/lfn/lfnprobe.obj \
		libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286 library clibs \
		option stack=2k

lfn-probe-test: lfn-probe
	tests/dos/test_lfnprobe.sh

doslfn:
	sh tools/fetch_doslfn.sh

doslfn-test: lfn-probe doslfn
	tests/dos/test_doslfn.sh

fpc-win16-toolchain: omf-toolchain
	@if test -x '$(FPC_WIN16)' && test '$(FPC_REBUILD)' != '1'; then \
		printf '%s\n' 'Using installed Win16 FPC: $(FPC_WIN16)'; \
	else \
		WATCOM='$(WATCOM)' OMF_BIN_DIR='$(abspath $(OMF_BIN_DIR))' \
			sh tools/build_fpc_win16.sh; \
	fi

.PHONY: fpc-win16-fixed-compiler win16-class-pointer win16-class-pointer-runtime-test win16-fixed-regression
fpc-win16-fixed-compiler:
	FPC_FIXED_ROOT='$(abspath $(FPC_FIXED_ROOT))' FPC_BOOTSTRAP='$(FPC)' \
		sh tools/build_fpc_class_pointer.sh

# Separate output/PPU trees: never accept old-compiler RTL or cached test units.
win16-fixed-regression: fpc-win16-fixed-compiler
	compiler_profile=$$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["fingerprint"][:20])' \
		'$(abspath $(FPC_FIXED_ROOT))/compiler.json') && \
	$(MAKE) BUILD_DIR='$(BUILD_DIR)/class-pointer/'"$$compiler_profile" \
		FPC_WIN16_ROOT='$(abspath $(FPC_WIN16_ROOT))' \
		FPC_WIN16='$(abspath $(FPC_WIN16_FIXED))' OMF_BIN_DIR='$(abspath $(OMF_BIN_DIR))' \
		win16-class-pointer-runtime-test win16-application-runtime-test win16-application-dialog-runtime-test \
		win16-application-factory-runtime-test win16-application-original-runtime-test \
		win16-application-window-runtime-test win16-application-activation-runtime-test \
		win16-idle-runtime-test win16-application-idle-runtime-test win16-application-exception-runtime-test \
		win16-application-help-runtime-test \
		win16-help-key-runtime-test \
		win16-control-view-runtime-test win16-view-order-runtime-test \
		win16-coordinates-runtime-test \
		win16-children-runtime-test \
		win16-realloc-runtime-test \
		win16-drain-runtime-test win16-application-pump-runtime-test \
		win16-identity-runtime-test \
		win16-screen-runtime-test win16-screen-modal-runtime-test \
		win16-forms-runtime-test win16-dialogs-runtime-test win16-input-query-runtime-test \
		win16-shellapi-runtime-test win16-inifiles-runtime-test win16-menus-runtime-test \
		win16-system-dlls-runtime-test win16-clipbrd-runtime-test win16-radio-runtime-test \
		win16-combobox-runtime-test win16-notebook-runtime-test win16-speedbutton-runtime-test win16-drag-runtime-test win16-spin-runtime-test win16-bevel-runtime-test win16-listbox-runtime-test win16-align-runtime-test win16-parent-runtime-test win16-ownerdraw-runtime-test win16-canvas-context-runtime-test win16-hints-runtime-test win16-minimize-runtime-test win16-grids-runtime-test win16-form-loader-runtime-test win16-outline-runtime-test win16-common-dialogs-runtime-test win16-tab-panel-runtime-test win16-timer-runtime-test win16-dde-runtime-test win16-radio-group-runtime-test win16-file-filter-runtime-test win16-shape-runtime-test win16-form-menu-runtime-test win16-loader-props-runtime-test win16-far-imports-runtime-test win16-delphi-asm-runtime-test \
		win16-dll-runtime-test win16-lfnfuncs-runtime-test \
		win16-cursor-runtime-test win16-cursor-modal-runtime-test \
		win16-form-activation-runtime-test win16-form-resize-runtime-test win16-form-state-runtime-test \
		win16-ui-runtime-test win16-window-runtime-test win16-input-runtime-test \
		win16-paint-runtime-test win16-draw-runtime-test win16-loop-runtime-test \
		win16-modal-loop-runtime-test win16-gui-stdio-runtime-test \
		win16-gui-diagnostics-runtime-test win16-gui-buffer-runtime-test \
		win16-resource-text-runtime-test fpc-win16-classes-runtime-test

win16-class-pointer: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-class-pointer/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-class-pointer/units -FE$(BUILD_DIR)/tests/win16-class-pointer \
		-oGDITEST.EXE tests/pascal/test_win16_class_pointer.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-class-pointer/GDITEST.EXE

win16-class-pointer-runtime-test: win16-class-pointer
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-class-pointer/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-application win16-application-runtime-test win16-application-dialog win16-application-dialog-runtime-test
win16-application: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-application/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-application/units -FE$(BUILD_DIR)/tests/win16-application \
		-oGDITEST.EXE tests/pascal/test_win16_application.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application/GDITEST.EXE

win16-application-runtime-test: win16-application
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-application/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

win16-application-dialog: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-application-dialog/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-application-dialog/units -FE$(BUILD_DIR)/tests/win16-application-dialog \
		-oGDITEST.EXE tests/pascal/test_win16_application_dialog.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application-dialog/GDITEST.EXE

win16-application-dialog-runtime-test: win16-application-dialog
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-application-dialog/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-application-factory win16-application-factory-runtime-test
win16-application-factory: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-application-factory/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-application-factory/units -FE$(BUILD_DIR)/tests/win16-application-factory \
		-oGDITEST.EXE tests/pascal/test_win16_application_factory.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application-factory/GDITEST.EXE

win16-application-factory-runtime-test: win16-application-factory
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-application-factory/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-application-original win16-application-original-runtime-test
win16-application-original: fpc-win16-gui-rtl $(BUILD_DIR)/generated/forms/incsrch_dfm.pas
	mkdir -p $(BUILD_DIR)/tests/win16-application-original/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -Fuvcl \
		-FU$(BUILD_DIR)/tests/win16-application-original/units -FE$(BUILD_DIR)/tests/win16-application-original \
		-oGDITEST.EXE tests/pascal/test_win16_application_original.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application-original/GDITEST.EXE

win16-application-original-runtime-test: win16-application-original
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-application-original/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-application-window win16-application-window-runtime-test
win16-application-window: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-application-window/units $(BUILD_DIR)/tests/win16-application-sender/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -Fusrc \
		-FU$(BUILD_DIR)/tests/win16-application-window/units -FE$(BUILD_DIR)/tests/win16-application-window \
		-oGDITEST.EXE tests/pascal/test_win16_application_window.pas
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc \
		-FU$(BUILD_DIR)/tests/win16-application-sender/units -FE$(BUILD_DIR)/tests/win16-application-sender \
		-oAPPSEND.EXE tests/pascal/application_sender.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application-window/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application-sender/APPSEND.EXE

win16-application-window-runtime-test: win16-application-window
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-application-window/GDITEST.EXE)' \
		GDI_HELPER_EXE='$(abspath $(BUILD_DIR)/tests/win16-application-sender/APPSEND.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-idle win16-idle-runtime-test win16-application-idle win16-application-idle-runtime-test
win16-idle: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-idle/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-idle/units -FE$(BUILD_DIR)/tests/win16-idle \
		-oGDITEST.EXE tests/pascal/test_win16_idle.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-idle/GDITEST.EXE

win16-idle-runtime-test: win16-idle
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-idle/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

win16-application-idle: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-application-idle/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-application-idle/units -FE$(BUILD_DIR)/tests/win16-application-idle \
		-oGDITEST.EXE tests/pascal/test_win16_application_idle.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application-idle/GDITEST.EXE

win16-application-idle-runtime-test: win16-application-idle
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-application-idle/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-application-exception win16-application-exception-runtime-test
win16-application-exception: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-application-exception/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-application-exception/units -FE$(BUILD_DIR)/tests/win16-application-exception \
		-oGDITEST.EXE tests/pascal/test_win16_application_exception.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application-exception/GDITEST.EXE

win16-application-exception-runtime-test: win16-application-exception
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-application-exception/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-application-activation win16-application-activation-runtime-test
.PHONY: win16-application-help win16-application-help-runtime-test
.PHONY: win16-help-key win16-help-key-runtime-test
.PHONY: win16-realloc win16-realloc-runtime-test
win16-realloc: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-realloc/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-realloc/units -FE$(BUILD_DIR)/tests/win16-realloc \
		-oGDITEST.EXE tests/pascal/test_win16_realloc.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-realloc/GDITEST.EXE

win16-realloc-runtime-test: win16-realloc
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-realloc/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-children win16-children-runtime-test
win16-children: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-children/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-children/units -FE$(BUILD_DIR)/tests/win16-children \
		-oGDITEST.EXE tests/pascal/test_win16_children.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-children/GDITEST.EXE

win16-children-runtime-test: win16-children
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-children/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-identity win16-identity-runtime-test win16-identity-package-runtime-test
win16-identity: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-identity/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-identity/units -FE$(BUILD_DIR)/tests/win16-identity \
		-oGDITEST.EXE tests/pascal/test_win16_identity.pas
	python3 tests/bitmap_fixtures.py $(BUILD_DIR)/tests/win16-identity
	$(WATCOM_BIN)/wrc -q -r -bt=windows -i=$(BUILD_DIR)/tests/win16-identity \
		-fo=$(BUILD_DIR)/tests/win16-identity/probe.res tests/pascal/test_win16_identity.rc
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/tests/win16-identity/probe.res $(BUILD_DIR)/tests/win16-identity/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-identity/GDITEST.EXE

win16-identity-runtime-test: win16-identity
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-identity/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

win16-identity-package-runtime-test: win16-identity upx
	IDENTITY_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-identity/GDITEST.EXE)' \
		UPX='$(abspath $(UPX))' sh tests/dos/test_identity_paths_win311.sh

.PHONY: win16-drain win16-drain-runtime-test win16-application-pump win16-application-pump-runtime-test
win16-drain: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-drain/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-drain/units -FE$(BUILD_DIR)/tests/win16-drain \
		-oGDITEST.EXE tests/pascal/test_win16_drain.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-drain/GDITEST.EXE

win16-drain-runtime-test: win16-drain
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-drain/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

win16-application-pump: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-application-pump/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-application-pump/units -FE$(BUILD_DIR)/tests/win16-application-pump \
		-oGDITEST.EXE tests/pascal/test_win16_application_pump.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application-pump/GDITEST.EXE

win16-application-pump-runtime-test: win16-application-pump
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-application-pump/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-coordinates win16-coordinates-runtime-test
win16-coordinates: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-coordinates/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-coordinates/units -FE$(BUILD_DIR)/tests/win16-coordinates \
		-oGDITEST.EXE tests/pascal/test_win16_coordinates.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-coordinates/GDITEST.EXE

win16-coordinates-runtime-test: win16-coordinates
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-coordinates/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-control-view win16-control-view-runtime-test win16-view-order win16-view-order-runtime-test
win16-control-view: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-control-view/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-control-view/units -FE$(BUILD_DIR)/tests/win16-control-view \
		-oGDITEST.EXE tests/pascal/test_win16_control_view.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-control-view/GDITEST.EXE

win16-control-view-runtime-test: win16-control-view
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-control-view/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

win16-view-order: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-view-order/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-view-order/units -FE$(BUILD_DIR)/tests/win16-view-order \
		-oGDITEST.EXE tests/pascal/test_win16_view_order.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-view-order/GDITEST.EXE

win16-view-order-runtime-test: win16-view-order
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-view-order/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

$(BUILD_DIR)/generated/forms/help_context_form.inc: tests/help_context_fixture.py tools/compile_dfm.py
	python3 tests/help_context_fixture.py $@

win16-help-key: fpc-win16-gui-rtl $(BUILD_DIR)/generated/forms/help_context_form.inc help
	mkdir -p $(BUILD_DIR)/tests/win16-help-key/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-Fi$(BUILD_DIR)/generated/forms -FU$(BUILD_DIR)/tests/win16-help-key/units \
		-FE$(BUILD_DIR)/tests/win16-help-key -oGDITEST.EXE tests/pascal/test_win16_help_key.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-help-key/GDITEST.EXE

win16-help-key-runtime-test: win16-help-key
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-help-key/GDITEST.EXE)' \
		GDI_HELP_FILE='$(abspath $(BUILD_DIR)/help/calmira.hlp)' sh tests/dos/test_win16_gdi.sh

win16-application-help: fpc-win16-gui-rtl languages help
	mkdir -p $(BUILD_DIR)/tests/win16-application-help/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-application-help/units -FE$(BUILD_DIR)/tests/win16-application-help \
		-oGDITEST.EXE tests/pascal/test_win16_application_help.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application-help/GDITEST.EXE

win16-application-help-runtime-test: win16-application-help
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-application-help/GDITEST.EXE)' \
		GDI_HELP_FILE='$(abspath $(BUILD_DIR)/help/calmira.hlp)' \
		GDI_CATALOG_DIR='$(abspath $(BUILD_DIR)/lang)' sh tests/dos/test_win16_gdi.sh

win16-application-activation: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-application-activation/units $(BUILD_DIR)/tests/win16-activation-sender/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-application-activation/units -FE$(BUILD_DIR)/tests/win16-application-activation \
		-oGDITEST.EXE tests/pascal/test_win16_application_activation.pas
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-activation-sender/units -FE$(BUILD_DIR)/tests/win16-activation-sender \
		-oAPPSEND.EXE tests/pascal/activation_sender.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-application-activation/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-activation-sender/APPSEND.EXE

win16-application-activation-runtime-test: win16-application-activation
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-application-activation/GDITEST.EXE)' \
		GDI_HELPER_EXE='$(abspath $(BUILD_DIR)/tests/win16-activation-sender/APPSEND.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-form-state win16-form-state-runtime-test
win16-form-state: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-form-state/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-form-state/units -FE$(BUILD_DIR)/tests/win16-form-state \
		-oGDITEST.EXE tests/pascal/test_win16_form_state.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-form-state/GDITEST.EXE

win16-form-state-runtime-test: win16-form-state
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-form-state/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-form-resize win16-form-resize-runtime-test
win16-form-resize: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-form-resize/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-form-resize/units -FE$(BUILD_DIR)/tests/win16-form-resize \
		-oGDITEST.EXE tests/pascal/test_win16_form_resize.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-form-resize/GDITEST.EXE

win16-form-resize-runtime-test: win16-form-resize
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-form-resize/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-form-activation win16-form-activation-runtime-test
win16-form-activation: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-form-activation/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-form-activation/units -FE$(BUILD_DIR)/tests/win16-form-activation \
		-oGDITEST.EXE tests/pascal/test_win16_form_activation.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-form-activation/GDITEST.EXE

win16-form-activation-runtime-test: win16-form-activation
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-form-activation/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-forms win16-forms-runtime-test
win16-forms: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-forms/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-forms/units -FE$(BUILD_DIR)/tests/win16-forms \
		-oGDITEST.EXE tests/pascal/test_win16_forms.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-forms/GDITEST.EXE

win16-forms-runtime-test: win16-forms
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-forms/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-shellapi win16-shellapi-runtime-test
win16-shellapi: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-shellapi/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-shellapi/units -FE$(BUILD_DIR)/tests/win16-shellapi \
		-oGDITEST.EXE tests/pascal/test_win16_shellapi.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-shellapi/GDITEST.EXE

win16-shellapi-runtime-test: win16-shellapi
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-shellapi/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-inifiles win16-inifiles-runtime-test
win16-inifiles: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-inifiles/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-inifiles/units -FE$(BUILD_DIR)/tests/win16-inifiles \
		-oGDITEST.EXE tests/pascal/test_win16_inifiles.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-inifiles/GDITEST.EXE

win16-inifiles-runtime-test: win16-inifiles
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-inifiles/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-menus win16-menus-runtime-test
win16-menus: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-menus/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-menus/units -FE$(BUILD_DIR)/tests/win16-menus \
		-oGDITEST.EXE tests/pascal/test_win16_menus.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-menus/GDITEST.EXE

win16-menus-runtime-test: win16-menus
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-menus/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-system-dlls win16-system-dlls-runtime-test
win16-system-dlls: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-system-dlls/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-system-dlls/units -FE$(BUILD_DIR)/tests/win16-system-dlls \
		-oGDITEST.EXE tests/pascal/test_win16_system_dlls.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-system-dlls/GDITEST.EXE

win16-system-dlls-runtime-test: win16-system-dlls
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-system-dlls/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-clipbrd win16-clipbrd-runtime-test
win16-clipbrd: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-clipbrd/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-clipbrd/units -FE$(BUILD_DIR)/tests/win16-clipbrd \
		-oGDITEST.EXE tests/pascal/test_win16_clipbrd.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-clipbrd/GDITEST.EXE

win16-clipbrd-runtime-test: win16-clipbrd
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-clipbrd/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-radio win16-radio-runtime-test
win16-radio: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-radio/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-radio/units -FE$(BUILD_DIR)/tests/win16-radio \
		-oGDITEST.EXE tests/pascal/test_win16_radio.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-radio/GDITEST.EXE

win16-radio-runtime-test: win16-radio
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-radio/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-combobox win16-combobox-runtime-test
win16-combobox: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-combobox/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-combobox/units -FE$(BUILD_DIR)/tests/win16-combobox \
		-oGDITEST.EXE tests/pascal/test_win16_combobox.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-combobox/GDITEST.EXE

win16-combobox-runtime-test: win16-combobox
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-combobox/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-notebook win16-notebook-runtime-test
win16-notebook: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-notebook/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-notebook/units -FE$(BUILD_DIR)/tests/win16-notebook \
		-oGDITEST.EXE tests/pascal/test_win16_notebook.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-notebook/GDITEST.EXE

win16-notebook-runtime-test: win16-notebook
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-notebook/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-speedbutton win16-speedbutton-runtime-test
win16-speedbutton: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-speedbutton/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-speedbutton/units -FE$(BUILD_DIR)/tests/win16-speedbutton \
		-oGDITEST.EXE tests/pascal/test_win16_speedbutton.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-speedbutton/GDITEST.EXE

.PHONY: win16-listbox win16-listbox-runtime-test
win16-listbox: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-listbox/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-listbox/units -FE$(BUILD_DIR)/tests/win16-listbox \
		-oGDITEST.EXE tests/pascal/test_win16_listbox.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-listbox/GDITEST.EXE

win16-listbox-runtime-test: win16-listbox
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-listbox/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-spin win16-spin-runtime-test
win16-spin: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-spin/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-spin/units -FE$(BUILD_DIR)/tests/win16-spin \
		-oGDITEST.EXE tests/pascal/test_win16_spin.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-spin/GDITEST.EXE

win16-spin-runtime-test: win16-spin
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-spin/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-align win16-align-runtime-test
win16-align: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-align/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-align/units -FE$(BUILD_DIR)/tests/win16-align \
		-oGDITEST.EXE tests/pascal/test_win16_align.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-align/GDITEST.EXE

win16-align-runtime-test: win16-align
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-align/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-canvas-context win16-canvas-context-runtime-test
win16-canvas-context: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-canvas-context/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-canvas-context/units -FE$(BUILD_DIR)/tests/win16-canvas-context \
		-oGDITEST.EXE tests/pascal/test_win16_canvas_context.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-canvas-context/GDITEST.EXE

win16-canvas-context-runtime-test: win16-canvas-context
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-canvas-context/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-hints win16-hints-runtime-test
win16-hints: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-hints/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-hints/units -FE$(BUILD_DIR)/tests/win16-hints \
		-oGDITEST.EXE tests/pascal/test_win16_hints.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-hints/GDITEST.EXE

win16-hints-runtime-test: win16-hints
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-hints/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-minimize win16-minimize-runtime-test
win16-minimize: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-minimize/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable -Fuvcl \
		-FU$(BUILD_DIR)/tests/win16-minimize/units -FE$(BUILD_DIR)/tests/win16-minimize \
		-oGDITEST.EXE tests/pascal/test_win16_minimize.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-minimize/GDITEST.EXE

win16-minimize-runtime-test: win16-minimize
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-minimize/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-grids win16-grids-runtime-test
win16-grids: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-grids/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable -Fusrc -Fuvcl \
		-FU$(BUILD_DIR)/tests/win16-grids/units -FE$(BUILD_DIR)/tests/win16-grids \
		-oGDITEST.EXE tests/pascal/test_win16_grids.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-grids/GDITEST.EXE

win16-grids-runtime-test: win16-grids
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-grids/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-form-loader win16-form-loader-runtime-test
$(BUILD_DIR)/generated/forms/form_loader_probe_dfm.pas: tests/form_loader_fixture.py tests/pascal/form_loader_probe.pas tools/dfm_loader.py tools/compile_dfm.py
	python3 tests/form_loader_fixture.py $@

win16-form-loader: fpc-win16-gui-rtl $(BUILD_DIR)/generated/forms/form_loader_probe_dfm.pas
	mkdir -p $(BUILD_DIR)/tests/win16-form-loader/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-Futests/pascal -Fu$(BUILD_DIR)/generated/forms \
		-FU$(BUILD_DIR)/tests/win16-form-loader/units -FE$(BUILD_DIR)/tests/win16-form-loader \
		-oGDITEST.EXE tests/pascal/test_win16_form_loader.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-form-loader/GDITEST.EXE

win16-form-loader-runtime-test: win16-form-loader
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-form-loader/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-outline win16-outline-runtime-test
win16-outline: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-outline/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -Fuvcl -Fusrc/win16 -Fusrc/portable -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-outline/units -FE$(BUILD_DIR)/tests/win16-outline \
		-oGDITEST.EXE tests/pascal/test_win16_outline.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-outline/GDITEST.EXE

win16-outline-runtime-test: win16-outline
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-outline/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-common-dialogs win16-common-dialogs-runtime-test
win16-common-dialogs: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-common-dialogs/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-common-dialogs/units -FE$(BUILD_DIR)/tests/win16-common-dialogs \
		-oGDITEST.EXE tests/pascal/test_win16_common_dialogs.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-common-dialogs/GDITEST.EXE

win16-common-dialogs-runtime-test: win16-common-dialogs
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-common-dialogs/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-tab-panel win16-tab-panel-runtime-test
win16-tab-panel: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-tab-panel/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fuvcl -Fusrc/win16 -Fusrc/portable -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-tab-panel/units -FE$(BUILD_DIR)/tests/win16-tab-panel \
		-oGDITEST.EXE tests/pascal/test_win16_tab_panel.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-tab-panel/GDITEST.EXE

win16-tab-panel-runtime-test: win16-tab-panel
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-tab-panel/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-timer win16-timer-runtime-test
win16-timer: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-timer/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fuvcl -Fusrc/win16 -Fusrc/portable -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-timer/units -FE$(BUILD_DIR)/tests/win16-timer \
		-oGDITEST.EXE tests/pascal/test_win16_timer.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-timer/GDITEST.EXE

win16-timer-runtime-test: win16-timer
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-timer/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-dde win16-dde-runtime-test
win16-dde: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-dde/units $(BUILD_DIR)/tests/win16-dde-sender/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fuvcl -Fusrc/win16 -Fusrc/portable -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-dde/units -FE$(BUILD_DIR)/tests/win16-dde \
		-oGDITEST.EXE tests/pascal/test_win16_dde.pas
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fusrc/win16 -Fusrc/portable -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-dde-sender/units -FE$(BUILD_DIR)/tests/win16-dde-sender \
		-oAPPSEND.EXE tests/pascal/dde_sender.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-dde/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-dde-sender/APPSEND.EXE

win16-dde-runtime-test: win16-dde
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-dde/GDITEST.EXE)' \
		GDI_HELPER_EXE='$(abspath $(BUILD_DIR)/tests/win16-dde-sender/APPSEND.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-radio-group win16-radio-group-runtime-test
win16-radio-group: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-radio-group/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fuvcl -Fusrc/win16 -Fusrc/portable -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-radio-group/units -FE$(BUILD_DIR)/tests/win16-radio-group \
		-oGDITEST.EXE tests/pascal/test_win16_radio_group.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-radio-group/GDITEST.EXE

win16-radio-group-runtime-test: win16-radio-group
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-radio-group/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-file-filter win16-file-filter-runtime-test
win16-file-filter: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-file-filter/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-file-filter/units -FE$(BUILD_DIR)/tests/win16-file-filter \
		-oGDITEST.EXE tests/pascal/test_win16_file_filter.pas
	$(WATCOM_BIN)/wrc -q -r -bt=windows -fo=$(BUILD_DIR)/tests/win16-file-filter/probe.res tests/pascal/test_win16_file_filter.rc
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/tests/win16-file-filter/probe.res $(BUILD_DIR)/tests/win16-file-filter/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-file-filter/GDITEST.EXE

win16-file-filter-runtime-test: win16-file-filter
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-file-filter/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-shape win16-shape-runtime-test
win16-shape: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-shape/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-shape/units -FE$(BUILD_DIR)/tests/win16-shape \
		-oGDITEST.EXE tests/pascal/test_win16_shape.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-shape/GDITEST.EXE

win16-shape-runtime-test: win16-shape
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-shape/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-form-menu win16-form-menu-runtime-test
win16-form-menu: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-form-menu/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-form-menu/units -FE$(BUILD_DIR)/tests/win16-form-menu \
		-oGDITEST.EXE tests/pascal/test_win16_form_menu.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-form-menu/GDITEST.EXE

win16-form-menu-runtime-test: win16-form-menu
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-form-menu/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: lfnfuncs win16-lfnfuncs win16-lfnfuncs-runtime-test
# Calmira's long-filename library, imported by vcl/lfnutils.pas.
lfnfuncs: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/lfnfuncs/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -Fuvcl -Fu./$(FPC_WIN16_GUI_RTL) \
		-Fusrc -Fusrc/portable -Fusrc/win16 \
		-FU$(BUILD_DIR)/lfnfuncs/units -FE$(BUILD_DIR)/lfnfuncs -oLFNFUNCS.DLL src/lfnfuncs.dpr
	python3 tools/check_win16_budget.py $(BUILD_DIR)/lfnfuncs/LFNFUNCS.DLL

win16-lfnfuncs: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-lfnfuncs/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -Fuvcl -Fu./$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-lfnfuncs/units -FE$(BUILD_DIR)/tests/win16-lfnfuncs \
		-oGDITEST.EXE tests/pascal/test_win16_lfnfuncs.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-lfnfuncs/GDITEST.EXE

win16-lfnfuncs-runtime-test: win16-lfnfuncs lfnfuncs
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-lfnfuncs/GDITEST.EXE)' \
		GDI_EXTRA_FILES='$(abspath $(BUILD_DIR)/lfnfuncs/LFNFUNCS.DLL)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-delphi-asm win16-delphi-asm-runtime-test
# vcl comes before the RTL so that Strings is vcl/strings.pas.
win16-delphi-asm: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-delphi-asm/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -Fuvcl -Fu./$(FPC_WIN16_GUI_RTL) \
		-Fusrc -Fusrc/portable -Fusrc/win16 -Futests/pascal \
		-FU$(BUILD_DIR)/tests/win16-delphi-asm/units -FE$(BUILD_DIR)/tests/win16-delphi-asm \
		-oGDITEST.EXE tests/pascal/test_win16_delphi_asm.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-delphi-asm/GDITEST.EXE

win16-delphi-asm-runtime-test: win16-delphi-asm
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-delphi-asm/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-far-imports win16-far-imports-runtime-test
win16-far-imports: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-far-imports/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Futests/pascal \
		-FU$(BUILD_DIR)/tests/win16-far-imports/units -FE$(BUILD_DIR)/tests/win16-far-imports \
		-oGDITEST.EXE tests/pascal/test_win16_far_imports.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-far-imports/GDITEST.EXE

win16-far-imports-runtime-test: win16-far-imports
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-far-imports/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-dll win16-dll-runtime-test
# A Free Pascal library, imported statically and loaded under a second name.
win16-dll: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-dll/units
	for name in DLLPROBE DLLDYN; do \
		PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
			-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Futests/pascal \
			-FU$(BUILD_DIR)/tests/win16-dll/units -FE$(BUILD_DIR)/tests/win16-dll \
			-o$$name.DLL tests/pascal/dll_probe.pas || exit 1; \
	done
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-dll/units -FE$(BUILD_DIR)/tests/win16-dll \
		-oGDITEST.EXE tests/pascal/test_win16_dll.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-dll/GDITEST.EXE

win16-dll-runtime-test: win16-dll
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-dll/GDITEST.EXE)' \
		GDI_EXTRA_FILES='$(abspath $(BUILD_DIR)/tests/win16-dll/DLLPROBE.DLL) $(abspath $(BUILD_DIR)/tests/win16-dll/DLLDYN.DLL)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-loader-props win16-loader-props-runtime-test
win16-loader-props: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-loader-props/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-loader-props/units -FE$(BUILD_DIR)/tests/win16-loader-props \
		-oGDITEST.EXE tests/pascal/test_win16_loader_props.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-loader-props/GDITEST.EXE

win16-loader-props-runtime-test: win16-loader-props
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-loader-props/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-ownerdraw win16-ownerdraw-runtime-test
win16-ownerdraw: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-ownerdraw/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-ownerdraw/units -FE$(BUILD_DIR)/tests/win16-ownerdraw \
		-oGDITEST.EXE tests/pascal/test_win16_ownerdraw.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-ownerdraw/GDITEST.EXE

win16-ownerdraw-runtime-test: win16-ownerdraw
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-ownerdraw/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-parent win16-parent-runtime-test
win16-parent: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-parent/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-parent/units -FE$(BUILD_DIR)/tests/win16-parent \
		-oGDITEST.EXE tests/pascal/test_win16_parent.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-parent/GDITEST.EXE

win16-parent-runtime-test: win16-parent
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-parent/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-bevel win16-bevel-runtime-test
win16-bevel: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-bevel/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-bevel/units -FE$(BUILD_DIR)/tests/win16-bevel \
		-oGDITEST.EXE tests/pascal/test_win16_bevel.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-bevel/GDITEST.EXE

win16-bevel-runtime-test: win16-bevel
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-bevel/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

win16-speedbutton-runtime-test: win16-speedbutton
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-speedbutton/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-drag win16-drag-runtime-test
win16-drag: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-drag/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-drag/units -FE$(BUILD_DIR)/tests/win16-drag \
		-oGDITEST.EXE tests/pascal/test_win16_drag.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-drag/GDITEST.EXE

win16-drag-runtime-test: win16-drag
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-drag/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-dialogs win16-dialogs-runtime-test
win16-dialogs: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-dialogs/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-dialogs/units -FE$(BUILD_DIR)/tests/win16-dialogs \
		-oGDITEST.EXE tests/pascal/test_win16_dialogs.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-dialogs/GDITEST.EXE

win16-dialogs-runtime-test: win16-dialogs
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-dialogs/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-input-query win16-input-query-runtime-test
win16-input-query: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-input-query/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-input-query/units -FE$(BUILD_DIR)/tests/win16-input-query \
		-oGDITEST.EXE tests/pascal/test_win16_input_query.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-input-query/GDITEST.EXE

win16-input-query-runtime-test: win16-input-query
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-input-query/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-screen win16-screen-runtime-test win16-screen-modal win16-screen-modal-runtime-test
win16-screen: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-screen/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-screen/units -FE$(BUILD_DIR)/tests/win16-screen \
		-oGDITEST.EXE tests/pascal/test_win16_screen.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-screen/GDITEST.EXE

win16-screen-runtime-test: win16-screen
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-screen/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

win16-screen-modal: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-screen-modal/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-screen-modal/units -FE$(BUILD_DIR)/tests/win16-screen-modal \
		-oGDITEST.EXE tests/pascal/test_win16_screen_modal.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-screen-modal/GDITEST.EXE

win16-screen-modal-runtime-test: win16-screen-modal
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-screen-modal/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-cursor win16-cursor-runtime-test
win16-cursor: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-cursor/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-cursor/units -FE$(BUILD_DIR)/tests/win16-cursor \
		-oGDITEST.EXE tests/pascal/test_win16_cursor.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-cursor/GDITEST.EXE

win16-cursor-runtime-test: win16-cursor
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-cursor/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-cursor-modal win16-cursor-modal-runtime-test
win16-cursor-modal: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-cursor-modal/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) -Fusrc/win16 -Fusrc/portable \
		-FU$(BUILD_DIR)/tests/win16-cursor-modal/units -FE$(BUILD_DIR)/tests/win16-cursor-modal \
		-oGDITEST.EXE tests/pascal/test_win16_cursor_modal.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-cursor-modal/GDITEST.EXE

win16-cursor-modal-runtime-test: win16-cursor-modal
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-cursor-modal/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

fpc-win16-smoke: fpc-win16-toolchain
	mkdir -p $(BUILD_DIR)/tests/fpc-win16/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -S2 -CX \
		-Fu./src/portable -Fu./$(FPC_WIN16_UNITS) \
		-FU$(BUILD_DIR)/tests/fpc-win16/units \
		-FE$(BUILD_DIR)/tests/fpc-win16 \
		tests/pascal/test_drivechange.pas
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -S2 -CX \
		-Fu./src/portable -Fu./$(FPC_WIN16_UNITS) \
		-FU$(BUILD_DIR)/tests/fpc-win16/units \
		-FE$(BUILD_DIR)/tests/fpc-win16 \
		tests/pascal/test_virtual_lfn.pas
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -S2 -CX \
		-Fu./src/portable -Fu./$(FPC_WIN16_UNITS) \
		-FU$(BUILD_DIR)/tests/fpc-win16/units \
		-FE$(BUILD_DIR)/tests/fpc-win16 \
		tests/pascal/test_program_groups.pas

fpc-win16-gui-rtl: fpc-win16-toolchain
	FPC_WIN16='$(abspath $(FPC_WIN16))' FPC_WIN16_RTL='$(abspath $(FPC_WIN16_GUI_RTL))' \
		WIN16_MEMORY_MODEL='$(WIN16_MEMORY_MODEL)' sh tools/build_win16_rtl.sh

fpc-win16-classes-runtime-test: fpc-win16-gui-rtl languages
	mkdir -p $(BUILD_DIR)/tests/win16-classes/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/portable -Fuvcl -FU$(BUILD_DIR)/tests/win16-classes/units \
		-FE$(BUILD_DIR)/tests/win16-classes -oRTLTEST.EXE tests/pascal/test_win16_classes.pas
	RTL_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-classes/RTLTEST.EXE)' \
		RTL_CATALOG_DIR='$(abspath $(BUILD_DIR)/lang)' sh tests/dos/test_win16_classes_win311.sh

.PHONY: win16-messages win16-messages-runtime-test
win16-messages: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-messages/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -FU$(BUILD_DIR)/tests/win16-messages/units \
		-FE$(BUILD_DIR)/tests/win16-messages -oMSGTEST.EXE tests/pascal/test_win16_messages.pas

win16-messages-runtime-test: win16-messages
	MESSAGE_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-messages/MSGTEST.EXE)' \
		sh tests/dos/test_win16_messages.sh

.PHONY: win16-gdi win16-gdi-runtime-test
win16-gdi: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-gdi/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-gdi/units \
		-FE$(BUILD_DIR)/tests/win16-gdi -oGDITEST.EXE tests/pascal/test_win16_gdi.pas
	python3 tests/bitmap_fixtures.py $(BUILD_DIR)/tests/win16-gdi
	$(WATCOM_BIN)/wrc -q -r -bt=windows -i=$(BUILD_DIR)/tests/win16-gdi -fo=$(BUILD_DIR)/tests/win16-gdi/probe.res tests/pascal/test_win16_gdi.rc
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/tests/win16-gdi/probe.res $(BUILD_DIR)/tests/win16-gdi/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-gdi/GDITEST.EXE

win16-gdi-runtime-test: win16-gdi
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-gdi/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-graphics win16-graphics-runtime-test
win16-graphics: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-graphics/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -Fuvcl -FU$(BUILD_DIR)/tests/win16-graphics/units \
		-FE$(BUILD_DIR)/tests/win16-graphics -oGDITEST.EXE tests/pascal/test_win16_graphics.pas
	python3 tests/bitmap_fixtures.py $(BUILD_DIR)/tests/win16-graphics
	$(WATCOM_BIN)/wrc -q -r -bt=windows -i=$(BUILD_DIR)/tests/win16-graphics -fo=$(BUILD_DIR)/tests/win16-graphics/probe.res tests/pascal/test_win16_gdi.rc
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/tests/win16-graphics/probe.res $(BUILD_DIR)/tests/win16-graphics/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-graphics/GDITEST.EXE

win16-graphics-runtime-test: win16-graphics
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-graphics/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-handles win16-handles-runtime-test
win16-handles: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-handles/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-handles/units \
		-FE$(BUILD_DIR)/tests/win16-handles -oGDITEST.EXE tests/pascal/test_win16_handles.pas
	python3 tests/bitmap_fixtures.py $(BUILD_DIR)/tests/win16-handles
	$(WATCOM_BIN)/wrc -q -r -bt=windows -i=$(BUILD_DIR)/tests/win16-handles -fo=$(BUILD_DIR)/tests/win16-handles/probe.res tests/pascal/test_win16_gdi.rc
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/tests/win16-handles/probe.res $(BUILD_DIR)/tests/win16-handles/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-handles/GDITEST.EXE

win16-handles-runtime-test: win16-handles
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-handles/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-picture win16-picture-runtime-test
win16-picture: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-picture/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-picture/units \
		-FE$(BUILD_DIR)/tests/win16-picture -oGDITEST.EXE tests/pascal/test_win16_picture.pas
	python3 tests/bitmap_fixtures.py $(BUILD_DIR)/tests/win16-picture
	$(WATCOM_BIN)/wrc -q -r -bt=windows -i=$(BUILD_DIR)/tests/win16-picture -fo=$(BUILD_DIR)/tests/win16-picture/probe.res tests/pascal/test_win16_gdi.rc
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/tests/win16-picture/probe.res $(BUILD_DIR)/tests/win16-picture/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-picture/GDITEST.EXE

win16-picture-runtime-test: win16-picture
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-picture/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-drawing win16-drawing-runtime-test
win16-drawing: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-drawing/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-drawing/units \
		-FE$(BUILD_DIR)/tests/win16-drawing -oGDITEST.EXE tests/pascal/test_win16_drawing.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-drawing/GDITEST.EXE

win16-drawing-runtime-test: win16-drawing
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-drawing/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-window win16-window-runtime-test
win16-window: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-window/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -FU$(BUILD_DIR)/tests/win16-window/units \
		-FE$(BUILD_DIR)/tests/win16-window -oGDITEST.EXE tests/pascal/test_win16_window.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-window/GDITEST.EXE

win16-window-runtime-test: win16-window
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-window/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-paint win16-paint-runtime-test
win16-paint: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-paint/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-paint/units \
		-FE$(BUILD_DIR)/tests/win16-paint -oGDITEST.EXE tests/pascal/test_win16_paint.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-paint/GDITEST.EXE

win16-paint-runtime-test: win16-paint
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-paint/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-input win16-input-runtime-test
win16-input: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-input/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-input/units \
		-FE$(BUILD_DIR)/tests/win16-input -oGDITEST.EXE tests/pascal/test_win16_input.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-input/GDITEST.EXE

win16-input-runtime-test: win16-input
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-input/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-draw win16-draw-runtime-test
win16-draw: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-draw/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-draw/units \
		-FE$(BUILD_DIR)/tests/win16-draw -oGDITEST.EXE tests/pascal/test_win16_draw.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-draw/GDITEST.EXE

win16-draw-runtime-test: win16-draw
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-draw/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-slider win16-slider-runtime-test
win16-slider: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-slider/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -Fuvcl -FU$(BUILD_DIR)/tests/win16-slider/units \
		-FE$(BUILD_DIR)/tests/win16-slider -oGDITEST.EXE tests/pascal/test_win16_slider.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-slider/GDITEST.EXE

win16-slider-runtime-test: win16-slider
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-slider/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-graphic win16-graphic-runtime-test
win16-graphic: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-graphic/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -Fuvcl -FU$(BUILD_DIR)/tests/win16-graphic/units \
		-FE$(BUILD_DIR)/tests/win16-graphic -oGDITEST.EXE tests/pascal/test_win16_graphic.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-graphic/GDITEST.EXE

win16-graphic-runtime-test: win16-graphic
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-graphic/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-hierarchy win16-hierarchy-runtime-test
win16-hierarchy: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-hierarchy/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-hierarchy/units \
		-FE$(BUILD_DIR)/tests/win16-hierarchy -oGDITEST.EXE tests/pascal/test_win16_hierarchy.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-hierarchy/GDITEST.EXE

win16-hierarchy-runtime-test: win16-hierarchy
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-hierarchy/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-loop win16-loop-runtime-test
win16-loop: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-loop/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -FU$(BUILD_DIR)/tests/win16-loop/units \
		-FE$(BUILD_DIR)/tests/win16-loop -oGDITEST.EXE tests/pascal/test_win16_loop.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-loop/GDITEST.EXE

win16-loop-runtime-test: win16-loop
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-loop/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-form win16-form-runtime-test
win16-form: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-form/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-form/units \
		-FE$(BUILD_DIR)/tests/win16-form -oGDITEST.EXE tests/pascal/test_win16_form.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-form/GDITEST.EXE

win16-form-runtime-test: win16-form
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-form/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-gauge win16-gauge-runtime-test
win16-gauge: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-gauge/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -Fuvcl -FU$(BUILD_DIR)/tests/win16-gauge/units \
		-FE$(BUILD_DIR)/tests/win16-gauge -oGDITEST.EXE tests/pascal/test_win16_gauge.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-gauge/GDITEST.EXE

win16-gauge-runtime-test: win16-gauge
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-gauge/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-label win16-label-runtime-test
win16-label: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-label/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-label/units \
		-FE$(BUILD_DIR)/tests/win16-label -oGDITEST.EXE tests/pascal/test_win16_label.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-label/GDITEST.EXE

win16-label-runtime-test: win16-label
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-label/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-image win16-image-runtime-test
win16-image: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-image/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-image/units \
		-FE$(BUILD_DIR)/tests/win16-image -oGDITEST.EXE tests/pascal/test_win16_image.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-image/GDITEST.EXE

win16-image-runtime-test: win16-image
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-image/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-progress-ui win16-progress-ui-runtime-test
win16-progress-ui: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-progress-ui/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -Fuvcl -FU$(BUILD_DIR)/tests/win16-progress-ui/units \
		-FE$(BUILD_DIR)/tests/win16-progress-ui -oGDITEST.EXE tests/pascal/test_win16_progress_ui.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-progress-ui/GDITEST.EXE

win16-progress-ui-runtime-test: win16-progress-ui
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-progress-ui/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-button win16-button-runtime-test
win16-button: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-button/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-button/units \
		-FE$(BUILD_DIR)/tests/win16-button -oGDITEST.EXE tests/pascal/test_win16_button.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-button/GDITEST.EXE

win16-button-runtime-test: win16-button
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-button/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-bitbtn win16-bitbtn-runtime-test
win16-bitbtn: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-bitbtn/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -Fuvcl -FU$(BUILD_DIR)/tests/win16-bitbtn/units \
		-FE$(BUILD_DIR)/tests/win16-bitbtn -oGDITEST.EXE tests/pascal/test_win16_bitbtn.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-bitbtn/GDITEST.EXE

win16-bitbtn-runtime-test: win16-bitbtn
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-bitbtn/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-progress-button win16-progress-button-runtime-test
win16-progress-button: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-progress-button/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -Fuvcl -FU$(BUILD_DIR)/tests/win16-progress-button/units \
		-FE$(BUILD_DIR)/tests/win16-progress-button -oGDITEST.EXE tests/pascal/test_win16_progress_button.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-progress-button/GDITEST.EXE

win16-progress-button-runtime-test: win16-progress-button
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-progress-button/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-dialog win16-dialog-runtime-test
win16-dialog: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-dialog/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-dialog/units \
		-FE$(BUILD_DIR)/tests/win16-dialog -oGDITEST.EXE tests/pascal/test_win16_dialog.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-dialog/GDITEST.EXE

win16-dialog-runtime-test: win16-dialog
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-dialog/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-edit win16-edit-runtime-test win16-checkbox win16-checkbox-runtime-test
win16-edit: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-edit/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-edit/units \
		-FE$(BUILD_DIR)/tests/win16-edit -oGDITEST.EXE tests/pascal/test_win16_edit.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-edit/GDITEST.EXE

win16-edit-runtime-test: win16-edit
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-edit/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

win16-checkbox: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-checkbox/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-checkbox/units \
		-FE$(BUILD_DIR)/tests/win16-checkbox -oGDITEST.EXE tests/pascal/test_win16_checkbox.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-checkbox/GDITEST.EXE

win16-checkbox-runtime-test: win16-checkbox
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-checkbox/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-input-dialog win16-input-dialog-runtime-test
win16-input-dialog: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-input-dialog/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-input-dialog/units \
		-FE$(BUILD_DIR)/tests/win16-input-dialog -oGDITEST.EXE tests/pascal/test_win16_input_dialog.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-input-dialog/GDITEST.EXE

win16-input-dialog-runtime-test: win16-input-dialog
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-input-dialog/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-form-resources win16-incsrch win16-incsrch-runtime-test
.PHONY: win16-gui-stdio win16-gui-stdio-runtime-test
win16-gui-stdio: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-gui-stdio/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-gui-stdio/units -FE$(BUILD_DIR)/tests/win16-gui-stdio \
		-oGDITEST.EXE tests/pascal/test_win16_gui_stdio.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-gui-stdio/GDITEST.EXE

win16-gui-stdio-runtime-test: win16-gui-stdio
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-gui-stdio/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-form-resources-report
.PHONY: win16-gui-diagnostics win16-gui-diagnostics-runtime-test
.PHONY: win16-gui-buffer win16-gui-buffer-runtime-test
win16-gui-buffer: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-gui-buffer/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Cr -Co -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-gui-buffer/units -FE$(BUILD_DIR)/tests/win16-gui-buffer \
		-oGDITEST.EXE tests/pascal/test_gui_error_buffer.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-gui-buffer/GDITEST.EXE

win16-gui-buffer-runtime-test: win16-gui-buffer
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-gui-buffer/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

win16-gui-diagnostics: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-gui-diagnostics/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-FU$(BUILD_DIR)/tests/win16-gui-diagnostics/units -FE$(BUILD_DIR)/tests/win16-gui-diagnostics \
		-oGDITEST.EXE tests/pascal/test_win16_gui_diagnostics.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-gui-diagnostics/GDITEST.EXE

win16-gui-diagnostics-runtime-test: win16-gui-diagnostics
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-gui-diagnostics/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

# Calmira's forms: a loader unit (and its bitmaps) per DFM, see tools/dfm_loader.py.
$(BUILD_DIR)/generated/forms/%_dfm.pas $(BUILD_DIR)/generated/forms/%_dfm.res: src/%.dfm src/%.pas \
		tools/dfm_loader.py tools/compile_dfm.py tools/dfm_bitmaps.py tools/bitmap_resources.py
	mkdir -p $(BUILD_DIR)/generated/forms
	python3 tools/dfm_loader.py --unit src/$*.pas --output $(BUILD_DIR)/generated/forms/$*_dfm.pas \
		--resources $(BUILD_DIR)/generated/forms/$*_dfm.res $<

win16-form-resources-report:
	python3 tools/compile_dfm.py src --inventory --output $(BUILD_DIR)/generated/forms/report.json

win16-form-resources: $(BUILD_DIR)/generated/forms/incsrch_dfm.pas \
	$(BUILD_DIR)/generated/forms/askdrop_dfm.pas $(BUILD_DIR)/generated/forms/askdrop_dfm.res \
	$(BUILD_DIR)/generated/forms/select_dfm.pas $(BUILD_DIR)/generated/forms/select_dfm.res \
	$(BUILD_DIR)/generated/forms/password_dfm.pas $(BUILD_DIR)/generated/forms/password_dfm.res

.PHONY: win16-password win16-password-runtime-test
win16-password: fpc-win16-gui-rtl $(BUILD_DIR)/generated/forms/password_dfm.pas $(BUILD_DIR)/generated/forms/password_dfm.res src/locale.res
	mkdir -p $(BUILD_DIR)/tests/win16-password/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -Fuvcl -FU$(BUILD_DIR)/tests/win16-password/units \
		-FE$(BUILD_DIR)/tests/win16-password -oGDITEST.EXE tests/pascal/test_win16_password.pas
	python3 tools/merge_res16.py src/locale.res $(BUILD_DIR)/generated/forms/password_dfm.res \
		--output $(BUILD_DIR)/tests/win16-password/bound.res
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/tests/win16-password/bound.res $(BUILD_DIR)/tests/win16-password/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-password/GDITEST.EXE

win16-password-runtime-test: win16-password
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-password/GDITEST.EXE)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-password-language win16-password-language-runtime-test win16-resource-text win16-resource-text-runtime-test
win16-password-language: fpc-win16-gui-rtl $(BUILD_DIR)/generated/forms/password_dfm.pas $(BUILD_DIR)/generated/forms/password_dfm.res src/locale.res
	mkdir -p $(BUILD_DIR)/tests/win16-password-language/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -Fuvcl -FU$(BUILD_DIR)/tests/win16-password-language/units \
		-FE$(BUILD_DIR)/tests/win16-password-language -oGDITEST.EXE tests/pascal/test_win16_password_language.pas
	python3 tools/merge_res16.py src/locale.res $(BUILD_DIR)/generated/forms/password_dfm.res \
		--output $(BUILD_DIR)/tests/win16-password-language/bound.res
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/tests/win16-password-language/bound.res $(BUILD_DIR)/tests/win16-password-language/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-password-language/GDITEST.EXE

win16-password-language-runtime-test: win16-password-language languages
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-password-language/GDITEST.EXE)' \
		GDI_CATALOG_DIR='$(abspath $(BUILD_DIR)/lang)' sh tests/dos/test_win16_gdi.sh

win16-resource-text: fpc-win16-gui-rtl src/locale.res
	mkdir -p $(BUILD_DIR)/tests/win16-resource-text/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc -FU$(BUILD_DIR)/tests/win16-resource-text/units \
		-FE$(BUILD_DIR)/tests/win16-resource-text -oGDITEST.EXE tests/pascal/test_win16_resource_text.pas
	$(WATCOM_BIN)/wrc -q -bt=windows src/locale.res $(BUILD_DIR)/tests/win16-resource-text/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-resource-text/GDITEST.EXE

win16-resource-text-runtime-test: win16-resource-text languages
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-resource-text/GDITEST.EXE)' \
		GDI_CATALOG_DIR='$(abspath $(BUILD_DIR)/lang)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-select win16-select-runtime-test
.PHONY: win16-mnemonic win16-mnemonic-runtime-test
win16-mnemonic: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-mnemonic/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-mnemonic/units \
		-FE$(BUILD_DIR)/tests/win16-mnemonic -oGDITEST.EXE tests/pascal/test_win16_mnemonic.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-mnemonic/GDITEST.EXE

win16-mnemonic-runtime-test: win16-mnemonic
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-mnemonic/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh
win16-select: fpc-win16-gui-rtl $(BUILD_DIR)/generated/forms/select_dfm.pas $(BUILD_DIR)/generated/forms/select_dfm.res src/icons.res
	mkdir -p $(BUILD_DIR)/tests/win16-select/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -Fuvcl -Fu./$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -Fuvcl -FU$(BUILD_DIR)/tests/win16-select/units \
		-FE$(BUILD_DIR)/tests/win16-select -oGDITEST.EXE tests/pascal/test_win16_select.pas
	python3 tools/merge_res16.py src/icons.res $(BUILD_DIR)/generated/forms/select_dfm.res \
		--output $(BUILD_DIR)/tests/win16-select/bound.res
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/tests/win16-select/bound.res $(BUILD_DIR)/tests/win16-select/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-select/GDITEST.EXE

win16-select-runtime-test: win16-select
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-select/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-select-language win16-select-language-runtime-test
win16-select-language: fpc-win16-gui-rtl $(BUILD_DIR)/generated/forms/select_dfm.pas $(BUILD_DIR)/generated/forms/select_dfm.res src/icons.res
	mkdir -p $(BUILD_DIR)/tests/win16-select-language/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -Fuvcl -Fu./$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -Fuvcl -FU$(BUILD_DIR)/tests/win16-select-language/units \
		-FE$(BUILD_DIR)/tests/win16-select-language -oGDITEST.EXE tests/pascal/test_win16_select_language.pas
	python3 tools/merge_res16.py src/icons.res $(BUILD_DIR)/generated/forms/select_dfm.res \
		--output $(BUILD_DIR)/tests/win16-select-language/bound.res
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/tests/win16-select-language/bound.res $(BUILD_DIR)/tests/win16-select-language/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-select-language/GDITEST.EXE

win16-select-language-runtime-test: win16-select-language languages
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-select-language/GDITEST.EXE)' \
		GDI_CATALOG_DIR='$(abspath $(BUILD_DIR)/lang)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-askdrop win16-askdrop-runtime-test
.PHONY: win16-askdrop-modal win16-askdrop-modal-runtime-test
.PHONY: win16-askdrop-language win16-askdrop-language-runtime-test
win16-askdrop: fpc-win16-gui-rtl $(BUILD_DIR)/generated/forms/askdrop_dfm.pas $(BUILD_DIR)/generated/forms/askdrop_dfm.res
	mkdir -p $(BUILD_DIR)/tests/win16-askdrop/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -Fuvcl -FU$(BUILD_DIR)/tests/win16-askdrop/units \
		-FE$(BUILD_DIR)/tests/win16-askdrop -oGDITEST.EXE tests/pascal/test_win16_askdrop.pas
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/generated/forms/askdrop_dfm.res $(BUILD_DIR)/tests/win16-askdrop/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-askdrop/GDITEST.EXE

win16-askdrop-runtime-test: win16-askdrop languages
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-askdrop/GDITEST.EXE)' \
		GDI_CATALOG_DIR='$(abspath $(BUILD_DIR)/lang)' sh tests/dos/test_win16_gdi.sh

win16-askdrop-modal: fpc-win16-gui-rtl $(BUILD_DIR)/generated/forms/askdrop_dfm.pas $(BUILD_DIR)/generated/forms/askdrop_dfm.res
	mkdir -p $(BUILD_DIR)/tests/win16-askdrop-modal/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -dMODAL_PROBE -Fu$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -Fuvcl -FU$(BUILD_DIR)/tests/win16-askdrop-modal/units \
		-FE$(BUILD_DIR)/tests/win16-askdrop-modal -oGDITEST.EXE tests/pascal/test_win16_askdrop.pas
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/generated/forms/askdrop_dfm.res $(BUILD_DIR)/tests/win16-askdrop-modal/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-askdrop-modal/GDITEST.EXE

win16-askdrop-modal-runtime-test: win16-askdrop-modal
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-askdrop-modal/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

win16-askdrop-language: fpc-win16-gui-rtl $(BUILD_DIR)/generated/forms/askdrop_dfm.pas $(BUILD_DIR)/generated/forms/askdrop_dfm.res
	mkdir -p $(BUILD_DIR)/tests/win16-askdrop-language/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -Fuvcl -FU$(BUILD_DIR)/tests/win16-askdrop-language/units \
		-FE$(BUILD_DIR)/tests/win16-askdrop-language -oGDITEST.EXE tests/pascal/test_win16_askdrop_language.pas
	$(WATCOM_BIN)/wrc -q -bt=windows $(BUILD_DIR)/generated/forms/askdrop_dfm.res $(BUILD_DIR)/tests/win16-askdrop-language/GDITEST.EXE
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-askdrop-language/GDITEST.EXE

win16-askdrop-language-runtime-test: win16-askdrop-language languages
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-askdrop-language/GDITEST.EXE)' \
		GDI_CATALOG_DIR='$(abspath $(BUILD_DIR)/lang)' sh tests/dos/test_win16_gdi.sh

win16-incsrch: fpc-win16-gui-rtl win16-form-resources
	mkdir -p $(BUILD_DIR)/tests/win16-incsrch/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -FU$(BUILD_DIR)/tests/win16-incsrch/units \
		-FE$(BUILD_DIR)/tests/win16-incsrch -oGDITEST.EXE tests/pascal/test_win16_incsrch.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-incsrch/GDITEST.EXE

win16-incsrch-runtime-test: win16-incsrch
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-incsrch/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-form-text win16-form-text-runtime-test
win16-form-text: fpc-win16-gui-rtl win16-form-resources
	mkdir -p $(BUILD_DIR)/tests/win16-form-text/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -FU$(BUILD_DIR)/tests/win16-form-text/units \
		-FE$(BUILD_DIR)/tests/win16-form-text -oGDITEST.EXE tests/pascal/test_win16_form_text.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-form-text/GDITEST.EXE

win16-form-text-runtime-test: win16-form-text languages
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-form-text/GDITEST.EXE)' \
		GDI_CATALOG_DIR='$(abspath $(BUILD_DIR)/lang)' sh tests/dos/test_win16_gdi.sh

.PHONY: win16-modal win16-modal-runtime-test win16-incsrch-modal win16-incsrch-modal-runtime-test
.PHONY: win16-modal-loop win16-modal-loop-runtime-test
win16-modal-loop: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-modal-loop/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-modal-loop/units \
		-FE$(BUILD_DIR)/tests/win16-modal-loop -oGDITEST.EXE tests/pascal/test_win16_modal_loop.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-modal-loop/GDITEST.EXE

win16-modal-loop-runtime-test: win16-modal-loop
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-modal-loop/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

win16-modal: fpc-win16-gui-rtl
	mkdir -p $(BUILD_DIR)/tests/win16-modal/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fusrc/win16 -Fusrc/portable -FU$(BUILD_DIR)/tests/win16-modal/units \
		-FE$(BUILD_DIR)/tests/win16-modal -oGDITEST.EXE tests/pascal/test_win16_modal.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-modal/GDITEST.EXE

win16-modal-runtime-test: win16-modal
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-modal/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

win16-incsrch-modal: fpc-win16-gui-rtl win16-form-resources
	mkdir -p $(BUILD_DIR)/tests/win16-incsrch-modal/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi $(WIN16_GUI_FLAGS) -CX -Fu$(FPC_WIN16_GUI_RTL) \
		-Fi$(BUILD_DIR)/generated/forms -Fu$(BUILD_DIR)/generated/forms -Fusrc/win16 -Fusrc/portable -Fusrc -FU$(BUILD_DIR)/tests/win16-incsrch-modal/units \
		-FE$(BUILD_DIR)/tests/win16-incsrch-modal -oGDITEST.EXE tests/pascal/test_win16_incsrch_modal.pas
	python3 tools/check_win16_budget.py $(BUILD_DIR)/tests/win16-incsrch-modal/GDITEST.EXE

win16-incsrch-modal-runtime-test: win16-incsrch-modal
	GDI_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-incsrch-modal/GDITEST.EXE)' \
		sh tests/dos/test_win16_gdi.sh

.PHONY: win16-ui win16-ui-runtime-test
win16-ui: win16-image win16-progress-ui win16-label win16-graphic \
	win16-gauge win16-slider win16-form win16-hierarchy win16-button win16-bitbtn win16-progress-button win16-dialog \
	win16-edit win16-checkbox win16-input-dialog win16-incsrch win16-modal win16-incsrch-modal win16-form-text win16-askdrop win16-askdrop-modal win16-askdrop-language win16-mnemonic win16-select win16-select-language win16-password win16-password-language

win16-ui-runtime-test: win16-image-runtime-test win16-progress-ui-runtime-test \
	win16-label-runtime-test win16-graphic-runtime-test win16-gauge-runtime-test \
	win16-slider-runtime-test win16-form-runtime-test win16-hierarchy-runtime-test \
	win16-button-runtime-test win16-bitbtn-runtime-test win16-progress-button-runtime-test win16-dialog-runtime-test \
	win16-edit-runtime-test win16-checkbox-runtime-test win16-input-dialog-runtime-test win16-incsrch-runtime-test \
	win16-modal-runtime-test win16-incsrch-modal-runtime-test win16-form-text-runtime-test win16-askdrop-runtime-test win16-askdrop-modal-runtime-test win16-askdrop-language-runtime-test win16-mnemonic-runtime-test win16-select-runtime-test win16-select-language-runtime-test win16-password-runtime-test win16-password-language-runtime-test

# Delphi 1 strings are short strings. Calmira units precede the RTL so that
# vcl/strings.pas, not the RTL unit of the same name, satisfies "uses Strings".
calmira: fpc-win16-gui-rtl languages win16-form-resources
	mkdir -p $(BUILD_DIR)/calmira/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -Sh- $(WIN16_GUI_FLAGS) -CX \
		-Fi$(BUILD_DIR)/generated/forms -Fuvcl -Fusrc -Fusrc/portable -Fusrc/win16 \
		-Fu./$(FPC_WIN16_GUI_RTL) -FU$(BUILD_DIR)/calmira/units \
		-FE$(BUILD_DIR)/calmira -oCALMIRA.EXE src/calmira.dpr

winfile16-core: omf-toolchain
	$(MAKE) -C $(WINFILE_PORT_SRC) -f win16/Makefile \
		WATCOM='$(WATCOM)' OUT='$(abspath $(WINFILE_PORT_DIR))' core

winfile16-core-runtime-test: winfile16-core
	$(MAKE) -C $(WINFILE_PORT_SRC) -f win16/Makefile \
		WATCOM='$(WATCOM)' OUT='$(abspath $(WINFILE_PORT_DIR))' \
		JWLINK='$(abspath $(JWLINK))' core-test
	sh tests/dos/test_winfile_core_win311.sh

winfile16: winfile16-core
	$(MAKE) -C $(WINFILE_PORT_SRC) -f win16/Makefile \
		WATCOM='$(WATCOM)' OUT='$(abspath $(WINFILE_PORT_DIR))' \
		JWLINK='$(abspath $(JWLINK))' application

drive-probe: fpc-win16-toolchain languages
	mkdir -p $(DRIVE_PROBE_DIR)/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mobjfpc -CX \
		-Fu./$(FPC_WIN16_UNITS) -Fusrc/portable -Fusrc/win16 -FU$(DRIVE_PROBE_DIR)/units \
		-FE$(DRIVE_PROBE_DIR) -oDRVPROBE.EXE src/win16/drive_probe.pas

win16-helpers: fpc-win16-toolchain
	mkdir -p $(BUILD_DIR)/helpers/units
	@for helper in SHOWDESK SCRNSAVE EXPLORER CTASKMAN; do \
		source_name=$$(printf '%s' "$$helper" | tr '[:upper:]' '[:lower:]'); \
		PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mdelphi -CX -Fu./$(FPC_WIN16_UNITS) \
		-Fusrc -Fusrc/portable -Fusrc/win16 -FU$(BUILD_DIR)/helpers/units -FE$(BUILD_DIR)/helpers \
		-o$$helper.EXE src/$$source_name.dpr || exit 1; \
		$(WATCOM_BIN)/wrc -q -bt=windows src/$$source_name.res \
		$(BUILD_DIR)/helpers/$$helper.EXE || exit 1; done

toolchain-info:
	@$(FPC) -iV
	@$(FPC) -iTP
	@$(FPC) -iTO
	@test ! -x $(JWASM) || $(JWASM) -? 2>&1 | sed -n '1p'
	@test ! -x $(JWLINK) || $(JWLINK) 2>&1 | sed -n '1p'
	@test -x $(WCC) && printf '%s\n' '$(WCC)'
	@printf 'OpenWatcom source: '; git -C vendor/reference/open-watcom-v2 rev-parse HEAD
	@printf 'JWasm source: '; git -C vendor/reference/jwasm rev-parse HEAD
	@printf 'JWlink source: '; git -C vendor/reference/jwlink rev-parse HEAD
	@printf 'Free Pascal source: '; git -C vendor/reference/freepascal rev-parse HEAD
	@sed -n '/^\[jwasm\]/,/^$$/p; /^\[jwlink\]/,$$p' vendor/build-deps/LOCK

ctl3d: omf-toolchain
	mkdir -p $(CTL3D_DIR)
	WATCOM=$(WATCOM) $(WCC) -q -bt=windows -ms -ecc -zp2 -j -2 \
		-s -os -zq -zW -zu -bd -dSTRICT -dCTL3D_DLL \
		-i=$(CTL3D_SRC) -i=$(WATCOM)/h -i=$(WATCOM)/h/win \
		-fo=$(CTL3D_DIR)/ctl3d.obj $(CTL3D_SRC)/CTL3D.C
	$(JWLINK) option quiet format windows dll \
		name $(CTL3D_DIR)/CTL3DV2.DLL option modname=CTL3DV2 \
		file $(CTL3D_DIR)/ctl3d.obj file $(WATCOM)/lib286/win/libentry.obj \
		libpath $(WATCOM)/lib286/win libpath $(WATCOM)/lib286 \
		library windows option nocaseexact option version=3.10 disable 1121 \
		$(CTL3D_EXPORTS) option map=$(CTL3D_DIR)/ctl3d.map
	python3 tools/check_ctl3d.py $(CTL3D_DIR)/CTL3DV2.DLL

ctl3d-runtime-test: ctl3d
	WATCOM=$(WATCOM) sh tests/dos/test_ctl3d_win311.sh

clfn-hook: omf-toolchain
	mkdir -p $(BUILD_DIR)/win16/clfnhook
	WATCOM=$(WATCOM) $(WCC) -q -bt=windows -ms -ecc -zp2 -j -2 \
		-s -os -oi -zq -zW -zu -bd -dSTRICT -w4 -we \
		-i=$(WATCOM)/h -i=$(WATCOM)/h/win \
		-fr=$(BUILD_DIR)/win16/clfnhook/clfnhook.err \
		-fo=$(BUILD_DIR)/win16/clfnhook/clfnhook.obj src/win16/clfnhook.c
	$(WCC) -q -bt=windows -ms -ecc -zp2 -j -2 -s -os -oi -zW -zu -bd -dSTRICT -w4 -we \
		-i=$(WATCOM)/h -i=$(WATCOM)/h/win \
		-fo=$(BUILD_DIR)/win16/clfnhook/clfnstore.obj src/win16/clfnstore.c
	$(WCC) -q -bt=windows -ms -ecc -zp2 -j -2 -s -os -oi -zW -zu -bd -dSTRICT -w4 -we \
		-i=$(WATCOM)/h -i=$(WATCOM)/h/win \
		-fo=$(BUILD_DIR)/win16/clfnhook/lfn_store.obj src/portable/lfn_store.c
	$(JWLINK) option quiet format windows dll \
		name $(BUILD_DIR)/win16/clfnhook/OLFNHOOK.DLL option modname=OLFNHOOK \
		file $(BUILD_DIR)/win16/clfnhook/clfnhook.obj \
		file $(BUILD_DIR)/win16/clfnhook/clfnstore.obj \
		file $(BUILD_DIR)/win16/clfnhook/lfn_store.obj \
		file $(WATCOM)/lib286/win/libentry.obj \
		libpath $(WATCOM)/lib286/win libpath $(WATCOM)/lib286 library windows \
		option version=3.10 option nocaseexact disable 1121 \
		option map=$(BUILD_DIR)/win16/clfnhook/clfnhook.map \
		option heapsize=1k \
		export STARTFILEDIALOGHOOK.1=StartFileDialogHook \
		export STOPFILEDIALOGHOOK.2=StopFileDialogHook \
		export FILEDIALOGHOOKCOUNT.3=FileDialogHookCount \
		export FILEDIALOGHOOKDIAGNOSTICS.4=FileDialogHookDiagnostics \
		export POLLFILEDIALOGSAVES.8=PollFileDialogSaves \
		export PENDINGFILEDIALOGSAVES.9=PendingFileDialogSaves
	$(WCC) -q -bt=windows -ml -zW -zu -s -os -dSTRICT -w4 -we \
		-i=$(WATCOM)/h -i=$(WATCOM)/h/win \
		-fr=$(BUILD_DIR)/win16/clfnhook/clfnload.err \
		-fo=$(BUILD_DIR)/win16/clfnhook/clfnload.obj src/win16/clfnload.c
	$(JWLINK) option quiet format windows \
		name $(BUILD_DIR)/win16/clfnhook/OLFNLOAD.EXE \
		file $(BUILD_DIR)/win16/clfnhook/clfnload.obj \
		libpath $(WATCOM)/lib286/win libpath $(WATCOM)/lib286 \
		library windows,clibl option stack=12k option heapsize=1k option version=3.10

clfn-hook-runtime-test: clfn-hook
	sh tests/dos/test_clfnhook_win311.sh

clfn-office-runtime-test: clfn-hook
	HOOK_OFFICE_FIXTURE=1 sh tests/dos/test_clfnhook_win311.sh

window-inventory: omf-toolchain
	mkdir -p $(BUILD_DIR)/win16/diagnostics
	$(WCC) -q -bt=windows -ml -zW -zu -s -os -w4 -we \
		-i=$(WATCOM)/h -i=$(WATCOM)/h/win \
		-fo=$(BUILD_DIR)/win16/diagnostics/window_inventory.obj tests/c/window_inventory.c
	$(JWLINK) option quiet format windows \
		name $(BUILD_DIR)/win16/diagnostics/WININV.EXE \
		file $(BUILD_DIR)/win16/diagnostics/window_inventory.obj \
		libpath $(WATCOM)/lib286/win libpath $(WATCOM)/lib286 \
		library windows,clibl option stack=12k option heapsize=1k option version=3.10

# Native host reference, NOT an installed DOS/Win16 archive backend.
# All objects stay outside the pinned source submodule. Exclude RAR handlers.
archive-host:
	@test "$$(git -C $(SEVENZIP_SRC) rev-parse HEAD)" = "$(SEVENZIP_PIN)" || { \
		echo 'Initialize the pinned 7-Zip submodule before building.' >&2; exit 1; }
	mkdir -p $(SEVENZIP_HOST_DIR)
	$(MAKE) -C $(SEVENZIP_SRC)/CPP/7zip/Bundles/Alone2 -f ../../$(SEVENZIP_HOST_MAKEFILE) \
		-j$(SEVENZIP_HOST_JOBS) O=$(SEVENZIP_HOST_DIR) DISABLE_RAR=1 ST_MODE=1 \
		CC=$(SEVENZIP_HOST_CC) CXX=$(SEVENZIP_HOST_CXX)

archive-host-test: archive-host
	SEVENZIP_HOST=$(SEVENZIP_HOST_DIR)/7zz python3 tests/archive_host_acceptance.py

archive-dos: omf-toolchain
	WATCOM=$(WATCOM) JWLINK=$(abspath $(JWLINK)) \
		ARCHIVE_BUILD_DIR=$(abspath $(BUILD_DIR)/archive-dos) sh tools/build_archive_reader.sh dos

archive-dos-runtime-test: archive-dos
	sh tests/dos/test_archive_reader.sh

archive-reader-host:
	ARCHIVE_CC=$(SEVENZIP_HOST_CC) ARCHIVE_CXX=$(SEVENZIP_HOST_CXX) \
		ARCHIVE_BUILD_DIR=$(abspath $(BUILD_DIR)/archive-reader-host) sh tools/build_archive_reader.sh host

archive-reader-host-test: archive-reader-host
	ARCHIVE_READER=$(abspath $(BUILD_DIR)/archive-reader-host/clarclst) python3 tests/archive_reader_acceptance.py

archive-viewer: archive-dos
	mkdir -p $(BUILD_DIR)/win16/archive
	$(WCC) -q -bt=windows -ml -zW -zu -s -os -w4 -we \
		-i=$(WATCOM)/h -i=$(WATCOM)/h/win \
		-fo=$(BUILD_DIR)/win16/archive/clarcview.obj src/win16/clarcview.c
	$(WCC) -q -bt=windows -ml -zW -zu -s -os -w4 -we -i=$(WATCOM)/h \
		-fo=$(BUILD_DIR)/win16/archive/archive_index.obj src/portable/archive_index.c
	$(JWLINK) option quiet format windows name $(BUILD_DIR)/win16/archive/OLFNVIEW.EXE \
		file $(BUILD_DIR)/win16/archive/clarcview.obj file $(BUILD_DIR)/win16/archive/archive_index.obj \
		libpath $(WATCOM)/lib286/win libpath $(WATCOM)/lib286 library windows,commdlg,clibl \
		option stack=12k option heapsize=1k option version=3.10
	cp $(BUILD_DIR)/archive-dos/OLFNLIST.EXE $(BUILD_DIR)/win16/archive/
	cp $(BUILD_DIR)/archive-dos/7ZIP-LICENSE.txt $(BUILD_DIR)/archive-dos/7ZIP-LGPL.txt \
		$(BUILD_DIR)/archive-dos/DOS32A-LICENSE.txt $(BUILD_DIR)/win16/archive/
	cp docs/licenses/gpl-3.0.txt $(BUILD_DIR)/win16/archive/GPL-3.0.txt
	cp docs/archive_viewer.md $(BUILD_DIR)/win16/archive/ARCHIVE_VIEWER.md

archive-preview-runtime-test: archive-viewer clfn-hook
	WATCOM=$(WATCOM) sh tests/dos/test_archive_preview_win311.sh

archive-office-runtime-test: archive-viewer clfn-hook
	WATCOM=$(WATCOM) sh tests/dos/test_archive_office_win311.sh

dos-bridge-diagnose: archive-dos
	WATCOM=$(WATCOM) sh tests/dos/diagnose_dos_bridge.sh

upx:
	@test -f $(UPX_SRC)/vendor/ucl/src/ucl_init.c || { \
		echo 'Initialize UPX dependencies: git submodule update --init --recursive' >&2; exit 1; }
	cmake -S $(UPX_SRC) -B $(UPX_BUILD) -G Ninja \
		-DCMAKE_BUILD_TYPE=Release -DUPX_CONFIG_DISABLE_GITREV=ON \
		-DUPX_CONFIG_DISABLE_SELF_PACK_TEST=ON
	cmake --build $(UPX_BUILD) --target upx

pack-win16: win16-helpers upx
	python3 tools/pack_executables.py --upx '$(UPX)' --output $(BUILD_DIR)/packed \
		$(BUILD_DIR)/helpers/*.EXE

pack-drive-probe: drive-probe upx
	python3 tools/pack_executables.py --upx '$(UPX)' --output $(BUILD_DIR)/packed-probe \
		$(DRIVE_PROBE_DIR)/DRVPROBE.EXE

openlfn: clfn-hook

openlfn-package: archive-viewer openlfn
	python3 tools/stage_archive.py --build '$(BUILD_DIR)' --output '$(BUILD_DIR)/openlfn-package' \
		--installer '$(GDI)/build/INSTALL.EXE'

openlfn-dist: openlfn-package
	mkdir -p '$(BUILD_DIR)/dist'
	python3 tools/stage_archive.py --build '$(BUILD_DIR)' --output '$(BUILD_DIR)/openlfn-package' \
		--installer '$(GDI)/build/INSTALL.EXE' --archive '$(BUILD_DIR)/dist/OPENLFN.ZIP'
	cd '$(BUILD_DIR)/dist' && sha256sum OPENLFN.ZIP > OPENLFN.SHA

# Compatibility target: new packages always use the independent product name.
archive-package: openlfn-package

archive-package-runtime-test: archive-package
	sh tests/dos/test_archive_package.sh

package: help lfn-probe doslfn ctl3d languages pack-win16 archive-viewer clfn-hook
	GDI="$(GDI)" sh tools/package.sh

clean:
	rm -rf $(FPC_TEST_DIR)
