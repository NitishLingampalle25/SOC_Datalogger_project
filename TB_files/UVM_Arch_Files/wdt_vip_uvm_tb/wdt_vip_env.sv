`timescale 1ns/1ps
// =============================================================================
// wdt_vip_env.sv — UVM environment for WDT VIP
//
// Contains one active agent and one scoreboard.
// Connects agent.mon.ap → sb.ap in connect_phase so every edge event
// observed by the monitor is forwarded to the scoreboard.
// =============================================================================
class wdt_vip_env extends uvm_env;

  wdt_vip_agent      agent;
  wdt_vip_scoreboard sb;

  `uvm_component_utils(wdt_vip_env)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: construct agent and scoreboard
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = wdt_vip_agent::type_id::create("agent", this);
    sb    = wdt_vip_scoreboard::type_id::create("sb",    this);
  endfunction

  // ---------------------------------------------------------------------------
  // connect_phase: wire monitor analysis port to scoreboard
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    agent.mon.ap.connect(sb.ap);
  endfunction

endclass
