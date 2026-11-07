`timescale 1ns/1ps
// =============================================================================
// gpio_vip_test.sv — UVM test classes for GPIO VIP
//
// Three tests, one per TC:
//   tc_gpio_01_test  — pin direction + output drive (gpio_tx_en_o, gpio_out_o)
//   tc_gpio_02_test  — input sampling (gpio_in_i → GPIO_IN_REG readback)
//   tc_gpio_03_test  — rising-edge IRQ (gpio_irq_o assertion)
//
// Each test:
//   1. Builds a gpio_vip_env (which contains agent + scoreboard)
//   2. The virtual interface was set in config DB by tb_top before run_test()
//   3. Raises objection, runs its sequence, then drops objection
//
// Default test name (used by tb_top): "gpio_vip_test" resolves to
// tc_gpio_01_test via the factory alias set in gpio_vip_base_test or by
// passing +UVM_TESTNAME=tc_gpio_01_test on the command line.
// =============================================================================

// -----------------------------------------------------------------------------
// Base test — common env construction; subclassed by each TC
// -----------------------------------------------------------------------------
class gpio_vip_base_test extends uvm_test;

  gpio_vip_env env;

  `uvm_component_utils(gpio_vip_base_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = gpio_vip_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

endclass

// =============================================================================
// TC_GPIO_01 — Pin direction + output drive
// gpio_tx_en_o[7:0] must equal 8'hFF, gpio_out_o[7:0] must equal 8'hA5
// =============================================================================
class tc_gpio_01_test extends gpio_vip_base_test;

  `uvm_component_utils(tc_gpio_01_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_gpio_01_seq seq;
    phase.raise_objection(this);
    seq = tc_gpio_01_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
    // Allow DUT outputs to settle after the final stimulus edge
    #100;
    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// TC_GPIO_02 — Input sampling
// gpio_in_i = 32'h5A5A_A5A5 must be correctly registered by the DUT
// =============================================================================
class tc_gpio_02_test extends gpio_vip_base_test;

  `uvm_component_utils(tc_gpio_02_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_gpio_02_seq seq;
    phase.raise_objection(this);
    seq = tc_gpio_02_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
    // Hold stimulus for at least 3 clock cycles so DUT synchroniser latches
    #50;
    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// TC_GPIO_03 — Rising-edge interrupt
// gpio_irq_o must assert after gpio_in_i[0] transitions 0 → 1
// with GPIO_RISE_EN[0] set
// =============================================================================
class tc_gpio_03_test extends gpio_vip_base_test;

  `uvm_component_utils(tc_gpio_03_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_gpio_03_seq seq;
    phase.raise_objection(this);
    seq = tc_gpio_03_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
    // Allow DUT edge-detect logic to propagate and assert gpio_irq_o
    #100;
    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// gpio_vip_test — default test alias (runs TC_GPIO_01)
// Override with +UVM_TESTNAME=<name> to run a specific test
// =============================================================================
class gpio_vip_test extends tc_gpio_01_test;
  `uvm_component_utils(gpio_vip_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

endclass
