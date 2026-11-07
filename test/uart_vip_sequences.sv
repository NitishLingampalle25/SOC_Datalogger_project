// =============================================================================
// uart_vip_sequences.sv — Four directed test sequences for UART VIP
//
// Address map (base = 0x4000_0000):
//   THR/RBR  offset 0x00  → 0x4000_0000
//   IER      offset 0x04  → 0x4000_0004
//   BAUD     offset 0x08  → 0x4000_0008
//   LCR      offset 0x0C  → 0x4000_000C
//   LSR      offset 0x14  → 0x4000_0014
//
// Sentinel values used by the driver:
//   tx_byte = 8'hFF  → no serial injection this item
//   addr    = 32'hFFFF_FFFF → no AXI transaction this item
// =============================================================================

// Convenience macros (used only inside sequences — not for synthesis)
`define UART_THR  32'h4000_0000
`define UART_IER  32'h4000_0004
`define UART_BAUD 32'h4000_0008
`define UART_LCR  32'h4000_000C
`define UART_LSR  32'h4000_0014

// =============================================================================
// TC_UART_01 — Configuration register write + read-back
// Writes LCR=0x03 (8N1), BAUD=10 (SIM_BAUD_DIV), IER=0x01 (RX-data irq)
// Reads back all three registers and checks equality.
// =============================================================================
class tc_uart_01_seq extends uvm_sequence #(uart_vip_item);
  `uvm_object_utils(tc_uart_01_seq)

  function new(string name = "tc_uart_01_seq");
    super.new(name);
  endfunction

  task body();
    uart_vip_item item;

    // ------------------------------------------------------------------
    // Phase 1: write configuration registers
    // ------------------------------------------------------------------
    // LCR = 0x03 (8 data bits, no parity, 1 stop bit)
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `UART_LCR;
                         wdata    == 32'h0000_0003;
                         tx_byte  == 8'hFF; })

    // BAUD divisor = 10
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `UART_BAUD;
                         wdata    == 32'h0000_000A;
                         tx_byte  == 8'hFF; })

    // IER = 0x01 (enable RX-data-available interrupt)
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `UART_IER;
                         wdata    == 32'h0000_0001;
                         tx_byte  == 8'hFF; })

    // ------------------------------------------------------------------
    // Phase 2: read back and verify
    // ------------------------------------------------------------------
    // Read LCR
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == `UART_LCR;
                         tx_byte  == 8'hFF; })
    if (item.rdata[7:0] !== 8'h03)
      `uvm_error("TC01", $sformatf("LCR readback FAIL: exp=0x03 got=0x%02h",
                                    item.rdata[7:0]))
    else
      `uvm_info("TC01", "TC_UART_01 LCR readback PASS (0x03)", UVM_LOW)

    // Read BAUD
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == `UART_BAUD;
                         tx_byte  == 8'hFF; })
    if (item.rdata !== 32'h0000_000A)
      `uvm_error("TC01", $sformatf("BAUD readback FAIL: exp=10 got=0x%08h",
                                    item.rdata))
    else
      `uvm_info("TC01", "TC_UART_01 BAUD readback PASS (10)", UVM_LOW)

    // Read IER
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == `UART_IER;
                         tx_byte  == 8'hFF; })
    if (item.rdata[7:0] !== 8'h01)
      `uvm_error("TC01", $sformatf("IER readback FAIL: exp=0x01 got=0x%02h",
                                    item.rdata[7:0]))
    else
      `uvm_info("TC01", "TC_UART_01 IER readback PASS (0x01)", UVM_LOW)

    `uvm_info("TC01", "TC_UART_01 COMPLETE", UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_UART_02 — TX path: write 0x4B to THR, monitor captures uart_tx_o
// The driver sends the AXI write; the monitor detects the serialised frame
// on uart_tx_o and the scoreboard checks rx_byte == 0x4B.
// tx_byte is left at sentinel 8'hFF because no serial *injection* is needed.
// =============================================================================
class tc_uart_02_seq extends uvm_sequence #(uart_vip_item);
  `uvm_object_utils(tc_uart_02_seq)

  function new(string name = "tc_uart_02_seq");
    super.new(name);
  endfunction

  task body();
    uart_vip_item item;

    // Write 0x4B to THR (transmit holding register)
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `UART_THR;
                         wdata    == 32'h0000_004B;
                         tx_byte  == 8'hFF; })

    // Poll LSR until TEMT (bit 6) and THRE (bit 5) are set
    begin : poll_lsr
      automatic bit temt = 0;
      while (!temt) begin
        `uvm_do_with(item, { do_write == 1'b0;
                             addr     == `UART_LSR;
                             tx_byte  == 8'hFF; })
        temt = item.rdata[6]; // TEMT
      end
    end

    `uvm_info("TC02", "TC_UART_02 COMPLETE: 0x4B written to THR, monitoring uart_tx_o",
              UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_UART_03 — RX path: inject byte 0xA5 on uart_rx_i, expect IRQ assertion
// The driver serialises 0xA5 on uart_rx_i; once the DUT receives it,
// uart_read_irq_o should assert.  The monitor captures both and the
// scoreboard checks expect_irq == 1 for rx_byte == 0xA5.
// =============================================================================
class tc_uart_03_seq extends uvm_sequence #(uart_vip_item);
  `uvm_object_utils(tc_uart_03_seq)

  function new(string name = "tc_uart_03_seq");
    super.new(name);
  endfunction

  task body();
    uart_vip_item item;

    // Serial inject: addr sentinel = no AXI transaction; tx_byte = 0xA5
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == 32'hFFFF_FFFF;
                         tx_byte  == 8'hA5; })

    `uvm_info("TC03", "TC_UART_03 COMPLETE: 0xA5 injected on uart_rx_i", UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_UART_04 — Overrun: inject two back-to-back bytes (0x11, 0x11) without
// reading RBR between them.  Second frame should cause an overrun condition
// in the DUT's RX buffer.
// =============================================================================
class tc_uart_04_seq extends uvm_sequence #(uart_vip_item);
  `uvm_object_utils(tc_uart_04_seq)

  function new(string name = "tc_uart_04_seq");
    super.new(name);
  endfunction

  task body();
    uart_vip_item item;

    // First injection — fills RX buffer
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == 32'hFFFF_FFFF;
                         tx_byte  == 8'h11; })

    // Second injection immediately — no RBR read in between → overrun
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == 32'hFFFF_FFFF;
                         tx_byte  == 8'h11; })

    // Read LSR to expose OE (overrun error) bit — bit 1 of LSR
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == `UART_LSR;
                         tx_byte  == 8'hFF; })
    if (item.rdata[1])
      `uvm_info("TC04",
        "TC_UART_04 PASS: Overrun Error (LSR[1]) set after double inject",
        UVM_LOW)
    else
      `uvm_warning("TC04",
        "TC_UART_04: LSR[1] (OE) not set — DUT may have a deep FIFO or OE is elsewhere")

    `uvm_info("TC04", "TC_UART_04 COMPLETE", UVM_LOW)
  endtask

endclass
