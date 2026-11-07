// =============================================================================
// uart_seq.sv
// Simple UART sequence — sends 3 bytes serially on uart_rx_i via the driver.
// The driver receives each uart_vip_item and injects it as an 8N1 serial frame.
// =============================================================================

class uart_seq extends uvm_sequence #(uart_vip_item);
    `uvm_object_utils(uart_seq)

    function new(string name = "uart_seq");
        super.new(name);
    endfunction

    task body();
        uart_vip_item item;

        // --- Byte 1: 0x55 = 0101_0101 (alternating pattern) ---
        item = uart_vip_item::type_id::create("item");
        start_item(item);
        item.tx_byte    = 8'h55;
        item.expect_irq = 1'b1;
        finish_item(item);
        `uvm_info("UART_SEQ", $sformatf("Sent byte 0x%02h", item.tx_byte), UVM_MEDIUM)

        // --- Byte 2: 0xA5 = 1010_0101 ---
        item = uart_vip_item::type_id::create("item");
        start_item(item);
        item.tx_byte    = 8'hA5;
        item.expect_irq = 1'b1;
        finish_item(item);
        `uvm_info("UART_SEQ", $sformatf("Sent byte 0x%02h", item.tx_byte), UVM_MEDIUM)

        // --- Byte 3: 0xFF = 1111_1111 (all ones) ---
        item = uart_vip_item::type_id::create("item");
        start_item(item);
        item.tx_byte    = 8'hFF;
        item.expect_irq = 1'b1;
        finish_item(item);
        `uvm_info("UART_SEQ", $sformatf("Sent byte 0x%02h", item.tx_byte), UVM_MEDIUM)

    endtask

endclass
