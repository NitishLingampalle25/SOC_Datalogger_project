`timescale 1ns/1ps
// =============================================================================
// systimer_vip_test.sv — UVM test classes for SysTimer VIP
//
// Tests:
//   tc_tmr_01_test — prescaler config + counter increment verification
//   tc_tmr_02_test — compare-match IRQ + W1C clear
//
// Both tests share a common base class (systimer_vip_base_test) that builds
// the environment and prints the component topology at end-of-elaboration.
// =============================================================================

// -----------------------------------------------------------------------------
// Base test — common environment construction, subclassed by each TC
// -----------------------------------------------------------------------------
class systimer_vip_base_test extends uvm_test;

  systimer_vip_env env;

  `uvm_component_utils(systimer_vip_base_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = systimer_vip_env::type_id::create("env", this);
  endfunction

  // Print UVM topology once hierarchy is fully elaborated
  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

endclass

// =============================================================================
// TC_TMR_01 — Prescaler configuration and counter increment check
// =============================================================================
class tc_tmr_01_test extends systimer_vip_base_test;

  `uvm_component_utils(tc_tmr_01_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_tmr_01_seq seq;
    phase.raise_objection(this);

    seq = tc_tmr_01_seq::type_id::create("seq");
    seq.start(env.agent.seqr);

    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// TC_TMR_02 — Compare-match interrupt + W1C clear
//
// Extra guard time (#500) after the sequence completes so that the monitor
// can observe the timer_irq_o posedge before the objection is dropped and
// the scoreboard has a chance to register the PASS.
// =============================================================================
class tc_tmr_02_test extends systimer_vip_base_test;

  `uvm_component_utils(tc_tmr_02_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_tmr_02_seq seq;
    phase.raise_objection(this);

    seq = tc_tmr_02_seq::type_id::create("seq");
    seq.start(env.agent.seqr);

    // Allow the DUT time to assert timer_irq_o after the compare-match
    // before the objection count reaches zero and simulation ends.
    #500;

    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// systimer_vip_test — default test: runs both TC_TMR_01 and TC_TMR_02
//                      in sequence on the same agent/sequencer
// =============================================================================
class systimer_vip_test extends systimer_vip_base_test;

  `uvm_component_utils(systimer_vip_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_tmr_01_seq seq01;
    tc_tmr_02_seq seq02;
    phase.raise_objection(this);

    `uvm_info("TMR_TEST", "Starting TC_TMR_01", UVM_LOW)
    seq01 = tc_tmr_01_seq::type_id::create("seq01");
    seq01.start(env.agent.seqr);

    `uvm_info("TMR_TEST", "Starting TC_TMR_02", UVM_LOW)
    seq02 = tc_tmr_02_seq::type_id::create("seq02");
    seq02.start(env.agent.seqr);

    // Guard time for IRQ monitor to capture the posedge
    #500;

    phase.drop_objection(this);
  endtask

endclass
