// aes_vip_monitor.sv — AES VIP monitor
// Samples DUT output pins: aes_busy_o, aes_done_o, aes_done_pulse_o, aes_irq_o.
// On posedge of aes_done_pulse_o, broadcasts an aes_vip_item on ap.
`timescale 1ns/1ps
class aes_vip_monitor extends uvm_monitor;
    virtual aes_vip_if vif;
    uvm_analysis_port #(aes_vip_item) ap;

    `uvm_component_utils(aes_vip_monitor)

    function new(string n, uvm_component p);
        super.new(n, p);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db #(virtual aes_vip_if)::get(this, "", "aes_vif", vif))
            `uvm_fatal("NOVIF", "aes_vip_monitor: aes_vif not in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        aes_vip_item item;
        forever begin
            // Wait for rising edge of done pulse (single-cycle)
            @(posedge vif.clk iff (vif.aes_done_pulse_o === 1'b1));
            item = aes_vip_item::type_id::create("mon_item");
            item.aes_busy       = vif.aes_busy_o;
            item.aes_done       = vif.aes_done_o;
            item.aes_done_pulse = vif.aes_done_pulse_o;
            item.aes_irq        = vif.aes_irq_o;
            // Pre-load FIPS-197 expected ciphertext for scoreboard
            item.exp_ct[0] = 32'h3925_841d;
            item.exp_ct[1] = 32'h02dc_09fb;
            item.exp_ct[2] = 32'hdc11_8597;
            item.exp_ct[3] = 32'h196a_0b32;
            `uvm_info("AES_MON", $sformatf(
                "aes_done_pulse: busy=%0b done=%0b irq=%0b",
                item.aes_busy, item.aes_done, item.aes_irq), UVM_MEDIUM)
            ap.write(item);
            // Wait for pulse to fall before next detection
            @(posedge vif.clk iff (vif.aes_done_pulse_o === 1'b0));
        end
    endtask
endclass
