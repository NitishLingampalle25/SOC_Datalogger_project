// uart_vip_item.sv — UART VIP sequence item
`timescale 1ns/1ps
class uart_vip_item extends uvm_sequence_item;
    // Register access fields (used in sequences)
    rand bit        do_write;
    rand bit [31:0] addr;
    rand bit [31:0] wdata;
    bit      [31:0] rdata;
    bit      [1:0]  resp;

    // Pin-level fields
    rand bit [7:0] tx_byte;      // byte to drive on uart_rx_i; 8'hFF = no-op
    bit      [7:0] rx_byte;      // byte sampled from uart_tx_o by monitor
    bit            expect_irq;   // observe uart_read_irq_o after injection

    `uvm_object_utils_begin(uart_vip_item)
        `uvm_field_int(do_write,   UVM_ALL_ON)
        `uvm_field_int(addr,       UVM_ALL_ON)
        `uvm_field_int(wdata,      UVM_ALL_ON)
        `uvm_field_int(rdata,      UVM_ALL_ON)
        `uvm_field_int(resp,       UVM_ALL_ON)
        `uvm_field_int(tx_byte,    UVM_ALL_ON)
        `uvm_field_int(rx_byte,    UVM_ALL_ON)
        `uvm_field_int(expect_irq, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "uart_vip_item"); super.new(name); endfunction
endclass
