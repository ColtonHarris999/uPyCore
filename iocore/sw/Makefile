# I/O core firmware (upycore/docs/mpy_io_core.md, Firmware).
#
#   make -C iocore/sw APP=hello     build/iocore/hello/{code,data}.hex
#   make -C iocore/sw               APP defaults to fw (the production image)
#
# Toolchain: Ubuntu's gcc-riscv64-unknown-elf and picolibc-riscv64-unknown-elf
# (iocore/sw/TOOLCHAIN.md). The link fails when the image does not fit the
# SRAMs or the plan's size budget (common/iocore.ld).

CROSS    ?= riscv64-unknown-elf-
CC       := $(CROSS)gcc
OBJCOPY  := $(CROSS)objcopy
SIZE     := $(CROSS)size
PYTHON   ?= python3
ROOT     := $(abspath ../..)
COMMON   := $(abspath common)
APP      ?= fw
OUT      ?= $(ROOT)/build/iocore/$(APP)

ARCH     ?= -march=rv32emc_zicsr -mabi=ilp32e
CFLAGS   := $(ARCH) -Os -g -ffunction-sections -fdata-sections -fno-common -Wall \
            -Wno-unused-function --specs=picolibc.specs -I$(COMMON) -I$(CURDIR)/$(APP) $(EXTRA_CFLAGS)
LDFLAGS  := $(ARCH) --specs=picolibc.specs -nostartfiles -T$(COMMON)/iocore.ld -Wl,--gc-sections

SRCS     := $(wildcard $(CURDIR)/$(APP)/*.c) $(EXTRA_SRCS)
# The production firmware has the USB device: TinyUSB's CDC ACM on the
# no2usb SIE (vendor/tinyusb, iocore/sw/usb).
ifeq ($(APP),fw)
TINYUSB  ?= $(ROOT)/vendor/tinyusb
SRCS     += $(addprefix $(TINYUSB)/,src/tusb.c src/common/tusb_fifo.c src/device/usbd.c \
              src/class/cdc/cdc_device.c) $(wildcard $(CURDIR)/usb/*.c)
CFLAGS   += -DTUP_DCD_ENDPOINT_MAX=8 -I$(CURDIR)/usb -I$(TINYUSB)/src
endif
OBJS     := $(addprefix $(OUT)/,$(notdir $(SRCS:.c=.o))) $(OUT)/crt0.o

.PHONY: all clean
all: $(OUT)/code.hex $(OUT)/data.hex

$(OUT):
	mkdir -p $@

define compile
$(OUT)/$(notdir $(1:.c=.o)): $(1) $(wildcard $(CURDIR)/$(APP)/*.h) $(COMMON)/iocore.h | $(OUT)
	$(CC) $(CFLAGS) -c $$< -o $$@
endef
$(foreach s,$(SRCS),$(eval $(call compile,$(s))))

$(OUT)/crt0.o: $(COMMON)/crt0.S | $(OUT)
	$(CC) $(ARCH) -c $< -o $@

$(OUT)/iocore.elf: $(OBJS) $(COMMON)/iocore.ld
	$(CC) $(LDFLAGS) -Wl,-Map=$(OUT)/iocore.map -o $@ $(OBJS)
	$(SIZE) $@

$(OUT)/code.hex: $(OUT)/iocore.elf
	$(OBJCOPY) -O binary -j .vectors -j .text $< $(OUT)/code.bin
	$(PYTHON) tools/bin2hex.py $(OUT)/code.bin $@

$(OUT)/data.hex: $(OUT)/iocore.elf
	$(OBJCOPY) -O binary -j .rodata -j .data $< $(OUT)/data.bin
	$(PYTHON) tools/bin2hex.py $(OUT)/data.bin $@

clean:
	rm -rf $(OUT)
