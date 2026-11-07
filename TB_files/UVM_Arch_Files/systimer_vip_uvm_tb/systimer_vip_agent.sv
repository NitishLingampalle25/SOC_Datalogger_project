`timescale 1ns/1ps
// =============================================================================
// systimer_vip_agent.sv — UVM agent for SysTimer VIP
//
// Active agent: instantiates the driver, monitor, and sequencer.
// The driver seq_item_port is connected to the sequencer seq_item_export.
// The monitor's analysis port (ap) is left open here and connected to the
// scoreboard by the enclosing environment in connect_phase.
// =============================================================================
class systimer_vip_agent extends uvm_agent;

  systimer_vip_driver    drv;
  systimer_vip_monitor   mon;
  systimer_vip_sequencer seqr;

  `uvm_component_utils(systimer_vip_agent)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: construct driver, monitor, and sequencer
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv  = systimer_vip_driver::type_id::create("drv",  this);
    mon  = systimer_vip_monitor::type_id::create("mon",  this);
    seqr = systimer_vip_sequencer::type_id::create("seqr", this);
  endfunction

  // ---------------------------------------------------------------------------
  // connect_phase: wire driver's TLM port to sequencer's export
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction

endclass
