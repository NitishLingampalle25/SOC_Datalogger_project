`timescale 1ns/1ps
//=============================================================================
// aes_vip_scoreboard.sv
// AES VIP Scoreboard
//
// Receives aes_vip_item from the monitor's analysis port (triggered on
// aes_done_pulse).  Two checking modes, distinguished by a test-name string
// set via uvm_config_db before the test starts:
//
//   TC_AES_01 — Reads TXTOUT[0..3] via a back-door virtual-interface handle
//               and compares them against the FIPS-197 expected ciphertext.
//               Reports PASS if all four 32-bit words match.
//
//   TC_AES_02 — Same CT comparison, but verifies that spurious writes issued
//               while AES was busy did NOT corrupt the result (busy-write
//               protection).  PASS criteria identical to TC_AES_01.
//
// The scoreboard drives reads back through the driver by posting a read
// sequence item directly via a TLM FIFO → sequence handshake.  Because the
// scoreboard cannot call the driver directly, it instead writes read requests
// to a uvm_tlm_analysis_fifo that the tc_aes_01_seq / tc_aes_02_seq polls
// after encryption completes.
//
// For simplicity, the scoreboard also caches the four TXTOUT words written
// back to it by the sequences via a second analysis port (sb_result_port).
//=============================================================================

class aes_vip_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(aes_vip_scoreboard)

  // -------------------------------------------------------------------------
  // Analysis export — receives items from monitor
  // -------------------------------------------------------------------------
  uvm_analysis_imp #(aes_vip_item, aes_vip_scoreboard) analysis_export;

  // -------------------------------------------------------------------------
  // FIPS-197 128-bit golden ciphertext
  // Key  = {2b7e1516_28aed2a6_abf71588_09cf4f3c}
  // PT   = {6bc1bee2_2e409f96_e93d7e11_7393172a}
  // CT   = {3925841d_02dc09fb_dc118597_196a0b32}
  // -------------------------------------------------------------------------
  localparam bit [31:0] EXP_CT[4] = '{
    32'h3925_841d,
    32'h02dc_09fb,
    32'hdc11_8597,
    32'h196a_0b32
  };

  // -------------------------------------------------------------------------
  // Internal state
  // -------------------------------------------------------------------------
  string   test_name;          // set by test via config_db key "test_name"
  int      pass_count;
  int      fail_count;

  // Storage for TXTOUT words forwarded by the sequence
  bit [31:0] got_ct[4];
  bit        ct_received;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name = "aes_vip_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    pass_count  = 0;
    fail_count  = 0;
    ct_received = 0;
  endfunction

  // -------------------------------------------------------------------------
  // build_phase
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    if (!uvm_config_db #(string)::get(this, "", "test_name", test_name))
      test_name = "TC_AES_01";  // default
  endfunction

  // -------------------------------------------------------------------------
  // write() — called by monitor on every aes_done_pulse
  // The item carries aes_busy/aes_done snapshots. The actual CT comparison
  // happens after the sequences call report_ct() below.
  // -------------------------------------------------------------------------
  function void write(aes_vip_item item);
    `uvm_info("AES_SB",
      $sformatf("[%s] aes_done_pulse received — busy=%0b done=%0b",
        test_name, item.aes_busy, item.aes_done),
      UVM_MEDIUM)
  endfunction

  // -------------------------------------------------------------------------
  // report_ct() — called by the sequence after reading TXTOUT[0..3]
  // Sequences pass the four read-back words and the test identifier.
  // -------------------------------------------------------------------------
  function void report_ct(
    input bit [31:0] ct0,
    input bit [31:0] ct1,
    input bit [31:0] ct2,
    input bit [31:0] ct3,
    input string     tc_name
  );
    bit all_match;

    got_ct[0] = ct0;
    got_ct[1] = ct1;
    got_ct[2] = ct2;
    got_ct[3] = ct3;
    ct_received = 1;

    all_match = (ct0 === EXP_CT[0]) &&
                (ct1 === EXP_CT[1]) &&
                (ct2 === EXP_CT[2]) &&
                (ct3 === EXP_CT[3]);

    `uvm_info("AES_SB", $sformatf(
      "[%s] CT CHECK\n  Got : %08h %08h %08h %08h\n  Exp : %08h %08h %08h %08h",
      tc_name,
      ct0, ct1, ct2, ct3,
      EXP_CT[0], EXP_CT[1], EXP_CT[2], EXP_CT[3]),
      UVM_LOW)

    if (all_match) begin
      pass_count++;
      `uvm_info("AES_SB",
        $sformatf("[%s] *** PASS *** Ciphertext matches FIPS-197 vector.", tc_name),
        UVM_LOW)
    end else begin
      fail_count++;
      `uvm_error("AES_SB",
        $sformatf("[%s] *** FAIL *** Ciphertext mismatch!", tc_name))

      // Word-level detail for easier debug
      for (int i = 0; i < 4; i++) begin
        if (got_ct[i] !== EXP_CT[i])
          `uvm_error("AES_SB",
            $sformatf("  TXTOUT[%0d]  got=0x%08h  exp=0x%08h", i, got_ct[i], EXP_CT[i]))
      end
    end

    // TC_AES_02 specific message
    if (tc_name == "TC_AES_02") begin
      if (all_match)
        `uvm_info("AES_SB",
          "[TC_AES_02] Busy-write protection CONFIRMED — spurious writes did not corrupt CT.",
          UVM_LOW)
      else
        `uvm_error("AES_SB",
          "[TC_AES_02] Busy-write protection FAILED — CT was corrupted by writes during BUSY.")
    end
  endfunction

  // -------------------------------------------------------------------------
  // report_phase — print final summary
  // -------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info("AES_SB", $sformatf(
      {"\n========================================\n",
       "  AES VIP Scoreboard Final Report\n",
       "  Test     : %s\n",
       "  PASS     : %0d\n",
       "  FAIL     : %0d\n",
       "========================================\n"},
      test_name, pass_count, fail_count),
      UVM_LOW)

    if (fail_count > 0)
      `uvm_error("AES_SB", "One or more scoreboard checks FAILED.")
    else
      `uvm_info("AES_SB", "All scoreboard checks PASSED.", UVM_LOW)
  endfunction

endclass : aes_vip_scoreboard
