// =============================================================================
// uart_vip_test.sv — UVM test classes for UART VIP
//
// Four tests, one per TC:
//   tc_uart_01_test  — config register write/read-back
//   tc_uart_02_test  — TX byte 0x4B via THR
//   tc_uart_03_test  — RX inject 0xA5, IRQ check
//   tc_uart_04_test  — overrun (double inject without RBR read)
//
// Each test:
//   1. Instantiates uart_vip_env
//   2. Fetches the virtual interface from the config DB
//      (set by the top-level module before run_test())
//   3. Starts its matching sequence on env.agent.seqr
// =============================================================================

// -----------------------------------------------------------------------------
// Base test — common env build logic, subclassed by each TC
// -----------------------------------------------------------------------------
class uart_vip_base_test extends uvm_test;

  uart_vip_env env;

  `uvm_component_utils(uart_vip_base_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_vip_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

endclass

// =============================================================================
// TC_UART_01 — Configuration register write + read-back
// =============================================================================
class tc_uart_01_test extends uart_vip_base_test;

  `uvm_component_utils(tc_uart_01_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_uart_01_seq seq;
    phase.raise_objection(this);
    seq = tc_uart_01_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// TC_UART_02 — TX byte 0x4B written to THR; monitor checks uart_tx_o
// =============================================================================
class tc_uart_02_test extends uart_vip_base_test;

  `uvm_component_utils(tc_uart_02_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_uart_02_seq seq;
    phase.raise_objection(this);
    seq = tc_uart_02_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
    // Allow time for serialisation to complete after the sequence exits
    #500;
    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// TC_UART_03 — RX inject 0xA5 on uart_rx_i; scoreboard checks IRQ
// =============================================================================
class tc_uart_03_test extends uart_vip_base_test;

  `uvm_component_utils(tc_uart_03_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_uart_03_seq seq;
    phase.raise_objection(this);
    seq = tc_uart_03_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
    // Allow time for the DUT to assert irq after RX complete
    #200;
    phase.drop_objection(this);
  endtask

endclass

// =============================================================================
// TC_UART_04 — Overrun: two back-to-back 0x11 injections, no RBR read
// =============================================================================
class tc_uart_04_test extends uart_vip_base_test;

  `uvm_component_utils(tc_uart_04_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    tc_uart_04_seq seq;
    phase.raise_objection(this);
    seq = tc_uart_04_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
    #200;
    phase.drop_objection(this);
  endtask

endclass
