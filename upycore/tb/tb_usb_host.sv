// A full-speed USB host for the SoC bench (upycore/docs/mpy_coproc.md).
//
// It drives D+ and D- itself: NRZI, bit stuffing, SYNC and EOP, CRC5 on
// tokens and CRC16 on data, at 12 Mbit/s. Once the device switches its
// pull-up on, the host resets the bus for 10 ms, starts SOF every 1 ms, and
// enumerates the device as Linux would a CDC ACM function: the device
// descriptor, SET_ADDRESS 1, the configuration descriptor, SET_CONFIGURATION
// 1, SET_LINE_CODING (115200 8N1), and SET_CONTROL_LINE_STATE (DTR and RTS).
// Then it moves data: bytes queued for the device go out on bulk OUT 0x02 in
// packets of up to 64, and bulk IN 0x82 is polled; a NAK is retried.
//
// +USB_SCRIPT=<file> runs a script, one command a line (# comments):
//   text <s>      queue the text (escapes \r \n \t \\ \xHH) for the device
//   send <hex>    queue bytes, two hex digits each
//   wait <s>      wait until the bytes read from the device since the last
//                 wait contain <s> (escapes as for text)
//   sleep <us>    wait
//   suspend <ms>  stop SOF for <ms> (the device suspends after 3 ms), then
//                 resume: K for 1 ms, an EOP, and SOF again
//   loopback <n>  send n pattern bytes (printable ASCII) and wait for them to
//                 come back in order; prints USB_LOOPBACK with the bytes per
//                 second
//   finish        end the run (done = 1)
// Without a script the host stays off the bus. A failure sets failed and
// fail_msg; the bench reports it and stops.
module tb_usb_host (
    inout wire dp,
    inout wire dn
);
    localparam realtime BIT = 83.333;          // ns, one bit at 12 Mbit/s

    localparam byte PID_OUT   = 8'hE1, PID_IN    = 8'h69, PID_SOF   = 8'hA5, PID_SETUP = 8'h2D;
    localparam byte PID_DATA0 = 8'hC3, PID_DATA1 = 8'h4B;
    localparam byte PID_ACK   = 8'hD2, PID_NAK   = 8'h5A, PID_STALL = 8'h1E;
    localparam int  ST_ACK = 0, ST_NAK = 1, ST_STALL = 2, ST_DATA = 3, ST_TIMEOUT = 4, ST_ERR = 5;
    localparam logic [6:0] ADDR = 7'd1;

    logic oe = 1'b0, odp = 1'b1, odn = 1'b0;
    assign dp = oe ? odp : 1'bz;
    assign dn = oe ? odn : 1'bz;

    // ---- what the bench reads ----
    bit          active = 0;        // a script is running
    bit          configured = 0;
    bit          done = 0;
    bit          failed = 0;
    string       fail_msg = "";
    logic [7:0]  rxmem [0:65535];   // bytes read from the device, in order
    int          rx_n = 0;
    int          tx_total = 0;      // bytes the device accepted
    int          suspends = 0;

    byte         txq[$];
    bit          bus_busy = 0;
    bit          sof_on = 0;
    bit          pump_on = 0;
    int          frame = 0;
    bit          tog_out = 0, tog_in = 0;
    bit          debug = 0;                // +USB_DEBUG: one line per transaction

    initial debug = $test$plusargs("USB_DEBUG");

    task automatic fail(input string msg);
        if (!failed) begin
            failed = 1;
            fail_msg = msg;
        end
    endtask

    // ---- CRCs (USB 2.0 8.3.5) ----
    function automatic logic [4:0] crc5(input logic [10:0] v);
        logic [4:0] c;
        c = 5'h1F;
        for (int i = 0; i < 11; i++) c = (c[0] ^ v[i]) ? ((c >> 1) ^ 5'h14) : (c >> 1);
        return ~c;
    endfunction

    function automatic logic [15:0] crc16(input byte d[$]);
        logic [15:0] c;
        c = 16'hFFFF;
        foreach (d[k])
            for (int i = 0; i < 8; i++) c = (c[0] ^ d[k][i]) ? ((c >> 1) ^ 16'hA001) : (c >> 1);
        return ~c;
    endfunction

    // ---- the wire ----
    // Variables are set at the top of each task: Verilator keeps a block's
    // locals from one call to the next.
    task automatic tx(input byte pkt[$]);
        logic lvl;
        int ones;
        byte all[$];
        lvl = 1'b1;                     // idle J
        ones = 0;
        all = pkt;
        all.push_front(8'h80);          // SYNC
        oe = 1'b1;
        foreach (all[k]) begin
            for (int i = 0; i < 8; i++) begin
                if (all[k][i]) ones++;
                else begin lvl = !lvl; ones = 0; end
                odp = lvl; odn = !lvl; #(BIT);
                if (ones == 6) begin
                    lvl = !lvl; ones = 0;
                    odp = lvl; odn = !lvl; #(BIT);
                end
            end
        end
        odp = 1'b0; odn = 1'b0; #(BIT); #(BIT);
        odp = 1'b1; odn = 1'b0; #(BIT);
        oe = 1'b0;
        last_idle = $realtime;
    endtask

    // A packet from the device, PID first; ok is 0 on a timeout or a bad
    // SYNC. Samples the middle of each bit from the first K.
    task automatic rx(output byte pkt[$], output bit ok, input int wait_bits);
        logic prev, lvl;
        int ones, nb;
        logic [7:0] cur;
        bit started;
        pkt.delete();
        ok = 0;
        started = 0;
        for (int k = 0; k < wait_bits * 8; k++) begin
            if (!dp && dn) begin started = 1; break; end
            #(BIT / 8);
        end
        if (!started) return;
        #(BIT / 2 - BIT / 16);
        prev = 1'b1;
        ones = 0;
        nb = 0;
        cur = 8'h0;
        for (int k = 0; k < 1200; k++) begin
            logic b;
            if (!dp && !dn) break;
            lvl = dp;
            b = (lvl == prev);
            prev = lvl;
            if (ones == 6) ones = 0;            // a stuffed zero
            else begin
                ones = b ? ones + 1 : 0;
                cur[nb % 8] = b;
                nb++;
                if (nb % 8 == 0) begin pkt.push_back(cur); cur = 8'h0; end
            end
            #(BIT);
        end
        while (!(dp && !dn)) #(BIT / 4);        // the EOP's J
        #(BIT);
        last_idle = $realtime;
        if (pkt.size() == 0 || pkt[0] != 8'h80) return;
        pkt.pop_front();
        ok = (pkt.size() > 0) && (pkt[0][3:0] == ~pkt[0][7:4]);
    endtask

    task automatic gap();
        #(BIT * 4);
    endtask

    // A transaction starts at least four bit times after the bus last went
    // idle: the device may still drive the J that ends its EOP for a bit
    // after the host sees it, and a packet started on top of it is lost.
    realtime last_idle = 0;

    task automatic lock();
        while (bus_busy) #(BIT);
        bus_busy = 1;
        while ($realtime - last_idle < BIT * 4) #(BIT / 4);
    endtask

    task automatic unlock();
        bus_busy = 0;
    endtask

    task automatic token(input byte pid, input logic [6:0] a, input logic [3:0] ep);
        logic [15:0] f;
        f = {crc5({ep, a}), ep, a};
        tx('{pid, f[7:0], f[15:8]});
    endtask

    task automatic data(input bit d1, input byte payload[$]);
        logic [15:0] c;
        byte p[$];
        c = crc16(payload);
        p = payload;
        p.push_front(d1 ? PID_DATA1 : PID_DATA0);
        p.push_back(c[7:0]);
        p.push_back(c[15:8]);
        tx(p);
    endtask

    // ---- transactions ----
    task automatic setup_stage(input logic [6:0] a, input byte s[$], output int st);
        byte h[$];
        bit ok;
        for (int tries = 0; tries < 200; tries++) begin
            lock();
            token(PID_SETUP, a, 4'd0);
            gap();
            data(1'b0, s);
            rx(h, ok, 64);
            unlock();
            if (debug) $display("USB t=%0t SETUP %0d ok=%0d pid=%02x", $time, a, ok, ok ? h[0] : 8'h0);
            if (ok && h[0] == PID_ACK) begin st = ST_ACK; return; end
            #(20us);
        end
        st = ST_TIMEOUT;
    endtask

    task automatic in_stage(input logic [6:0] a, input logic [3:0] ep, inout bit tog,
                            output byte d[$], output int st);
        byte p[$];
        byte pay[$];
        logic [15:0] c;
        bit ok;
        d.delete();
        pay.delete();
        lock();
        token(PID_IN, a, ep);
        rx(p, ok, 64);
        if (!ok) st = ST_TIMEOUT;
        else if (p[0] == PID_NAK) st = ST_NAK;
        else if (p[0] == PID_STALL) st = ST_STALL;
        else if (p[0] == PID_DATA0 || p[0] == PID_DATA1) begin
            if (p.size() < 3) st = ST_ERR;
            else begin
                // PID, the payload, then the CRC16 low byte first.
                c = {p[p.size() - 1], p[p.size() - 2]};
                for (int k = 1; k < p.size() - 2; k++) pay.push_back(p[k]);
                if (crc16(pay) != c) st = ST_ERR;
                else begin
                    gap();
                    tx('{PID_ACK});
                    st = ST_DATA;
                    if ((p[0] == PID_DATA1) == tog) begin d = pay; tog = !tog; end
                end
            end
        end else st = ST_ERR;
        unlock();
        if (debug) $display("USB t=%0t IN %0d.%0d st=%0d n=%0d", $time, a, ep, st, d.size());
        if (debug && st == ST_ERR) begin
            string h = "";
            foreach (p[k]) h = {h, $sformatf(" %02x", p[k])};
            $display("USB   bad packet:%s", h);
        end
    endtask

    task automatic out_stage(input logic [6:0] a, input logic [3:0] ep, inout bit tog,
                             input byte d[$], output int st);
        byte h[$];
        bit ok;
        lock();
        token(PID_OUT, a, ep);
        gap();
        data(tog, d);
        rx(h, ok, 64);
        unlock();
        if (!ok) st = ST_TIMEOUT;
        else if (h[0] == PID_ACK) begin st = ST_ACK; tog = !tog; end
        else if (h[0] == PID_NAK) st = ST_NAK;
        else if (h[0] == PID_STALL) st = ST_STALL;
        else st = ST_ERR;
        if (debug) $display("USB t=%0t OUT %0d.%0d st=%0d n=%0d", $time, a, ep, st, d.size());
    endtask

    task automatic control_in(input logic [6:0] a, input byte s[$], output byte d[$]);
        int st, want;
        bit tog;
        byte part[$], z[$];
        d.delete();
        want = {s[7], s[6]};
        setup_stage(a, s, st);
        if (st != ST_ACK) begin fail("SETUP not acknowledged"); return; end
        tog = 1;
        for (int tries = 0; tries < 2000 && d.size() < want; tries++) begin
            in_stage(a, 4'd0, tog, part, st);
            if (st == ST_DATA) begin
                d = {d, part};
                if (part.size() < 64) break;
            end else if (st == ST_STALL) begin fail("control IN stalled"); return; end
            else #(10us);
        end
        tog = 1;
        for (int tries = 0; tries < 2000; tries++) begin
            out_stage(a, 4'd0, tog, z, st);
            if (st == ST_ACK) return;
            #(10us);
        end
        fail("control IN status stage");
    endtask

    task automatic control_out(input logic [6:0] a, input byte s[$], input byte d[$]);
        int st;
        bit tog;
        byte part[$];
        setup_stage(a, s, st);
        if (st != ST_ACK) begin fail("SETUP not acknowledged"); return; end
        tog = 1;
        if (d.size() > 0)
            for (int tries = 0; tries < 2000; tries++) begin
                out_stage(a, 4'd0, tog, d, st);
                if (st == ST_ACK) break;
                if (st == ST_STALL) begin fail("control OUT stalled"); return; end
                #(10us);
            end
        tog = 1;
        for (int tries = 0; tries < 2000; tries++) begin
            in_stage(a, 4'd0, tog, part, st);
            if (st == ST_DATA) return;
            if (st == ST_STALL) begin fail("control status stalled"); return; end
            #(10us);
        end
        fail("control OUT status stage");
    endtask

    // ---- frames ----
    initial forever begin
        #(1ms);
        if (sof_on) begin
            lock();
            token(PID_SOF, 7'(frame), 4'(frame >> 7));
            if (debug) $display("USB t=%0t SOF %0d", $time, frame);
            frame = (frame + 1) % 2048;
            unlock();
        end
    end

    // ---- enumeration ----
    task automatic enumerate();
        byte d[$];
        wait (dp === 1'b1 && dn === 1'b0);      // the device's pull-up
        #(100us);
        oe = 1'b1; odp = 1'b0; odn = 1'b0;      // reset: SE0 for 10 ms
        #(10.5ms);
        odp = 1'b1;
        #(BIT);
        oe = 1'b0;
        sof_on = 1;
        #(2ms);
        control_in(7'd0, '{8'h80, 8'h06, 8'h00, 8'h01, 8'h00, 8'h00, 8'h40, 8'h00}, d);
        if (failed) return;
        if (d.size() < 18 || d[0] != 8'd18 || d[1] != 8'h01) begin fail("device descriptor"); return; end
        if ({d[9], d[8]} != 16'h1209 || {d[11], d[10]} != 16'h5550) begin fail("VID:PID"); return; end
        control_out(7'd0, '{8'h00, 8'h05, 8'(ADDR), 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}, '{});
        if (failed) return;
        #(2ms);
        control_in(ADDR, '{8'h80, 8'h06, 8'h00, 8'h02, 8'h00, 8'h00, 8'h09, 8'h00}, d);
        if (failed) return;
        if (d.size() != 9 || d[1] != 8'h02) begin fail("configuration descriptor"); return; end
        control_in(ADDR, '{8'h80, 8'h06, 8'h00, 8'h02, 8'h00, 8'h00, d[2], d[3]}, d);
        if (failed) return;
        control_out(ADDR, '{8'h00, 8'h09, 8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}, '{});
        if (failed) return;
        tog_out = 0;
        tog_in = 0;
        control_out(ADDR, '{8'h21, 8'h20, 8'h00, 8'h00, 8'h00, 8'h00, 8'h07, 8'h00},
                    '{8'h00, 8'hC2, 8'h01, 8'h00, 8'h00, 8'h00, 8'h08});
        if (failed) return;
        control_out(ADDR, '{8'h21, 8'h22, 8'h03, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}, '{});
        if (failed) return;
        configured = 1;
        $display("USB_ENUM t=%0t configured", $time);
    endtask

    // ---- data pump: one OUT packet if anything is queued, then one IN poll ----
    initial forever begin
        if (pump_on) begin
            byte d[$], got[$];
            int st;
            if (txq.size() > 0) begin
                int n;
                n = (txq.size() > 64) ? 64 : txq.size();
                d.delete();
                for (int k = 0; k < n; k++) d.push_back(txq[k]);
                out_stage(ADDR, 4'd2, tog_out, d, st);
                if (st == ST_ACK) begin
                    repeat (n) void'(txq.pop_front());
                    tx_total += n;
                end
            end
            in_stage(ADDR, 4'd2, tog_in, got, st);
            if (st == ST_DATA)
                foreach (got[k]) begin
                    rxmem[rx_n % 65536] = got[k];
                    rx_n++;
                end
            if (st != ST_DATA && txq.size() == 0) #(20us);
            else #(BIT * 8);
        end else #(10us);
    end

    // ---- the script ----
    function automatic string unescape(input string s);
        string o = "";
        for (int i = 0; i < s.len(); i++) begin
            if (s[i] == "\\" && i + 1 < s.len()) begin
                i++;
                case (s[i])
                    "r": o = {o, "\r"};
                    "n": o = {o, "\n"};
                    "t": o = {o, "\t"};
                    "x": begin
                        int v;
                        string h;
                        h = s.substr(i + 1, i + 2);
                        void'($sscanf(h, "%h", v));
                        o = {o, $sformatf("%c", 8'(v))};
                        i += 2;
                    end
                    default: o = {o, s.substr(i, i)};
                endcase
            end else o = {o, s.substr(i, i)};
        end
        return o;
    endfunction

    int rx_mark = 0;

    // The loopback bytes: printable ASCII, so no Ctrl-C and no UTF-8 to
    // decode on the hart.
    function automatic logic [7:0] pattern(input int i);
        return 8'(32 + (i * 7 + i / 95) % 95);
    endfunction

    function automatic bit rx_contains(input string pat, output int at);
        for (int i = rx_mark; i + pat.len() <= rx_n; i++) begin
            bit m = 1;
            for (int j = 0; j < pat.len() && m; j++)
                if (rxmem[(i + j) % 65536] != pat[j]) m = 0;
            if (m) begin at = i + pat.len(); return 1; end
        end
        return 0;
    endfunction

    task automatic run_script(input string path);
        int fd, n;
        string line, cmd, arg;
        fd = $fopen(path, "r");
        if (fd == 0) begin fail({"cannot open ", path}); return; end
        while (!$feof(fd) && !failed && !done) begin
            line = "";
            void'($fgets(line, fd));
            while (line.len() > 0 && (line[line.len() - 1] == "\n" || line[line.len() - 1] == "\r"))
                line = line.substr(0, line.len() - 2);
            if (line.len() == 0 || line[0] == "#") continue;
            cmd = line;
            arg = "";
            for (int i = 0; i < line.len(); i++)
                if (line[i] == " ") begin
                    cmd = line.substr(0, i - 1);
                    arg = line.substr(i + 1, line.len() - 1);
                    break;
                end
            if (cmd == "text") begin
                string t;
                t = unescape(arg);
                for (int i = 0; i < t.len(); i++) txq.push_back(t[i]);
            end else if (cmd == "send") begin
                for (int i = 0; i + 1 < arg.len(); i += 2) begin
                    int v;
                    void'($sscanf(arg.substr(i, i + 1), "%h", v));
                    txq.push_back(8'(v));
                end
            end else if (cmd == "wait") begin
                string t;
                int at;
                realtime t0;
                t = unescape(arg);
                t0 = $realtime;
                while (!rx_contains(t, at)) begin
                    if ($realtime - t0 > 400ms) begin fail({"timeout waiting for: ", arg}); break; end
                    #(20us);
                end
                if (!failed) rx_mark = at;
            end else if (cmd == "sleep") begin
                void'($sscanf(arg, "%d", n));
                #(n * 1us);
            end else if (cmd == "suspend") begin
                void'($sscanf(arg, "%d", n));
                pump_on = 0;
                while (bus_busy) #(BIT);
                sof_on = 0;
                #(n * 1ms);
                suspends++;
                lock();
                oe = 1'b1; odp = 1'b0; odn = 1'b1;  // resume: K
                #(1ms);
                odp = 1'b0; odn = 1'b0; #(BIT); #(BIT);
                odp = 1'b1; #(BIT);
                oe = 1'b0;
                unlock();
                sof_on = 1;
                #(2ms);
                pump_on = 1;
                $display("USB_RESUME t=%0t after %0d ms suspended", $time, n);
            end else if (cmd == "loopback") begin
                realtime t0;
                int base;
                void'($sscanf(arg, "%d", n));
                base = rx_n;
                t0 = $realtime;
                for (int i = 0; i < n; i++) txq.push_back(pattern(i));
                while (rx_n < base + n && !failed) begin
                    if ($realtime - t0 > 400ms) fail("loopback timeout");
                    #(20us);
                end
                for (int i = 0; i < n && !failed; i++)
                    if (rxmem[(base + i) % 65536] != pattern(i))
                        fail($sformatf("loopback byte %0d", i));
                if (!failed) begin
                    realtime dt;
                    dt = $realtime - t0;
                    $display("USB_LOOPBACK bytes=%0d ns=%0d bytes_per_s=%0d", n, longint'(dt),
                             longint'(n * 1.0e9 / dt));
                end
                rx_mark = rx_n;
            end else if (cmd == "finish") begin
                done = 1;
            end else fail({"unknown script command: ", cmd});
        end
        $fclose(fd);
        if (!failed) done = 1;
    endtask

    initial begin
        string path;
        if ($value$plusargs("USB_SCRIPT=%s", path)) begin
            active = 1;
            enumerate();
            if (!failed) begin
                pump_on = 1;
                run_script(path);
            end
        end
    end
endmodule
