`timescale 1ns/1ps
// =============================================================================
// gpio_vip_sequencer.sv — UVM sequencer for GPIO VIP
// Thin wrapper; UVM base-class handles all TLM arbitration.
// =============================================================================
class gpio_vip_sequencer extends uvm_sequencer #(gpio_vip_item);
  `uvm_component_utils(gpio_vip_sequencer)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

endclass
