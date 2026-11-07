`timescale 1ns/1ps
// =============================================================================
// systimer_vip_env.sv — UVM environment for SysTimer VIP
//
// Contains one active agent and one scoreboard.
// Wires agent.mon.ap → sb.ap in connect_phase so that every IRQ event
// observed by the monitor reaches the scoreboard for TC_TMR_02 checking.
// =============================================================================
class systimer_vip_env extends uvm_env;

  systimer_vip_agent      agent;
  systimer_vip_scoreboard sb;

  `uvm_component_utils(systimer_vip_env)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: construct agent and scoreboard
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = systimer_vip_agent::type_id::create("agent", this);
    sb    = systimer_vip_scoreboard::type_id::create("sb",    this);
  endfunction

  // ---------------------------------------------------------------------------
  // connect_phase: monitor analysis port → scoreboard
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    agent.mon.ap.connect(sb.ap);
  endfunction

endclass
