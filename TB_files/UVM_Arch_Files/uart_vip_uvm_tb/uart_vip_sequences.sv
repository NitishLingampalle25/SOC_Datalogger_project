// =============================================================================
// uart_vip_sequences.sv — UART VIP sequences
//
// All sequences work with the current uart_vip_item which has only:
//   tx_byte    — byte to inject on uart_rx_i (8'hFF = no-op)
//   rx_byte    — captured from uart_tx_o by monitor
//   expect_irq — set 1 if IRQ assertion expected after this byte
//
// No AXI fields — register access is CPU-internal to the SoC.
// =============================================================================

// =============================================================================
// TC_UART_01 — Send single byte 0x55, expect IRQ
// =============================================================================
class tc_uart_01_seq extends uvm_sequence #(uart_vip_item);
  `uvm_object_utils(tc_uart_01_seq)

  function new(string name = "tc_uart_01_seq");
    super.new(name);
  endfunction

  task body();
    uart_vip_item item;

    `uvm_do_with(item, { tx_byte == 8'h55; expect_irq == 1'b1; })
    `uvm_info("TC01", $sformatf("Sent 0x%02h, expect_irq=%0b", item.tx_byte, item.expect_irq), UVM_LOW)

    `uvm_info("TC01", "TC_UART_01 COMPLETE", UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_UART_02 — Send byte 0x4B, expect IRQ
// =============================================================================
class tc_uart_02_seq extends uvm_sequence #(uart_vip_item);
  `uvm_object_utils(tc_uart_02_seq)

  function new(string name = "tc_uart_02_seq");
    super.new(name);
  endfunction

  task body();
    uart_vip_item item;

    `uvm_do_with(item, { tx_byte == 8'h4B; expect_irq == 1'b1; })
    `uvm_info("TC02", $sformatf("Sent 0x%02h, expect_irq=%0b", item.tx_byte, item.expect_irq), UVM_LOW)

    `uvm_info("TC02", "TC_UART_02 COMPLETE", UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_UART_03 — Send byte 0xA5, expect IRQ
// =============================================================================
class tc_uart_03_seq extends uvm_sequence #(uart_vip_item);
  `uvm_object_utils(tc_uart_03_seq)

  function new(string name = "tc_uart_03_seq");
    super.new(name);
  endfunction

  task body();
    uart_vip_item item;

    `uvm_do_with(item, { tx_byte == 8'hA5; expect_irq == 1'b1; })
    `uvm_info("TC03", $sformatf("Sent 0x%02h, expect_irq=%0b", item.tx_byte, item.expect_irq), UVM_LOW)

    `uvm_info("TC03", "TC_UART_03 COMPLETE: 0xA5 injected on uart_rx_i", UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_UART_04 — Send two back-to-back bytes 0x11, 0x11 (overrun test)
// =============================================================================
class tc_uart_04_seq extends uvm_sequence #(uart_vip_item);
  `uvm_object_utils(tc_uart_04_seq)

  function new(string name = "tc_uart_04_seq");
    super.new(name);
  endfunction

  task body();
    uart_vip_item item;

    // First byte — fills RX buffer
    `uvm_do_with(item, { tx_byte == 8'h11; expect_irq == 1'b1; })
    `uvm_info("TC04", "First 0x11 sent", UVM_LOW)

    // Second byte immediately — no read between → overrun
    `uvm_do_with(item, { tx_byte == 8'h11; expect_irq == 1'b1; })
    `uvm_info("TC04", "Second 0x11 sent (overrun expected)", UVM_LOW)

    `uvm_info("TC04", "TC_UART_04 COMPLETE", UVM_LOW)
  endtask

endclass
