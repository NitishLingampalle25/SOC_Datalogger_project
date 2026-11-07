`timescale 1ns/1ps
//=============================================================================
// aes_vip_pkg.sv
// AES VIP UVM Package
//
// Collects every VIP class in dependency order so a single
//   `include "aes_vip_pkg.sv"
// (or filelist entry) pulls the whole VIP into a compilation unit.
//
// Include order (each class depends only on earlier entries):
//   1. aes_vip_item       — sequence item (no other VIP deps)
//   2. aes_vip_sequencer  — thin sequencer wrapper
//   3. aes_vip_driver     — uses item
//   4. aes_vip_monitor    — uses item
//   5. aes_vip_scoreboard — uses item
//   6. aes_vip_agent      — uses driver, sequencer, monitor
//   7. aes_vip_env        — uses agent, scoreboard
//   8. aes_vip_sequences  — uses item, base helpers, scoreboard handle
//   9. aes_vip_test       — uses env, sequences
//
// NOTE: aes_vip_if is an interface (not a class) and must be compiled
//       separately (listed in the filelist before this package).
//=============================================================================

package aes_vip_pkg;

  // Import UVM base library
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // -------------------------------------------------------------------------
  // 1. Sequence Item
  // -------------------------------------------------------------------------
  `include "aes_vip_item.sv"

  // -------------------------------------------------------------------------
  // 2. Sequencer
  // -------------------------------------------------------------------------
  `include "aes_vip_sequencer.sv"

  // -------------------------------------------------------------------------
  // 3. Driver
  // -------------------------------------------------------------------------
  `include "aes_vip_driver.sv"

  // -------------------------------------------------------------------------
  // 4. Monitor
  // -------------------------------------------------------------------------
  `include "aes_vip_monitor.sv"

  // -------------------------------------------------------------------------
  // 5. Scoreboard
  // -------------------------------------------------------------------------
  `include "aes_vip_scoreboard.sv"

  // -------------------------------------------------------------------------
  // 6. Agent
  // -------------------------------------------------------------------------
  `include "aes_vip_agent.sv"

  // -------------------------------------------------------------------------
  // 7. Environment
  // -------------------------------------------------------------------------
  `include "aes_vip_env.sv"

  // -------------------------------------------------------------------------
  // 8. Sequences (base + tc_aes_01_seq + tc_aes_02_seq)
  // -------------------------------------------------------------------------
  `include "aes_vip_sequences.sv"

  // -------------------------------------------------------------------------
  // 9. Tests (base_test + tc_aes_01_test + tc_aes_02_test)
  // -------------------------------------------------------------------------
  `include "aes_vip_test.sv"

endpackage : aes_vip_pkg
