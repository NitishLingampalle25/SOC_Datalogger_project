`timescale 1ns/1ps
// =============================================================================
// systimer_vip_pkg.sv — Package wrapper for the SysTimer VIP UVM classes
//
// `timescale is declared OUTSIDE the package body so it applies to all
// `included files (VCS resets timescale context at every file boundary;
// placing the directive before the package keyword ensures all included
// source files inherit consistent time resolution).
//
// Inclusion order follows strict UVM dependency:
//   item → sequencer → driver → monitor → scoreboard
//   → agent → env → sequences → test
// =============================================================================
package systimer_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---- data object (no UVM component dependencies) -------------------------
  `include "systimer_vip_item.sv"

  // ---- infrastructure (sequencer must precede driver) ----------------------
  `include "systimer_vip_sequencer.sv"
  `include "systimer_vip_driver.sv"
  `include "systimer_vip_monitor.sv"
  `include "systimer_vip_scoreboard.sv"

  // ---- structural hierarchy (agent and env require all of the above) -------
  `include "systimer_vip_agent.sv"
  `include "systimer_vip_env.sv"

  // ---- stimulus (sequences require item + env hierarchy) -------------------
  `include "systimer_vip_sequences.sv"

  // ---- tests (require env + sequences) -------------------------------------
  `include "systimer_vip_test.sv"

endpackage : systimer_vip_pkg
