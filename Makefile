GDI ?= ../gdi
FPC ?= fpc
BUILD_DIR ?= build
FPC_TEST_DIR := $(BUILD_DIR)/tests/fpc
FPC_WIN16_ROOT ?= $(BUILD_DIR)/toolchains/fpc-win16
FPC_WIN16_VERSION ?= 3.3.1
FPC_WIN16 := $(FPC_WIN16_ROOT)/lib/fpc/$(FPC_WIN16_VERSION)/ppcross8086
FPC_WIN16_UNITS := $(FPC_WIN16_ROOT)/lib/fpc/$(FPC_WIN16_VERSION)/units/win16/rtl
WINFILE16_DIR := $(BUILD_DIR)/winfile16
WATCOM ?= /opt/watcom
WATCOM_BIN ?= $(WATCOM)/binl64
WCC ?= $(WATCOM_BIN)/wcc
OMF_BIN_DIR ?= $(BUILD_DIR)/toolchains/bin
JWASM ?= $(OMF_BIN_DIR)/jwasm
JWLINK ?= $(OMF_BIN_DIR)/jwlink

.PHONY: all compare verify-sources test fpc-test toolchain-smoke doslfn \
	doslfn-test lfn-probe lfn-probe-test \
	toolchain-info omf-toolchain fpc-win16-toolchain fpc-win16-smoke \
	winfile16 package clean

all: test

compare:
	python3 tools/compare_upstreams.py

verify-sources:
	sha256sum -c archives/original/SHA256SUMS

test: fpc-test
	python3 -m unittest discover -s tests -p 'test_*.py'

fpc-test:
	mkdir -p $(FPC_TEST_DIR)/units
	$(FPC) -Mdelphi -S2 -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_drivechange.pas
	$(FPC_TEST_DIR)/test_drivechange
	$(FPC) -Mdelphi -S2 -Fu./src/portable -FU$(FPC_TEST_DIR)/units \
		-FE$(FPC_TEST_DIR) tests/pascal/test_virtual_lfn.pas
	$(FPC_TEST_DIR)/test_virtual_lfn

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

winfile16: fpc-win16-toolchain
	mkdir -p $(WINFILE16_DIR)/units
	PATH='$(abspath $(OMF_BIN_DIR)):$(PATH)' $(FPC_WIN16) \
		-Twin16 -Pi8086 -Mobjfpc -CX \
		-Fu./$(FPC_WIN16_UNITS) -FU$(WINFILE16_DIR)/units \
		-FE$(WINFILE16_DIR) -oWINFILE.EXE src/win16/winfile16.pas

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

package: lfn-probe doslfn
	GDI="$(GDI)" sh tools/package.sh

clean:
	rm -rf $(FPC_TEST_DIR)
