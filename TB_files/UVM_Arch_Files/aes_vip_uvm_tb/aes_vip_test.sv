`timescale 1ns/1ps
//=============================================================================
// aes_vip_test.sv
// AES VIP Tests
//
// tc_aes_01_test — Instantiates env, runs tc_aes_01_seq
//   Verifies FIPS-197 128-bit AES encryption result
//
// tc_aes_02_test — Instantiates env, runs tc_aes_02_seq
//   Verifies busy-write protection: spurious writes during BUSY must not
//   corrupt the final ciphertext
//=============================================================================

//=============================================================================
// Base test — common env build, scoreboard wiring, config_db setup
//=============================================================================
class aes_vip_base_test extends uvm_test;

  `uvm_component_utils(aes_vip_base_test)

  aes_vip_env env;

  function new(string name = "aes_vip_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------------------------
  // build_phase — create environment
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = aes_vip_env::type_id::create("env", this);
  endfunction

  // -------------------------------------------------------------------------
  // end_of_elaboration_phase — print topology for debug
  // -------------------------------------------------------------------------
  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

endclass : aes_vip_base_test


//=============================================================================
// tc_aes_01_test
// Functional encryption test: write FIPS key + PT, start, verify CT
//=============================================================================
class tc_aes_01_test extends aes_vip_base_test;

  `uvm_component_utils(tc_aes_01_test)

  function new(string name = "tc_aes_01_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------------------------
  // build_phase — set test_name in config_db for scoreboard
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db #(string)::set(this, "env.scoreboard", "test_name", "TC_AES_01");
  endfunction

  // -------------------------------------------------------------------------
  // run_phase — raise objection, start sequence, drop objection
  // -------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    tc_aes_01_seq seq;

    phase.raise_objection(this, "TC_AES_01 started");
    `uvm_info("TC_AES_01", ">>>  TC_AES_01 run_phase begin  <<<", UVM_LOW)

    seq    = tc_aes_01_seq::type_id::create("seq");
    seq.sb = env.scoreboard;   // wire scoreboard handle for direct reporting

    seq.start(env.agent.sequencer);

    `uvm_info("TC_AES_01", ">>>  TC_AES_01 run_phase end    <<<", UVM_LOW)
    phase.drop_objection(this, "TC_AES_01 finished");
  endtask

endclass : tc_aes_01_test


//=============================================================================
// tc_aes_02_test
// Busy-write protection test: spurious writes while BUSY must not corrupt CT
//=============================================================================
class tc_aes_02_test extends aes_vip_base_test;

  `uvm_component_utils(tc_aes_02_test)

  function new(string name = "tc_aes_02_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------------------------
  // build_phase — set test_name in config_db for scoreboard
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db #(string)::set(this, "env.scoreboard", "test_name", "TC_AES_02");
  endfunction

  // -------------------------------------------------------------------------
  // run_phase — raise objection, start sequence, drop objection
  // -------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    tc_aes_02_seq seq;

    phase.raise_objection(this, "TC_AES_02 started");
    `uvm_info("TC_AES_02", ">>>  TC_AES_02 run_phase begin  <<<", UVM_LOW)

    seq    = tc_aes_02_seq::type_id::create("seq");
    seq.sb = env.scoreboard;   // wire scoreboard handle for direct reporting

    seq.start(env.agent.sequencer);

    `uvm_info("TC_AES_02", ">>>  TC_AES_02 run_phase end    <<<", UVM_LOW)
    phase.drop_objection(this, "TC_AES_02 finished");
  endtask

endclass : tc_aes_02_test
