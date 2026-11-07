`timescale 1ns/1ps
// =============================================================================
// systimer_vip_sequencer.sv — UVM sequencer for SysTimer VIP
//
// Thin wrapper around uvm_sequencer parameterised on systimer_vip_item.
// No custom arbitration logic required — UVM base handles scheduling.
// =============================================================================
class systimer_vip_sequencer extends uvm_sequencer #(systimer_vip_item);

  `uvm_component_utils(systimer_vip_sequencer)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

endclass
