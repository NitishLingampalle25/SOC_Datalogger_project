`timescale 1ns/1ps
// =============================================================================
// wdt_vip_pkg.sv — Package wrapper for the WDT VIP UVM classes
//
// `timescale is declared OUTSIDE the package body so it applies to all
// included files.  VCS resets timescale context at file boundaries; placing
// the directive here before the package keyword ensures consistent
// propagation to every included source file.
//
// Inclusion order follows strict UVM dependency:
//   item  →  sequencer  →  driver  →  monitor  →  scoreboard
//   →  agent  →  env  →  sequences  →  test
// =============================================================================
package wdt_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---- data object (no UVM component dependencies) -------------------------
  `include "wdt_vip_item.sv"

  // ---- infrastructure (sequencer before driver) ----------------------------
  `include "wdt_vip_sequencer.sv"
  `include "wdt_vip_driver.sv"
  `include "wdt_vip_monitor.sv"
  `include "wdt_vip_scoreboard.sv"

  // ---- structural (agent and env need all of the above) --------------------
  `include "wdt_vip_agent.sv"
  `include "wdt_vip_env.sv"

  // ---- stimulus (sequences need item + scoreboard handle) ------------------
  `include "wdt_vip_sequences.sv"

  // ---- tests (need env + sequences + virtual interface) --------------------
  `include "wdt_vip_test.sv"

endpackage : wdt_vip_pkg
