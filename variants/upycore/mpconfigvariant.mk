# uPyCore unix oracle. 32-bit build: CROSS_COMPILE=i686-linux-gnu-
# (the pin's longlong CI recipe). Small ints are then 31 bits.

# libffi on i386, and the btree / mbedtls / micropython-lib submodules,
# are not part of the v1 lock. The longlong variant turns FFI off for the
# same 32-bit build. Fat and littlefs need finalisers, which this variant
# turns off.
MICROPY_PY_FFI := 0
MICROPY_PY_BTREE := 0
MICROPY_PY_SSL := 0
MICROPY_SSL_AXTLS := 0
MICROPY_SSL_MBEDTLS := 0
MICROPY_VFS_FAT := 0
MICROPY_VFS_LFS1 := 0
MICROPY_VFS_LFS2 := 0

# No frozen micropython-lib manifest. That tree is a nested submodule.
FROZEN_MANIFEST :=

# stdio.c in this directory is picked up by the unix port's variant
# wildcard. Its object path follows that absolute directory.
$(shell mkdir -p "$(BUILD)/$(VARIANT_DIR)")

ifeq ($(UPYCORE_ORACLE_MPZ),1)
MPY_TOOL_FLAGS = -mlongint-impl mpz
CFLAGS_EXTRA += -DUPYCORE_ORACLE_MPZ
else
MPY_TOOL_FLAGS = -mlongint-impl longlong
endif

# The common variant header lives next to the stock unix variants, not
# next to this directory.
CFLAGS_EXTRA += -I$(TOP)/ports/unix/variants

# Evaluate binary32 arithmetic in binary32. The i686 default is x87, whose
# 80-bit intermediates make float expressions differ from a binary32 MCU
# (Cortex-M4F, ESP32) and from the hart, which rounds every operation.
CFLAGS_EXTRA += -msse2 -mfpmath=sse
