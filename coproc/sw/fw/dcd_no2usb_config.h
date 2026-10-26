// no2usb DCD configuration: the coprocessor peripheral map in
// upycore/docs/mpy_coproc.md. The core is built with EVT_DEPTH 0, so the
// driver scans endpoint status instead of reading an event FIFO.
#pragma once
#define NO2USB_CORE_BASE    0x80010000
#define NO2USB_DATA_RX_BASE 0x80020000
#define NO2USB_DATA_TX_BASE 0x80030000
