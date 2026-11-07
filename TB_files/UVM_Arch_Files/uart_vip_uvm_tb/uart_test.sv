// =============================================================================
// uart_test.sv
// UVM test — builds the environment, starts uart_seq on the agent sequencer.
// Run with: +UVM_TESTNAME=uart_test
// =============================================================================

class uart_test extends uvm_test;
    `uvm_component_utils(uart_test)

    uart_vip_env env;

    function new(string name = "uart_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // -------------------------------------------------------------------------
    // build_phase: create env
    // -------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = uart_vip_env::type_id::create("env", this);
    endfunction

    // -------------------------------------------------------------------------
    // run_phase: raise objection, start sequence, drop objection
    // -------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        uart_seq seq;

        phase.raise_objection(this);

        // Wait for reset to complete before driving
        @(posedge env.agent.drv.vif.rst_n);
        repeat (10) @(posedge env.agent.drv.vif.clk);

        seq = uart_seq::type_id::create("seq");
        seq.start(env.agent.seqr);

        // Allow time for last byte to complete serialisation
        // 868 cycles/bit x 10 bits x 10ns = ~86.8us per byte, 3 bytes done
        // wait extra cycles for IRQ to settle
        repeat (200) @(posedge env.agent.drv.vif.clk);

        phase.drop_objection(this);
    endtask

endclass
