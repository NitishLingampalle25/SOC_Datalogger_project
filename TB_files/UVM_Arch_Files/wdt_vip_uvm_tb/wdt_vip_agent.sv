`timescale 1ns/1ps
// =============================================================================
// wdt_vip_agent.sv — UVM agent for WDT VIP
//
// Active agent: contains driver, monitor, and sequencer.
// Driver seq_item_port is connected to sequencer seq_item_export in
// connect_phase.  Monitor analysis port (ap) is left open for the
// environment to connect to the scoreboard.
// =============================================================================
class wdt_vip_agent extends uvm_agent;

  wdt_vip_driver    drv;
  wdt_vip_monitor   mon;
  wdt_vip_sequencer seqr;

  `uvm_component_utils(wdt_vip_agent)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: construct all sub-components
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv  = wdt_vip_driver::type_id::create("drv",  this);
    mon  = wdt_vip_monitor::type_id::create("mon",  this);
    seqr = wdt_vip_sequencer::type_id::create("seqr", this);
  endfunction

  // ---------------------------------------------------------------------------
  // connect_phase: wire driver to sequencer
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction

endclass
