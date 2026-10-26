// Descriptors for the coprocessor: one CDC ACM function (the MicroPython
// console). VID:PID 1209:5550 is in the pid.codes test range.
#include "tusb.h"

#define USB_VID 0x1209
#define USB_PID (0x5550 | (CFG_TUD_HID ? 1 : 0) | (CFG_TUD_DFU_RUNTIME ? 2 : 0))

static tusb_desc_device_t const desc_device = {
    .bLength = sizeof(tusb_desc_device_t),
    .bDescriptorType = TUSB_DESC_DEVICE,
    .bcdUSB = 0x0200,
    .bDeviceClass = TUSB_CLASS_MISC,
    .bDeviceSubClass = MISC_SUBCLASS_COMMON,
    .bDeviceProtocol = MISC_PROTOCOL_IAD,
    .bMaxPacketSize0 = CFG_TUD_ENDPOINT0_SIZE,
    .idVendor = USB_VID,
    .idProduct = USB_PID,
    .bcdDevice = 0x0100,
    .iManufacturer = 1,
    .iProduct = 2,
    .iSerialNumber = 3,
    .bNumConfigurations = 1,
};

uint8_t const *tud_descriptor_device_cb(void) {
    return (uint8_t const *)&desc_device;
}

enum {
    ITF_CDC = 0,
    ITF_CDC_DATA,
#if CFG_TUD_HID
    ITF_HID,
#endif
#if CFG_TUD_DFU_RUNTIME
    ITF_DFU_RT,
#endif
    ITF_TOTAL
};

#define EP_CDC_NOTIF 0x81
#define EP_CDC_OUT   0x02
#define EP_CDC_IN    0x82
#define EP_HID_IN    0x83

#if CFG_TUD_HID
static uint8_t const desc_hid_report[] = { TUD_HID_REPORT_DESC_KEYBOARD() };
uint8_t const *tud_hid_descriptor_report_cb(uint8_t instance) {
    (void)instance;
    return desc_hid_report;
}
#endif

#define CONFIG_LEN (TUD_CONFIG_DESC_LEN + TUD_CDC_DESC_LEN + \
                    (CFG_TUD_HID ? TUD_HID_DESC_LEN : 0) + \
                    (CFG_TUD_DFU_RUNTIME ? TUD_DFU_RT_DESC_LEN : 0))

static uint8_t const desc_config[] = {
    TUD_CONFIG_DESCRIPTOR(1, ITF_TOTAL, 0, CONFIG_LEN, 0x00, 100),
    TUD_CDC_DESCRIPTOR(ITF_CDC, 4, EP_CDC_NOTIF, 8, EP_CDC_OUT, EP_CDC_IN, 64),
#if CFG_TUD_HID
    TUD_HID_DESCRIPTOR(ITF_HID, 0, HID_ITF_PROTOCOL_KEYBOARD, sizeof(desc_hid_report),
                       EP_HID_IN, CFG_TUD_HID_EP_BUFSIZE, 10),
#endif
#if CFG_TUD_DFU_RUNTIME
    TUD_DFU_RT_DESCRIPTOR(ITF_DFU_RT, 5, 0x0d, 1000, 4096),
#endif
};

uint8_t const *tud_descriptor_configuration_cb(uint8_t index) {
    (void)index;
    return desc_config;
}

static char const *const strings[] = {
    "", "upycore", "upycore USB", "0001", "upycore CDC", "upycore DFU",
};

static uint16_t desc_str[32];

uint16_t const *tud_descriptor_string_cb(uint8_t index, uint16_t langid) {
    (void)langid;
    uint8_t n;
    if (index == 0) {
        desc_str[1] = 0x0409;
        n = 1;
    } else {
        if (index >= sizeof(strings) / sizeof(strings[0]))
            return NULL;
        char const *s = strings[index];
        for (n = 0; s[n] && n < 31; n++)
            desc_str[1 + n] = (uint8_t)s[n];
    }
    desc_str[0] = (uint16_t)((TUSB_DESC_STRING << 8) | (2 * n + 2));
    return desc_str;
}
