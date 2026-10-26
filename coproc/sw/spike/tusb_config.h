// TinyUSB configuration for the Phase 0 size spike.
// SPIKE_HID and SPIKE_DFU_RT add a HID keyboard or a DFU runtime
// interface next to CDC. The DCD is dcd_stub.c, so nothing here talks
// to hardware; the build only measures code, data, and stack.
#ifndef TUSB_CONFIG_H_
#define TUSB_CONFIG_H_

#define CFG_TUSB_MCU            OPT_MCU_NONE
#define CFG_TUSB_OS             OPT_OS_NONE
#define CFG_TUSB_DEBUG          0
#define CFG_TUD_ENABLED         1
#define CFG_TUD_MAX_SPEED       OPT_MODE_FULL_SPEED
#define CFG_TUSB_MEM_SECTION
#define CFG_TUSB_MEM_ALIGN      __attribute__((aligned(4)))
#define CFG_TUD_ENDPOINT0_SIZE  64

#define CFG_TUD_CDC             1
#define CFG_TUD_CDC_NOTIFY      1
#define CFG_TUD_CDC_RX_BUFSIZE  64
#define CFG_TUD_CDC_TX_BUFSIZE  64
#define CFG_TUD_CDC_RX_EPSIZE   64
#define CFG_TUD_CDC_TX_EPSIZE   64

#ifdef SPIKE_HID
#define CFG_TUD_HID             1
#define CFG_TUD_HID_EP_BUFSIZE  8
#else
#define CFG_TUD_HID             0
#endif

#ifdef SPIKE_DFU_RT
#define CFG_TUD_DFU_RUNTIME     1
#else
#define CFG_TUD_DFU_RUNTIME     0
#endif

#define CFG_TUD_MSC             0
#define CFG_TUD_MIDI            0
#define CFG_TUD_VENDOR          0

#endif
