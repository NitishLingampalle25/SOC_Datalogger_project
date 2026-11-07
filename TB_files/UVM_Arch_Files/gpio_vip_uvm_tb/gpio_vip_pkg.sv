`timescale 1ns/1ps
// =============================================================================
// gpio_vip_pkg.sv — Package wrapper for the GPIO VIP UVM classes
//
// `timescale is declared OUTSIDE the package body so it applies to all
// included files.  (VCS resets timescale context at every file boundary;
// placing it before the package keyword ensures consistent propagation —
// same lesson learned in the UART VIP integration.)
//
// Inclusion order follows strict UVM dependency:
//   item → sequencer → driver → monitor → scoreboard → agent → env
//   → sequences → test
// =============================================================================
package gpio_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---- data object (no component dependencies) -----------------------------
  `include "gpio_vip_item.sv"

  // ---- infrastructure (sequencer before driver) ----------------------------
  `include "gpio_vip_sequencer.sv"
  `include "gpio_vip_driver.sv"
  `include "gpio_vip_monitor.sv"
  `include "gpio_vip_scoreboard.sv"

  // ---- structural (agent and env need all of the above) --------------------
  `include "gpio_vip_agent.sv"
  `include "gpio_vip_env.sv"

  // ---- stimulus (sequences need item + env hierarchy) ----------------------
  `include "gpio_vip_sequences.sv"

  // ---- tests (need env + sequences) ----------------------------------------
  `include "gpio_vip_test.sv"

endpackage : gpio_vip_pkg
