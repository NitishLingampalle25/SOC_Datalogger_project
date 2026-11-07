// uart_vip_driver.sv — UART VIP driver
// Drives serial byte stimulus on uart_rx_i (NRZ 8N1, LSB-first).
// No AXI-Lite logic — register access is done by the CPU firmware through
// the SoC interconnect, not by this testbench driver.
`timescale 1ns/1ps
class uart_vip_driver extends uvm_driver #(uart_vip_item);
    virtual uart_vip_if vif;
    localparam int BIT_CYCLES = 10; // matches SIM_BAUD_DIV in DUT

    `uvm_component_utils(uart_vip_driver)

    function new(string n, uvm_component p); super.new(n, p); endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db #(virtual uart_vip_if)::get(this, "", "uart_vif", vif))
            `uvm_fatal("NOVIF", "uart_vip_driver: uart_vif not in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        vif.uart_rx_i <= 1'b1; // idle mark
        forever begin
            seq_item_port.get_next_item(req);
            if (req.tx_byte !== 8'hFF) // 8'hFF = sentinel = no injection
                inject_serial_byte(req.tx_byte);
            else
                @(posedge vif.clk);
            seq_item_port.item_done();
        end
    endtask

    // NRZ 8N1: start(0) + 8 bits LSB-first + stop(1)
    task inject_serial_byte(input bit [7:0] bval);
        vif.uart_rx_i <= 1'b0;                    // start bit
        repeat(BIT_CYCLES) @(posedge vif.clk);
        for (int i = 0; i < 8; i++) begin
            vif.uart_rx_i <= bval[i];
            repeat(BIT_CYCLES) @(posedge vif.clk);
        end
        vif.uart_rx_i <= 1'b1;                    // stop bit
        repeat(BIT_CYCLES) @(posedge vif.clk);
    endtask
endclass
