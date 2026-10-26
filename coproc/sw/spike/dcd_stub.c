// Device controller driver stub. Every entry point exists and does
// nothing, so the spike links TinyUSB's device stack and class drivers
// without an SIE. A real DCD is roughly another 1.5-3 KB of text.
#include "tusb.h"
#include "device/dcd.h"

volatile uint32_t dcd_stub_reg;

bool dcd_init(uint8_t rhport, const tusb_rhport_init_t *rh_init) {
    (void)rhport; (void)rh_init;
    dcd_stub_reg = 1;
    return true;
}

void dcd_int_handler(uint8_t rhport) {
    (void)rhport;
    if (dcd_stub_reg & 2)
        dcd_event_bus_reset(0, TUSB_SPEED_FULL, true);
}

void dcd_int_enable(uint8_t rhport) { (void)rhport; dcd_stub_reg |= 4; }
void dcd_int_disable(uint8_t rhport) { (void)rhport; dcd_stub_reg &= ~4u; }
void dcd_set_address(uint8_t rhport, uint8_t dev_addr) {
    (void)rhport;
    dcd_stub_reg = dev_addr;
    dcd_edpt_xfer(rhport, 0x80, NULL, 0, false);
}
void dcd_remote_wakeup(uint8_t rhport) { (void)rhport; }
void dcd_connect(uint8_t rhport) { (void)rhport; dcd_stub_reg |= 8; }
void dcd_disconnect(uint8_t rhport) { (void)rhport; dcd_stub_reg &= ~8u; }
void dcd_sof_enable(uint8_t rhport, bool en) { (void)rhport; (void)en; }
void dcd_edpt0_status_complete(uint8_t rhport, tusb_control_request_t const *request) {
    (void)rhport; (void)request;
}
bool dcd_edpt_open(uint8_t rhport, tusb_desc_endpoint_t const *desc_ep) {
    (void)rhport;
    dcd_stub_reg = desc_ep->bEndpointAddress;
    return true;
}
void dcd_edpt_close_all(uint8_t rhport) { (void)rhport; }
bool dcd_edpt_xfer(uint8_t rhport, uint8_t ep_addr, uint8_t *buffer, uint16_t total_bytes, bool is_isr) {
    (void)rhport; (void)buffer; (void)is_isr;
    dcd_stub_reg = ep_addr | ((uint32_t)total_bytes << 8);
    return true;
}
void dcd_edpt_stall(uint8_t rhport, uint8_t ep_addr) { (void)rhport; dcd_stub_reg = ep_addr; }
void dcd_edpt_clear_stall(uint8_t rhport, uint8_t ep_addr) { (void)rhport; dcd_stub_reg = ep_addr; }
