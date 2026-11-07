`timescale 1ns/1ps
//=============================================================================
// aes_vip_sequencer.sv
// AES VIP Sequencer — thin UVM sequencer wrapper for aes_vip_item
//=============================================================================

class aes_vip_sequencer extends uvm_sequencer #(aes_vip_item);

  `uvm_component_utils(aes_vip_sequencer)

  function new(string name = "aes_vip_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass : aes_vip_sequencer
