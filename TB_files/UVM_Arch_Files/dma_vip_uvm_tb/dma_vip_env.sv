`timescale 1ns/1ps
// =============================================================================
// dma_vip_env.sv — UVM environment for DMA VIP
//
// Contains one active agent and one scoreboard.
// connect_phase wires agent.mon.ap → sb.ap.
// =============================================================================
class dma_vip_env extends uvm_env;

  dma_vip_agent      agent;
  dma_vip_scoreboard sb;

  `uvm_component_utils(dma_vip_env)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: construct agent and scoreboard
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = dma_vip_agent::type_id::create("agent", this);
    sb    = dma_vip_scoreboard::type_id::create("sb",    this);
  endfunction

  // ---------------------------------------------------------------------------
  // connect_phase: monitor analysis port → scoreboard analysis imp
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    agent.mon.ap.connect(sb.ap);
  endfunction

endclass
