`timescale 1ns/1ps
// =============================================================================
// dma_vip_pkg.sv — Package wrapper for the DMA VIP UVM classes
//
// `timescale is declared OUTSIDE the package body so that it applies to all
// included files (VCS resets timescale context at each file boundary; placing
// the directive here before the package keyword ensures consistent propagation
// across all `include'd sources).
//
// Inclusion order follows strict UVM dependency:
//   item → sequencer → driver → monitor → scoreboard → agent → env
//   → sequences → test
// =============================================================================
package dma_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---- data object (no UVM component dependencies) -------------------------
  `include "dma_vip_item.sv"

  // ---- infrastructure: sequencer must precede driver -----------------------
  `include "dma_vip_sequencer.sv"
  `include "dma_vip_driver.sv"
  `include "dma_vip_monitor.sv"
  `include "dma_vip_scoreboard.sv"

  // ---- structural: agent and env need all of the above ---------------------
  `include "dma_vip_agent.sv"
  `include "dma_vip_env.sv"

  // ---- stimulus: sequences need item + env hierarchy -----------------------
  `include "dma_vip_sequences.sv"

  // ---- tests: need env + sequences -----------------------------------------
  `include "dma_vip_test.sv"

endpackage : dma_vip_pkg
