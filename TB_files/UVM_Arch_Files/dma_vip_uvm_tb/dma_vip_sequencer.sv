`timescale 1ns/1ps
// =============================================================================
// dma_vip_sequencer.sv — UVM sequencer for DMA VIP
// Thin wrapper; UVM base class handles all arbitration.
// =============================================================================
class dma_vip_sequencer extends uvm_sequencer #(dma_vip_item);
  `uvm_component_utils(dma_vip_sequencer)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

endclass
