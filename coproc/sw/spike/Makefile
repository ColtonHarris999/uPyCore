# Phase 0 size spike: TinyUSB device stack on RV32EMC / ilp32e.
#
#   make -C coproc/sw/spike          build cdc, cdc_hid, cdc_dfu and print the table
#   make -C coproc/sw/spike clean
#
# TOOLCHAIN.md one directory up has the toolchain recipe.

CROSS    ?= riscv64-unknown-elf-
CC       := $(CROSS)gcc
SIZE     := $(CROSS)size
PYTHON   ?= python3
ROOT     := $(abspath ../../..)
TINYUSB  ?= $(ROOT)/vendor/tinyusb
NO2USB   ?= $(ROOT)/vendor/no2usb
COMMON   := $(abspath ../common)
OUT      ?= $(ROOT)/build/coproc/spike

ARCH     ?= -march=rv32emc_zicsr -mabi=ilp32e
CFLAGS   := $(ARCH) -DTUP_DCD_ENDPOINT_MAX=8 -Os -g -ffunction-sections -fdata-sections -fno-common \
            -fstack-usage -fcallgraph-info=su -Wall -Wno-unused-function \
            --specs=picolibc.specs -I. -I../dcd -I$(TINYUSB)/src
LDFLAGS  := $(ARCH) --specs=picolibc.specs -nostartfiles -T$(COMMON)/coproc.ld \
            -Wl,--gc-sections -Wl,--defsym=CODE_SIZE=64K -Wl,--defsym=DATA_SIZE=32K

TUSB_SRC := src/tusb.c src/common/tusb_fifo.c src/device/usbd.c \
            src/class/cdc/cdc_device.c src/class/hid/hid_device.c src/class/dfu/dfu_rt_device.c
APP_SRC  := main.c usb_descriptors.c dcd_stub.c

VARIANTS := cdc cdc_hid cdc_dfu cdc_no2usb
DEF_cdc     :=
DEF_cdc_hid := -DSPIKE_HID
DEF_cdc_dfu := -DSPIKE_DFU_RT
DEF_cdc_no2usb :=
# cdc_no2usb links the real no2usb DCD instead of dcd_stub.c.
APP_cdc_no2usb := main.c usb_descriptors.c ../dcd/dcd_no2usb.c

.PHONY: all clean $(VARIANTS)
all: $(VARIANTS)
	$(PYTHON) ../tools/spike_report.py $(addprefix $(OUT)/,$(VARIANTS))

define variant
$(1): $(OUT)/$(1)/spike.elf
$(OUT)/$(1)/spike.elf: $(APP_SRC) tusb_config.h $(COMMON)/crt0.S $(COMMON)/coproc.ld
	rm -rf $(OUT)/$(1) && mkdir -p $(OUT)/$(1)
	cd $(OUT)/$(1) && for f in $(addprefix $(TINYUSB)/,$(TUSB_SRC)) $(abspath $(APP_$(1))); do \
	    $(CC) $(CFLAGS) -I$(CURDIR) $(DEF_$(1)) -c $$$$f -o $$$$(basename $$$$f .c).o || exit 1; done
	$(CC) $(ARCH) -c $(COMMON)/crt0.S -o $(OUT)/$(1)/crt0.o
	$(CC) $(LDFLAGS) -Wl,-Map=$(OUT)/$(1)/spike.map -o $$@ $(OUT)/$(1)/*.o
	$(SIZE) $$@
endef
$(foreach v,cdc cdc_hid cdc_dfu,$(eval APP_$(v) := $(APP_SRC)))
$(foreach v,$(VARIANTS),$(eval $(call variant,$(v))))

clean:
	rm -rf $(OUT)
