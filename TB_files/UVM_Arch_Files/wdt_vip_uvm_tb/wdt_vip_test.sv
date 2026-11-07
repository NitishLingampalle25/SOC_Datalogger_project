`timescale 1ns/1ps
// =============================================================================
// wdt_vip_test.sv — UVM test classes for WDT VIP
//
// Four test classes:
//   tc_wdt_01_test  — software ping prevents timeout
//   tc_wdt_02_test  — AES auto-kick prevents timeout
//   tc_wdt_03_test  — early-warning IRQ fires and is cleared (W1C)
//   tc_wdt_04_test  — NMI escalation followed by hard reset
//
// Each test:
//   1. Extends wdt_vip_base_test (builds env, fetches vif)
//   2. Instantiates its sequence in run_phase
//   3. Passes virtual interface / scoreboard handle to sequence as needed
// =============================================================================

// =============================================================================
// Base test — common build and elaboration logic
// =============================================================================
class wdt_vip_base_test extends uvm_test;

  wdt_vip_env      env;
  virtual wdt_vip_if vif;

  `uvm_component_utils(wdt_vip_base_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = wdt_vip_env::type_id::create("env", this);
    // Retrieve virtual interface — must be set by tb_top before run_test()
    if (!uvm_config_db #(virtual wdt_vip_if)::get(this, "", "wdt_vif", vif))
      `uvm_fatal("NOVIF",
        "wdt_vip_base_test: 'wdt_vif' not found in config DB")
  endfunction

  // ---------------------------------------------------------------------------
  // end_of_elaboration_phase: print UVM topology
  // ---------------------------------------------------------------------------
  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

endclass

// =============================================================================
// TC_WDT_01 — Software ping prevents timeout
// =============================================================================
class tc_wdt_01_test extends wdt_vip_base_test;

  `uvm_component_utils(tc_wdt_01_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_wdt_01_seq seq;
    phase.raise_objection(this);

    seq = tc_wdt_01_seq::type_id::create("seq");
    seq.start(env.agent.seqr);

    // Allow a few extra cycles for any residual side-effects to settle
    #50;
    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// TC_WDT_02 — AES auto-kick prevents timeout
// =============================================================================
class tc_wdt_02_test extends wdt_vip_base_test;

  `uvm_component_utils(tc_wdt_02_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_wdt_02_seq seq;
    phase.raise_objection(this);

    seq = tc_wdt_02_seq::type_id::create("seq");
    seq.start(env.agent.seqr);

    // Let AES pulse settle and any downstream reactions complete
    #200;
    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// TC_WDT_03 — Early-warning IRQ fires, W1C clears it
// =============================================================================
class tc_wdt_03_test extends wdt_vip_base_test;

  `uvm_component_utils(tc_wdt_03_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_wdt_03_seq seq;
    phase.raise_objection(this);

    seq      = tc_wdt_03_seq::type_id::create("seq");
    // Give the sequence direct access to the scoreboard for check_irq_cleared()
    seq.sb_h = env.sb;
    seq.start(env.agent.seqr);

    #50;
    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// TC_WDT_04 — NMI escalation then hard reset
//
// run_phase additionally forks a background task that monitors wdt_nmi_o and
// wdt_reset_o directly on the interface so the objection is not dropped until
// both signals have been seen.
// =============================================================================
class tc_wdt_04_test extends wdt_vip_base_test;

  `uvm_component_utils(tc_wdt_04_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_wdt_04_seq seq;
    bit           nmi_seen   = 1'b0;
    bit           reset_seen = 1'b0;

    phase.raise_objection(this);

    seq      = tc_wdt_04_seq::type_id::create("seq");
    // Pass virtual interface so the sequence can block on the signals directly
    seq.vif  = vif;

    // Fork: run sequence and a parallel interface watcher
    fork
      // Arm: start the sequence (writes LOAD and CTRL, then blocks on signals)
      seq.start(env.agent.seqr);

      // Background interface watcher — provides test-level visibility and
      // ensures we never miss the pulses even if the sequence races
      begin : watcher
        // Wait for NMI
        @(posedge vif.wdt_nmi_o);
        nmi_seen = 1'b1;
        `uvm_info("TC04_TEST",
          "run_phase: wdt_nmi_o posedge observed on interface", UVM_LOW)

        // Then wait for hard reset
        @(posedge vif.wdt_reset_o);
        reset_seen = 1'b1;
        `uvm_info("TC04_TEST",
          "run_phase: wdt_reset_o posedge observed on interface", UVM_LOW)
      end
    join  // both must finish before objection drops

    // Final test-level assertion
    if (nmi_seen && reset_seen)
      `uvm_info("TC04_TEST",
        "TC_WDT_04 PASS: NMI and hard-reset both observed — escalation chain verified",
        UVM_LOW)
    else
      `uvm_error("TC04_TEST",
        $sformatf("TC_WDT_04 FAIL: nmi_seen=%0b reset_seen=%0b",
                  nmi_seen, reset_seen))

    phase.drop_objection(this);
  endtask

endclass
