`timescale 1ns/1ps
// =============================================================================
// wdt_vip_sequencer.sv — UVM sequencer for WDT VIP
//
// Thin wrapper over uvm_sequencer — no custom arbitration needed.
// =============================================================================
class wdt_vip_sequencer extends uvm_sequencer #(wdt_vip_item);
  `uvm_component_utils(wdt_vip_sequencer)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

endclass
