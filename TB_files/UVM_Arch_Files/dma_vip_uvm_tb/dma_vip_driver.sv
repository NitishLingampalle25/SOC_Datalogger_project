// dma_vip_driver.sv — DMA VIP driver
// The DMA VIP is a passive (monitor-only) VIP from the external pin perspective.
// DMA descriptor registers are programmed by the CPU firmware via the AXI
// interconnect — there are no external pins for the testbench to drive.
// This driver simply burns a clock cycle per item so the sequencer does not stall.
`timescale 1ns/1ps
class dma_vip_driver extends uvm_driver #(dma_vip_item);
    virtual dma_vip_if vif;

    `uvm_component_utils(dma_vip_driver)

    function new(string n, uvm_component p); super.new(n, p); endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db #(virtual dma_vip_if)::get(this, "", "dma_vif", vif))
            `uvm_fatal("NOVIF", "dma_vip_driver: dma_vif not in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk); // passive: just advance time
            seq_item_port.item_done();
        end
    endtask
endclass
