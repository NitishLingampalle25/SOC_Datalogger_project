// dma_vip_item.sv — DMA VIP sequence item
`timescale 1ns/1ps
class dma_vip_item extends uvm_sequence_item;
    // Register access fields (used in sequences)
    rand bit        do_write;
    rand bit [31:0] addr;
    rand bit [31:0] wdata;
    bit      [31:0] rdata;
    bit      [1:0]  resp;

    // Pin-level observation fields (used in monitor & scoreboard)
    bit dma_done;
    bit dma_error;
    bit dma_irq;

    // Backward compatibility aliases
    bit dma_done_o;
    bit dma_error_o;
    bit dma_irq_o;

    `uvm_object_utils_begin(dma_vip_item)
        `uvm_field_int(do_write,    UVM_ALL_ON)
        `uvm_field_int(addr,        UVM_ALL_ON)
        `uvm_field_int(wdata,       UVM_ALL_ON)
        `uvm_field_int(rdata,       UVM_ALL_ON)
        `uvm_field_int(dma_done,    UVM_ALL_ON)
        `uvm_field_int(dma_error,   UVM_ALL_ON)
        `uvm_field_int(dma_irq,     UVM_ALL_ON)
        `uvm_field_int(dma_done_o,  UVM_ALL_ON)
        `uvm_field_int(dma_error_o, UVM_ALL_ON)
        `uvm_field_int(dma_irq_o,   UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "dma_vip_item"); super.new(name); endfunction
endclass
