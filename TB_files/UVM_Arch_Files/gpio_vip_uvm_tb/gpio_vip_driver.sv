`timescale 1ns/1ps
// =============================================================================
// gpio_vip_driver.sv — UVM driver for GPIO VIP (pin-level only)
//
// This VIP is a pin-level VIP.  The CPU writes to GPIO control registers
// (GPIO_EN, GPIO_OUT, GPIO_RISE_EN, etc.) through the SoC interconnect;
// those paths are not modelled here.  The driver's sole responsibility is:
//
//   1. Drive gpio_in_i from item.gpio_in_val (simulates external pin stimulus)
//   2. Wait one posedge clk so the DUT can register the new input
//   3. Call item_done — the monitor independently samples outputs
//
// Interface key: config DB key = "gpio_vif"
// =============================================================================
class gpio_vip_driver extends uvm_driver #(gpio_vip_item);

  virtual gpio_vip_if vif;

  `uvm_component_utils(gpio_vip_driver)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase — fetch virtual interface from config DB
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual gpio_vip_if)::get(this, "", "gpio_vif", vif))
      `uvm_fatal("NOVIF",
        "gpio_vip_driver: virtual interface 'gpio_vif' not found in config DB")
  endfunction

  // ---------------------------------------------------------------------------
  // run_phase — idle then drive items
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    // Hold gpio_in_i at 0 until the first item arrives
    vif.gpio_in_i <= 32'h0;

    forever begin
      // -----------------------------------------------------------------------
      // 1. Get the next item from the sequencer
      // -----------------------------------------------------------------------
      seq_item_port.get_next_item(req);

      // -----------------------------------------------------------------------
      // 2. Drive gpio_in_i to the stimulus value in the item
      // -----------------------------------------------------------------------
      vif.gpio_in_i <= req.gpio_in_val;

      // -----------------------------------------------------------------------
      // 3. Wait one clock so the DUT latches the new input value
      // -----------------------------------------------------------------------
      @(posedge vif.clk);

      // -----------------------------------------------------------------------
      // 4. Signal completion — monitor samples outputs independently
      // -----------------------------------------------------------------------
      seq_item_port.item_done();
    end
  endtask

endclass
