`timescale 1ns/1ps
// =============================================================================
// gpio_vip_env.sv — UVM environment for GPIO VIP
//
// Contains one active agent and one scoreboard.
// Connects agent.mon.ap → sb.ap in connect_phase.
// =============================================================================
class gpio_vip_env extends uvm_env;

  gpio_vip_agent      agent;
  gpio_vip_scoreboard sb;

  `uvm_component_utils(gpio_vip_env)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase — construct agent and scoreboard
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = gpio_vip_agent::type_id::create("agent", this);
    sb    = gpio_vip_scoreboard::type_id::create("sb",    this);
  endfunction

  // ---------------------------------------------------------------------------
  // connect_phase — wire monitor analysis port to scoreboard
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    agent.mon.ap.connect(sb.ap);
  endfunction

endclass
