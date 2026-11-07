// aes_vip_driver.sv — AES VIP driver
// The AES VIP is passive from the external pin perspective.
// AES key/plaintext/ciphertext registers are programmed by the CPU firmware
// via the AXI interconnect. External signals are all DUT outputs observed
// by the monitor (aes_busy_o, aes_done_o, aes_done_pulse_o, aes_irq_o).
// Driver burns a clock per item to keep the sequencer non-blocking.
`timescale 1ns/1ps
class aes_vip_driver extends uvm_driver #(aes_vip_item);
    virtual aes_vip_if vif;

    `uvm_component_utils(aes_vip_driver)

    function new(string n, uvm_component p); super.new(n, p); endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db #(virtual aes_vip_if)::get(this, "", "aes_vif", vif))
            `uvm_fatal("NOVIF", "aes_vip_driver: aes_vif not in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            seq_item_port.item_done();
        end
    endtask
endclass
