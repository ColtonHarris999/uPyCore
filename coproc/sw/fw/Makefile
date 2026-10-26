# Coprocessor firmware: TinyUSB CDC ACM bridged to the hart's mailbox.
#
#   make -C coproc/sw/fw         build/coproc/fw/coproc.hex and the SIE microcode
#   make -C coproc/sw/fw clean
#
# The toolchain recipe is coproc/sw/TOOLCHAIN.md. The link fails if the
# image does not fit the 16 KB code and 8 KB data SRAMs.

CROSS    ?= riscv64-unknown-elf-
CC       := $(CROSS)gcc
OBJCOPY  := $(CROSS)objcopy
SIZE     := $(CROSS)size
PYTHON   ?= python3
ROOT     := $(abspath ../../..)
TINYUSB  ?= $(ROOT)/vendor/tinyusb
NO2USB   ?= $(ROOT)/vendor/no2usb
COMMON   := $(abspath ../common)
OUT      ?= $(ROOT)/build/coproc/fw

ARCH     ?= -march=rv32emc_zicsr -mabi=ilp32e
CFLAGS   := $(ARCH) -DTUP_DCD_ENDPOINT_MAX=8 -Os -g -ffunction-sections -fdata-sections \
            -fno-common -Wall -Wno-unused-function --specs=picolibc.specs \
            -I$(CURDIR) -I$(abspath ../dcd) -I$(TINYUSB)/src
LDFLAGS  := $(ARCH) --specs=picolibc.specs -nostartfiles -T$(COMMON)/coproc.ld -Wl,--gc-sections

TUSB_SRC := src/tusb.c src/common/tusb_fifo.c src/device/usbd.c \
            src/class/cdc/cdc_device.c
APP_SRC  := main.c usb_descriptors.c ../dcd/dcd_no2usb.c
SRCS     := $(addprefix $(TINYUSB)/,$(TUSB_SRC)) $(abspath $(APP_SRC))
OBJS     := $(addprefix $(OUT)/,$(notdir $(SRCS:.c=.o))) $(OUT)/crt0.o

.PHONY: all clean
all: $(OUT)/coproc.hex $(OUT)/usb_trans_mc.hex

$(OUT):
	mkdir -p $@

define compile
$(OUT)/$(notdir $(1:.c=.o)): $(1) $(wildcard *.h) | $(OUT)
	$(CC) $(CFLAGS) -c $$< -o $$@
endef
$(foreach s,$(SRCS),$(eval $(call compile,$(s))))

$(OUT)/crt0.o: $(COMMON)/crt0.S | $(OUT)
	$(CC) $(ARCH) -c $< -o $@

$(OUT)/coproc.elf: $(OBJS) $(COMMON)/coproc.ld
	$(CC) $(LDFLAGS) -Wl,-Map=$(OUT)/coproc.map -o $@ $(OBJS)
	$(SIZE) $@

$(OUT)/coproc.hex: $(OUT)/coproc.elf
	$(OBJCOPY) -O binary $< $(OUT)/coproc.bin
	$(PYTHON) ../tools/bin2hex.py $(OUT)/coproc.bin $@

# The SIE's transaction microcode, the ROM no2usb loads from a hex file.
$(OUT)/usb_trans_mc.hex: $(NO2USB)/utils/microcode.py | $(OUT)
	$(PYTHON) $< > $@

clean:
	rm -rf $(OUT)
