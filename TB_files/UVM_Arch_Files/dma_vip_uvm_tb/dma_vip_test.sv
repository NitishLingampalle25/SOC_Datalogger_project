`timescale 1ns/1ps
// =============================================================================
// dma_vip_test.sv — UVM test classes for DMA VIP
//
// Two test classes:
//   tc_dma_01_test — burst transfer UART_BASE → DCCM_BASE, checks
//                    dma_done_o + dma_irq_o
//   tc_dma_02_test — error-abort to unmapped 0x4000_9000, checks dma_error_o
//
// Both share a base test that builds the environment and prints the topology.
// Each test: raises objection → starts sequence → drops objection.
// An extra drain time of 500 ns is kept after the sequence exits so that the
// monitor can capture any late-arriving terminal event from the DUT.
// =============================================================================

// =============================================================================
// dma_vip_base_test — shared environment build, topology print
// =============================================================================
class dma_vip_base_test extends uvm_test;

  dma_vip_env env;

  `uvm_component_utils(dma_vip_base_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = dma_vip_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

endclass

// =============================================================================
// tc_dma_01_test — Burst transfer: UART_BASE → DCCM_BASE, 64 bytes
//   Pass criteria: dma_done_o=1, dma_irq_o=1, dma_error_o=0
// =============================================================================
class tc_dma_01_test extends dma_vip_base_test;

  `uvm_component_utils(tc_dma_01_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_dma_01_seq seq;

    phase.raise_objection(this, "TC_DMA_01 running");

    seq = tc_dma_01_seq::type_id::create("seq");
    seq.start(env.agent.seqr);

    // Drain time: allow DUT to assert dma_done_o / dma_irq_o and the
    // monitor to capture the terminal event before the simulation ends.
    #500;

    phase.drop_objection(this, "TC_DMA_01 done");
  endtask

endclass

// =============================================================================
// tc_dma_02_test — Error abort: unmapped destination 0x4000_9000
//   Pass criteria: dma_error_o=1, dma_done_o=1
// =============================================================================
class tc_dma_02_test extends dma_vip_base_test;

  `uvm_component_utils(tc_dma_02_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_dma_02_seq seq;

    phase.raise_objection(this, "TC_DMA_02 running");

    seq = tc_dma_02_seq::type_id::create("seq");
    seq.start(env.agent.seqr);

    // Drain time: DUT should respond to the SLVERR and assert dma_error_o.
    #500;

    phase.drop_objection(this, "TC_DMA_02 done");
  endtask

endclass
