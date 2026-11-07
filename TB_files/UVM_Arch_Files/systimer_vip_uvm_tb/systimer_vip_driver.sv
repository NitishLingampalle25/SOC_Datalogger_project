// systimer_vip_driver.sv — SysTimer VIP driver
// The SysTimer VIP is passive from the external pin perspective.
// Timer registers are programmed by the CPU firmware via the AXI interconnect.
// The only external signal is timer_irq_o (DUT output, observed by monitor).
// Driver burns a clock per item to keep the sequencer non-blocking.
`timescale 1ns/1ps
class systimer_vip_driver extends uvm_driver #(systimer_vip_item);
    virtual systimer_vip_if vif;

    `uvm_component_utils(systimer_vip_driver)

    function new(string n, uvm_component p); super.new(n, p); endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db #(virtual systimer_vip_if)::get(this, "", "systimer_vif", vif))
            `uvm_fatal("NOVIF", "systimer_vip_driver: systimer_vif not in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            seq_item_port.item_done();
        end
    endtask
endclass
