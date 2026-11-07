// wdt_vip_driver.sv — WDT VIP driver
// The WDT VIP is passive from the external pin perspective.
// WDT registers (LOAD, CTRL, PING, IC) are programmed by the CPU firmware
// via the AXI interconnect. External signals are all DUT outputs observed
// by the monitor. Driver burns a clock per item to keep sequencer live.
`timescale 1ns/1ps
class wdt_vip_driver extends uvm_driver #(wdt_vip_item);
    virtual wdt_vip_if vif;

    `uvm_component_utils(wdt_vip_driver)

    function new(string n, uvm_component p); super.new(n, p); endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db #(virtual wdt_vip_if)::get(this, "", "wdt_vif", vif))
            `uvm_fatal("NOVIF", "wdt_vip_driver: wdt_vif not in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            seq_item_port.item_done();
        end
    endtask
endclass
