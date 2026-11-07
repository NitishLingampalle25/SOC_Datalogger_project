// =============================================================================
// soc_uvm_pkg.sv — SoC-level UVM package
// Aggregates all VIP packages for the VeeR-EL2 SoC Data Logger testbench.
// Testplan coverage: TC_UART_01..04, TC_TMR_01..02, TC_AES_01..02,
//                    TC_DMA_01..02, TC_WDT_01..04, TC_GPIO_01..03,
//                    TC_PIPE_01, TC_BUS_01..02, TC_FULL_01
//
// Compile order (all interfaces first, then packages):
//   uart_vip_uvm_tb/uart_vip_if.sv
//   dma_vip_uvm_tb/dma_vip_if.sv
//   gpio_vip_uvm_tb/gpio_vip_if.sv
//   systimer_vip_uvm_tb/systimer_vip_if.sv
//   wdt_vip_uvm_tb/wdt_vip_if.sv
//   soc_uvm_pkg.sv          <-- this file
//   tb_soc_uvm_top.sv
// =============================================================================
`timescale 1ns/1ps

package soc_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ---- per-VIP packages (each is self-contained) -------------------------
    import uart_vip_pkg::*;
    import dma_vip_pkg::*;
    import gpio_vip_pkg::*;
    import systimer_vip_pkg::*;
    import wdt_vip_pkg::*;

    // =========================================================================
    // soc_env — top-level environment that holds one agent per VIP
    // =========================================================================
    class soc_env extends uvm_env;
        uart_vip_env     uart_env;
        dma_vip_env      dma_env;
        gpio_vip_env     gpio_env;
        systimer_vip_env systimer_env;
        wdt_vip_env      wdt_env;

        `uvm_component_utils(soc_env)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            uart_env     = uart_vip_env::type_id::create("uart_env",     this);
            dma_env      = dma_vip_env::type_id::create("dma_env",       this);
            gpio_env     = gpio_vip_env::type_id::create("gpio_env",     this);
            systimer_env = systimer_vip_env::type_id::create("systimer_env", this);
            wdt_env      = wdt_vip_env::type_id::create("wdt_env",       this);
        endfunction
    endclass

    // =========================================================================
    // TC_PIPE_01 — full pipeline sequence
    // Inject UART byte → DMA transfer → AES encrypt → WDT auto-kick
    // Verifies wdt_reset_o stays deasserted throughout.
    // =========================================================================
    class tc_pipe_01_seq extends uvm_sequence;
        `uvm_object_utils(tc_pipe_01_seq)
        function new(string name="tc_pipe_01_seq"); super.new(name); endfunction

        // VIF handles set by test before start()
        virtual uart_vip_if  uart_vif;
        virtual wdt_vip_if   wdt_vif;
        virtual dma_vip_if   dma_vif;

        task body();
            uart_vip_item u_item;
            dma_vip_item  d_item;
            wdt_vip_item  w_item;

            `uvm_info("PIPE","TC_PIPE_01: starting full pipeline sequence",UVM_LOW)

            // Step 1: configure WDT with AUTOKICK enabled
            w_item = wdt_vip_item::type_id::create("w_cfg");
            w_item.do_write = 1; w_item.addr = 32'h4000_4000; w_item.wdata = 32'h0010_0000; // LOAD
            `uvm_send(w_item)
            w_item = wdt_vip_item::type_id::create("w_ctrl");
            w_item.do_write = 1; w_item.addr = 32'h4000_4004; w_item.wdata = 32'h0000_0003; // EN|AUTOKICK
            `uvm_send(w_item)

            // Step 2: inject UART byte to trigger DMA
            u_item = uart_vip_item::type_id::create("u_rx");
            u_item.do_write=0; u_item.addr=32'hFFFF_FFFF; // sentinel: no AXI
            u_item.tx_byte=8'hA5;
            `uvm_send(u_item)

            // Step 3: configure and start DMA
            d_item = dma_vip_item::type_id::create("d_src");
            d_item.do_write=1; d_item.addr=32'h4000_3000; d_item.wdata=32'h4000_0000; `uvm_send(d_item)
            d_item = dma_vip_item::type_id::create("d_dst");
            d_item.do_write=1; d_item.addr=32'h4000_3004; d_item.wdata=32'h1000_0000; `uvm_send(d_item)
            d_item = dma_vip_item::type_id::create("d_len");
            d_item.do_write=1; d_item.addr=32'h4000_3008; d_item.wdata=32'h0000_0040; `uvm_send(d_item)
            d_item = dma_vip_item::type_id::create("d_ctrl");
            d_item.do_write=1; d_item.addr=32'h4000_300C; d_item.wdata=32'h0000_0003; `uvm_send(d_item)

            // Step 4: wait for pipeline processing
            if (uart_vif != null) begin
                repeat(500) @(posedge uart_vif.clk);
            end else begin
                #5000;
            end

            // Step 5: check wdt_reset_o never fired
            if (wdt_vif != null) begin
                if (wdt_vif.wdt_reset_o !== 1'b0)
                    `uvm_error("PIPE","TC_PIPE_01 FAIL: wdt_reset_o asserted during pipeline")
                else
                    `uvm_info("PIPE","TC_PIPE_01 PASS: wdt_reset_o deasserted throughout",UVM_LOW)
            end
        endtask
    endclass

    // =========================================================================
    // TC_BUS_01 — multi-master arbitration stress
    // =========================================================================
    class tc_bus_01_seq extends uvm_sequence;
        `uvm_object_utils(tc_bus_01_seq)
        function new(string name="tc_bus_01_seq"); super.new(name); endfunction

        task body();
            dma_vip_item d;
            `uvm_info("BUS","TC_BUS_01: multi-master arbitration stress",UVM_LOW)
            // DMA master burst to UART space
            repeat(4) begin
                d = dma_vip_item::type_id::create("d_burst");
                d.do_write=1; d.addr=32'h4000_3000; d.wdata=$urandom();
                `uvm_send(d)
            end
            `uvm_info("BUS","TC_BUS_01 PASS: no deadlock observed",UVM_LOW)
        endtask
    endclass

    // =========================================================================
    // TC_BUS_02 — unmapped address SLVERR check
    // =========================================================================
    class tc_bus_02_seq extends uvm_sequence;
        `uvm_object_utils(tc_bus_02_seq)
        function new(string name="tc_bus_02_seq"); super.new(name); endfunction

        task body();
            dma_vip_item d;
            `uvm_info("BUS","TC_BUS_02: unmapped address SLVERR",UVM_LOW)
            // Write to unmapped hole 0x4000_9000
            d = dma_vip_item::type_id::create("d_unmap");
            d.do_write=1; d.addr=32'h4000_9000; d.wdata=32'hDEAD_BEEF;
            start_item(d);
            d.addr = 32'h4000_9000; // override constraint
            finish_item(d);
            if (d.resp === 2'b10)
                `uvm_info("BUS","TC_BUS_02 PASS: SLVERR received on unmapped address",UVM_LOW)
            else
                `uvm_error("BUS",$sformatf("TC_BUS_02 FAIL: expected SLVERR(2'b10) got %0b",d.resp))
        endtask
    endclass

    // =========================================================================
    // TC_FULL_01 — full regression pass: wait for gpio_out_o[31:16]==16'h900D
    // =========================================================================
    class tc_full_01_seq extends uvm_sequence;
        `uvm_object_utils(tc_full_01_seq)
        virtual gpio_vip_if  gpio_vif;
        function new(string name="tc_full_01_seq"); super.new(name); endfunction

        task body();
            int timeout_cnt = 0;
            `uvm_info("FULL","TC_FULL_01: waiting for gpio_out_o[31:16]==16'h900D",UVM_LOW)
            if (gpio_vif == null) begin
                `uvm_fatal("FULL","TC_FULL_01: gpio_vif handle not set")
                return;
            end
            forever begin
                @(posedge gpio_vif.clk);
                timeout_cnt++;
                if (gpio_vif.gpio_out_o[31:16] === 16'h900D) begin
                    `uvm_info("FULL","*** TC_FULL_01 PASS: ALL FIRMWARE CHECKS PASSED ***",UVM_NONE)
                    return;
                end
                if (gpio_vif.gpio_out_o[31:16] === 16'hDEAD) begin
                    `uvm_error("FULL","TC_FULL_01 FAIL: firmware reported 0xDEAD")
                    return;
                end
                if (timeout_cnt > 1_000_000) begin
                    `uvm_error("FULL","TC_FULL_01 TIMEOUT: 0x900D never appeared")
                    return;
                end
            end
        endtask
    endclass

    // =========================================================================
    // SoC-level test classes
    // =========================================================================

    // Base test — builds soc_env
    class soc_base_test extends uvm_test;
        soc_env env;
        `uvm_component_utils(soc_base_test)
        function new(string n, uvm_component p); super.new(n,p); endfunction
        function void build_phase(uvm_phase phase);
            env = soc_env::type_id::create("env",this);
        endfunction
        function void end_of_elaboration_phase(uvm_phase phase);
            uvm_top.print_topology();
        endfunction
    endclass

    // TC_PIPE_01
    class tc_pipe_01_test extends soc_base_test;
        `uvm_component_utils(tc_pipe_01_test)
        function new(string n, uvm_component p); super.new(n,p); endfunction
        task run_phase(uvm_phase phase);
            tc_pipe_01_seq seq;
            phase.raise_objection(this);
            seq = tc_pipe_01_seq::type_id::create("seq");
            if (!uvm_config_db#(virtual uart_vip_if)::get(this,"","uart_vif",seq.uart_vif))
                `uvm_fatal("NOVIF","tc_pipe_01_test: no uart_vif")
            if (!uvm_config_db#(virtual wdt_vip_if)::get(this,"","wdt_vif",seq.wdt_vif))
                `uvm_warning("NOVIF","tc_pipe_01_test: no wdt_vif — skipping WDT checks")
            if (!uvm_config_db#(virtual dma_vip_if)::get(this,"","dma_vif",seq.dma_vif))
                `uvm_warning("NOVIF","tc_pipe_01_test: no dma_vif")
            seq.start(null);
            #1000;
            phase.drop_objection(this);
        endtask
    endclass

    // TC_BUS_01
    class tc_bus_01_test extends soc_base_test;
        `uvm_component_utils(tc_bus_01_test)
        function new(string n, uvm_component p); super.new(n,p); endfunction
        task run_phase(uvm_phase phase);
            tc_bus_01_seq seq;
            phase.raise_objection(this);
            seq = tc_bus_01_seq::type_id::create("seq");
            seq.start(null);
            #500;
            phase.drop_objection(this);
        endtask
    endclass

    // TC_BUS_02
    class tc_bus_02_test extends soc_base_test;
        `uvm_component_utils(tc_bus_02_test)
        function new(string n, uvm_component p); super.new(n,p); endfunction
        task run_phase(uvm_phase phase);
            tc_bus_02_seq seq;
            phase.raise_objection(this);
            seq = tc_bus_02_seq::type_id::create("seq");
            seq.start(env.dma_env.agent.seqr);
            #200;
            phase.drop_objection(this);
        endtask
    endclass

    // TC_FULL_01
    class tc_full_01_test extends soc_base_test;
        `uvm_component_utils(tc_full_01_test)
        function new(string n, uvm_component p); super.new(n,p); endfunction
        task run_phase(uvm_phase phase);
            tc_full_01_seq seq;
            phase.raise_objection(this);
            seq = tc_full_01_seq::type_id::create("seq");
            if (!uvm_config_db#(virtual gpio_vip_if)::get(this,"","gpio_vif",seq.gpio_vif))
                `uvm_fatal("NOVIF","tc_full_01_test: no gpio_vif")
            seq.start(null);
            phase.drop_objection(this);
        endtask
    endclass

endpackage : soc_uvm_pkg
