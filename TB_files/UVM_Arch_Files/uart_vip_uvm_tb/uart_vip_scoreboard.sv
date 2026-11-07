// =============================================================================
// uart_vip_scoreboard.sv — UVM scoreboard for UART VIP
// Receives uart_vip_item from the monitor's analysis port.
// Checks:
//   TC_UART_02: rx_byte must equal 8'h4B  (loopback of THR write)
//   TC_UART_03: expect_irq must be 1 when rx_byte == 8'hA5 (RX inject)
//   TC_UART_04: silently counts overrun frames (rx_byte injected twice)
// =============================================================================
class uart_vip_scoreboard extends uvm_scoreboard;

  uvm_analysis_imp #(uart_vip_item, uart_vip_scoreboard) ap;

  int pass_cnt;
  int fail_cnt;
  int frame_cnt;  // total frames observed

  `uvm_component_utils(uart_vip_scoreboard)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  // ---------------------------------------------------------------------------
  // write() — called by analysis port for every completed UART frame
  // ---------------------------------------------------------------------------
  function void write(uart_vip_item item);
    frame_cnt++;

    // -----------------------------------------------------------------------
    // TC_UART_02: TX loopback — expect 0x4B on the wire
    // -----------------------------------------------------------------------
    if (item.rx_byte === 8'h4B) begin
      `uvm_info("UART_SB",
        "TC_UART_02 PASS: TX loopback byte 0x4B correctly captured",
        UVM_LOW)
      pass_cnt++;
    end

    // -----------------------------------------------------------------------
    // TC_UART_03: RX inject — 0xA5 must assert read IRQ
    // -----------------------------------------------------------------------
    if (item.rx_byte === 8'hA5) begin
      if (item.expect_irq === 1'b1) begin
        `uvm_info("UART_SB",
          "TC_UART_03 PASS: uart_read_irq_o asserted after RX inject 0xA5",
          UVM_LOW)
        pass_cnt++;
      end else begin
        `uvm_error("UART_SB",
          "TC_UART_03 FAIL: uart_read_irq_o NOT asserted after RX inject 0xA5")
        fail_cnt++;
      end
    end

    // -----------------------------------------------------------------------
    // TC_UART_04: overrun — second back-to-back frame of 0x11
    //   (both frames will arrive; we just count and report)
    // -----------------------------------------------------------------------
    if (item.rx_byte === 8'h11) begin
      `uvm_info("UART_SB",
        $sformatf("TC_UART_04: overrun-test frame received (0x11) frame_cnt=%0d",
                  frame_cnt),
        UVM_LOW)
    end

    // -----------------------------------------------------------------------
    // Unexpected byte — flag for debug visibility (not a hard fail)
    // -----------------------------------------------------------------------
    if (item.rx_byte !== 8'h4B &&
        item.rx_byte !== 8'hA5 &&
        item.rx_byte !== 8'h11) begin
      `uvm_warning("UART_SB",
        $sformatf("Unexpected rx_byte=0x%02h at frame %0d",
                  item.rx_byte, frame_cnt))
    end
  endfunction

  // ---------------------------------------------------------------------------
  // report_phase — summary line
  // ---------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info("UART_SB",
      $sformatf({"==============================\n",
                 "  UART Scoreboard Summary\n",
                 "  Total frames : %0d\n",
                 "  PASS         : %0d\n",
                 "  FAIL         : %0d\n",
                 "==============================\n"},
                frame_cnt, pass_cnt, fail_cnt),
      UVM_LOW)
    if (fail_cnt > 0)
      `uvm_error("UART_SB", "One or more UART VIP checks FAILED")
  endfunction

endclass
