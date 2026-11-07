`timescale 1ns/1ps
// =============================================================================
// gpio_vip_monitor.sv — UVM monitor for GPIO VIP
//
// Passively observes the three DUT-driven pin signals:
//   gpio_out_o    — current output data driven to pads
//   gpio_tx_en_o  — per-pin output-enable (1 = configured as output)
//   gpio_irq_o    — edge-detect interrupt to the processor
//
// Sampling strategy:
//   On every positive clock edge, compare the current sampled values to the
//   previous cycle.  If any signal changed, package the observations into a
//   gpio_vip_item and broadcast it on the analysis port.  This captures both
//   the steady-state value (for TC_GPIO_01 / TC_GPIO_02) and any transient
//   assertion (for TC_GPIO_03).
// =============================================================================
class gpio_vip_monitor extends uvm_monitor;

  virtual gpio_vip_if            vif;
  uvm_analysis_port #(gpio_vip_item) ap;

  `uvm_component_utils(gpio_vip_monitor)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase — fetch virtual interface
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual gpio_vip_if)::get(this, "", "gpio_vif", vif))
      `uvm_fatal("NOVIF",
        "gpio_vip_monitor: virtual interface 'gpio_vif' not found in config DB")
  endfunction

  // ---------------------------------------------------------------------------
  // run_phase — sample on every clock; broadcast on any change
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    gpio_vip_item  item;
    logic [31:0]   prev_out    = 32'hX;
    logic [31:0]   prev_tx_en  = 32'hX;
    logic          prev_irq    = 1'bX;

    // Wait for reset to deassert before monitoring
    @(posedge vif.rst_n);

    forever begin
      @(posedge vif.clk);
      #1; // small delta delay — let combinational outputs settle

      // Detect any change on any monitored signal
      if ((vif.gpio_out_o   !== prev_out)   ||
          (vif.gpio_tx_en_o !== prev_tx_en) ||
          (vif.gpio_irq_o   !== prev_irq)) begin

        item = gpio_vip_item::type_id::create("mon_item");

        // Capture current observed values
        item.gpio_out_obs   = vif.gpio_out_o;
        item.gpio_tx_en_obs = vif.gpio_tx_en_o;
        item.gpio_irq_obs   = vif.gpio_irq_o;
        // Also snapshot the current gpio_in_i for TC_GPIO_02 cross-check
        item.gpio_in_val    = vif.gpio_in_i;

        `uvm_info("GPIO_MON",
          $sformatf("GPIO change detected: gpio_out_o=0x%08h  gpio_tx_en_o=0x%08h  gpio_irq_o=%0b  gpio_in_i=0x%08h",
                    item.gpio_out_obs, item.gpio_tx_en_obs,
                    item.gpio_irq_obs, item.gpio_in_val),
          UVM_MEDIUM)

        ap.write(item);

        // Update previous state
        prev_out   = vif.gpio_out_o;
        prev_tx_en = vif.gpio_tx_en_o;
        prev_irq   = vif.gpio_irq_o;
      end
    end
  endtask

endclass
