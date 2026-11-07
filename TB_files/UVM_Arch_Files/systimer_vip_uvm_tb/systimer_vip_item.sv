// systimer_vip_item.sv — SysTimer VIP sequence item
`timescale 1ns/1ps
class systimer_vip_item extends uvm_sequence_item;
    // Register access fields (used in sequences)
    rand bit        do_write;
    rand bit [31:0] addr;
    rand bit [31:0] wdata;
    bit      [31:0] rdata;
    bit      [1:0]  resp;

    // Pin observation fields (used in monitor & scoreboard)
    bit timer_irq_obs;
    bit timer_irq_o;

    `uvm_object_utils_begin(systimer_vip_item)
        `uvm_field_int(do_write,      UVM_ALL_ON)
        `uvm_field_int(addr,          UVM_ALL_ON)
        `uvm_field_int(wdata,         UVM_ALL_ON)
        `uvm_field_int(rdata,         UVM_ALL_ON)
        `uvm_field_int(resp,          UVM_ALL_ON)
        `uvm_field_int(timer_irq_obs, UVM_ALL_ON)
        `uvm_field_int(timer_irq_o,   UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "systimer_vip_item"); super.new(name); endfunction
endclass
