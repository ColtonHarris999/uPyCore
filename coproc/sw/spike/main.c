// CDC echo loop for the size spike. The real bridge (CDC to the mailbox)
// is coproc/sw/fw; this file only has to pull in the same TinyUSB paths.
#include "tusb.h"

volatile uint32_t spike_sink;

int main(void) {
    tusb_rhport_init_t init = { .role = TUSB_ROLE_DEVICE, .speed = TUSB_SPEED_FULL };
    tusb_init(0, &init);
    for (;;) {
        tud_task();
        if (tud_cdc_available()) {
            uint8_t buf[64];
            uint32_t n = tud_cdc_read(buf, sizeof(buf));
            for (uint32_t i = 0; i < n; i++)
                if (buf[i] == 0x03)
                    spike_sink++;
            tud_cdc_write(buf, n);
            tud_cdc_write_flush();
        }
    }
}

void tud_cdc_line_state_cb(uint8_t itf, bool dtr, bool rts) {
    (void)itf;
    (void)rts;
    spike_sink = dtr;
}

void tud_cdc_line_coding_cb(uint8_t itf, cdc_line_coding_t const *coding) {
    (void)itf;
    spike_sink = coding->bit_rate;
}

void tud_suspend_cb(bool remote_wakeup_en) {
    (void)remote_wakeup_en;
    spike_sink = 0;
}

void tud_resume_cb(void) {
    spike_sink = 1;
}

#if CFG_TUD_HID
uint16_t tud_hid_get_report_cb(uint8_t instance, uint8_t report_id, hid_report_type_t type,
                               uint8_t *buffer, uint16_t reqlen) {
    (void)instance; (void)report_id; (void)type; (void)buffer; (void)reqlen;
    return 0;
}

void tud_hid_set_report_cb(uint8_t instance, uint8_t report_id, hid_report_type_t type,
                           uint8_t const *buffer, uint16_t bufsize) {
    (void)instance; (void)report_id; (void)type;
    spike_sink = bufsize ? buffer[0] : 0;
}
#endif

#if CFG_TUD_DFU_RUNTIME
void tud_dfu_runtime_reboot_to_dfu_cb(void) {
    spike_sink = 0xdf;
}
#endif
