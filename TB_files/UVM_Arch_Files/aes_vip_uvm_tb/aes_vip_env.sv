`timescale 1ns/1ps
//=============================================================================
// aes_vip_env.sv
// AES VIP Environment — instantiates agent + scoreboard and wires them
//=============================================================================

class aes_vip_env extends uvm_env;

  `uvm_component_utils(aes_vip_env)

  // Sub-components
  aes_vip_agent      agent;
  aes_vip_scoreboard scoreboard;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name = "aes_vip_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------------------------
  // build_phase — create agent and scoreboard
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = aes_vip_agent::type_id::create("agent", this);
    scoreboard = aes_vip_scoreboard::type_id::create("scoreboard", this);
  endfunction

  // -------------------------------------------------------------------------
  // connect_phase — agent analysis port → scoreboard analysis export
  // -------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    agent.ap.connect(scoreboard.analysis_export);
  endfunction

endclass : aes_vip_env
