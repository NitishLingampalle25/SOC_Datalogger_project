// aes_vip_item.sv — AES VIP sequence item
`timescale 1ns/1ps
class aes_vip_item extends uvm_sequence_item;
    // Register access fields (used in sequences)
    rand bit        do_write;
    rand bit [31:0] addr;
    rand bit [31:0] wdata;
    bit      [31:0] rdata;
    bit      [1:0]  resp;

    // Pin observation fields (used in monitor & scoreboard)
    bit       aes_busy;        // sampled: engine processing
    bit       aes_done;        // sampled: encryption complete (level)
    bit       aes_done_pulse;  // sampled: single-cycle completion pulse
    bit       aes_irq;         // sampled: interrupt to PIC
    bit [31:0] exp_ct [4];     // expected FIPS-197 ciphertext words (scoreboard)

    // Aliases
    bit       aes_busy_o;
    bit       aes_done_o;
    bit       aes_done_pulse_o;
    bit       aes_irq_o;

    `uvm_object_utils_begin(aes_vip_item)
        `uvm_field_int(do_write,       UVM_ALL_ON)
        `uvm_field_int(addr,           UVM_ALL_ON)
        `uvm_field_int(wdata,          UVM_ALL_ON)
        `uvm_field_int(rdata,          UVM_ALL_ON)
        `uvm_field_int(resp,           UVM_ALL_ON)
        `uvm_field_int(aes_busy,       UVM_ALL_ON)
        `uvm_field_int(aes_done,       UVM_ALL_ON)
        `uvm_field_int(aes_done_pulse, UVM_ALL_ON)
        `uvm_field_int(aes_irq,        UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "aes_vip_item"); super.new(name); endfunction

    function string convert2string();
        return $sformatf("busy=%0b done=%0b pulse=%0b irq=%0b",
            aes_busy, aes_done, aes_done_pulse, aes_irq);
    endfunction
endclass
