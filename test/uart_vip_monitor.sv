// =============================================================================
// uart_vip_monitor.sv — UVM monitor for UART VIP
// Passively observes uart_tx_o (DUT TX output) and uart_read_irq_o.
// Detects start bit (falling edge), samples 8 data bits at mid-bit,
// verifies stop bit, broadcasts uart_vip_item on analysis port.
// BIT_CYCLES = 10 matches SIM_BAUD_DIV.
// =============================================================================
class uart_vip_monitor extends uvm_monitor;

  virtual uart_vip_if       vif;
  uvm_analysis_port #(uart_vip_item) ap;

  localparam int BIT_CYCLES = 10;

  `uvm_component_utils(uart_vip_monitor)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: grab virtual interface
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual uart_vip_if)::get(this, "", "uart_vif", vif))
      `uvm_fatal("NOVIF", "uart_vip_monitor: virtual interface uart_vif not found in config DB")
  endfunction

  // ---------------------------------------------------------------------------
  // run_phase: infinite loop — one iteration per received UART frame
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    uart_vip_item item;

    forever begin
      // -----------------------------------------------------------------------
      // 1. Wait for falling edge on uart_tx_o = start bit
      // -----------------------------------------------------------------------
      @(negedge vif.uart_tx_o);

      item = uart_vip_item::type_id::create("mon_item");

      // -----------------------------------------------------------------------
      // 2. Advance to mid-point of the start bit, then one full bit period
      //    so we land at the mid-point of bit 0
      // -----------------------------------------------------------------------
      repeat (BIT_CYCLES / 2) @(posedge vif.clk);  // mid start bit
      repeat (BIT_CYCLES)     @(posedge vif.clk);  // advance to mid bit-0

      // -----------------------------------------------------------------------
      // 3. Sample 8 data bits, LSB first (bit 0 already aligned above)
      // -----------------------------------------------------------------------
      for (int i = 0; i < 8; i++) begin
        item.rx_byte[i] = vif.uart_tx_o;
        if (i < 7)
          repeat (BIT_CYCLES) @(posedge vif.clk); // advance to next mid-bit
      end

      // -----------------------------------------------------------------------
      // 4. Advance past bit-7 into stop-bit window and verify stop bit = 1
      // -----------------------------------------------------------------------
      repeat (BIT_CYCLES) @(posedge vif.clk);
      if (!vif.uart_tx_o)
        `uvm_error("UART_MON", $sformatf(
          "Framing error: stop bit not HIGH for byte 0x%02h", item.rx_byte))

      // -----------------------------------------------------------------------
      // 5. Capture interrupt line state (valid after full frame)
      // -----------------------------------------------------------------------
      item.expect_irq = vif.uart_read_irq_o;

      `uvm_info("UART_MON",
        $sformatf("Captured TX byte=0x%02h  irq=%0b",
                  item.rx_byte, item.expect_irq),
        UVM_MEDIUM)

      ap.write(item);
    end
  endtask

endclass
