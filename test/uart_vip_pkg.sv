// =============================================================================
// uart_vip_pkg.sv — Package wrapper for the UART VIP UVM classes
//
// `timescale is declared OUTSIDE the package body so that it applies to all
// included files (VCS resets timescale context at file boundaries; placing it
// here before the package keyword ensures consistent propagation).
//
// Inclusion order follows strict dependency:
//   item → sequencer → driver → monitor → scoreboard → agent → env
//   → sequences → test
// =============================================================================
package uart_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---- data object (no UVM component dependencies) -------------------------
  `include "uart_vip_item.sv"

  // ---- infrastructure (sequencer before driver) ----------------------------
  `include "uart_vip_sequencer.sv"
  `include "uart_vip_driver.sv"
  `include "uart_vip_monitor.sv"
  `include "uart_vip_scoreboard.sv"

  // ---- structural (agent and env need all of the above) --------------------
  `include "uart_vip_agent.sv"
  `include "uart_vip_env.sv"

  // ---- stimulus (sequences need item + env hierarchy) ----------------------
  `include "uart_vip_sequences.sv"

  // ---- tests (need env + sequences) ----------------------------------------
  `include "uart_vip_test.sv"

endpackage : uart_vip_pkg
