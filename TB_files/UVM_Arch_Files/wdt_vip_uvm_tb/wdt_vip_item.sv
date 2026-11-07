// wdt_vip_item.sv — WDT VIP sequence item
`timescale 1ns/1ps
class wdt_vip_item extends uvm_sequence_item;
    // Register access fields (used in sequences)
    rand bit        do_write;
    rand bit [31:0] addr;
    rand bit [31:0] wdata;
    bit      [31:0] rdata;
    bit      [1:0]  resp;

    // Pin observation fields (used in monitor & scoreboard)
    bit wdt_irq;
    bit wdt_nmi;
    bit wdt_reset;
    bit wdt_timeout;

    // Aliases with _o
    bit wdt_irq_o;
    bit wdt_nmi_o;
    bit wdt_reset_o;
    bit wdt_timeout_o;

    `uvm_object_utils_begin(wdt_vip_item)
        `uvm_field_int(do_write,      UVM_ALL_ON)
        `uvm_field_int(addr,          UVM_ALL_ON)
        `uvm_field_int(wdata,         UVM_ALL_ON)
        `uvm_field_int(rdata,         UVM_ALL_ON)
        `uvm_field_int(resp,          UVM_ALL_ON)
        `uvm_field_int(wdt_irq,       UVM_ALL_ON)
        `uvm_field_int(wdt_nmi,       UVM_ALL_ON)
        `uvm_field_int(wdt_reset,     UVM_ALL_ON)
        `uvm_field_int(wdt_timeout,   UVM_ALL_ON)
        `uvm_field_int(wdt_irq_o,     UVM_ALL_ON)
        `uvm_field_int(wdt_nmi_o,     UVM_ALL_ON)
        `uvm_field_int(wdt_reset_o,   UVM_ALL_ON)
        `uvm_field_int(wdt_timeout_o, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "wdt_vip_item"); super.new(name); endfunction
endclass
