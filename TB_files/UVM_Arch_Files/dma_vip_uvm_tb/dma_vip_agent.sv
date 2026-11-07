`timescale 1ns/1ps
// =============================================================================
// dma_vip_agent.sv — UVM agent for DMA VIP
//
// Active agent: instantiates driver, monitor, and sequencer.
// Driver seq_item_port is connected to sequencer seq_item_export.
// Monitor analysis port is left open here; env connects it to the scoreboard.
// =============================================================================
class dma_vip_agent extends uvm_agent;

  dma_vip_driver    drv;
  dma_vip_monitor   mon;
  dma_vip_sequencer seqr;

  `uvm_component_utils(dma_vip_agent)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: construct all sub-components
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv  = dma_vip_driver::type_id::create("drv",  this);
    mon  = dma_vip_monitor::type_id::create("mon",  this);
    seqr = dma_vip_sequencer::type_id::create("seqr", this);
  endfunction

  // ---------------------------------------------------------------------------
  // connect_phase: wire driver TLM port to sequencer TLM export
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction

endclass
