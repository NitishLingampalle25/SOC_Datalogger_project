`timescale 1ns/1ps
// =============================================================================
// systimer_vip_monitor.sv — UVM monitor for SysTimer VIP
//
// Passively watches the timer_irq_o signal from the DUT.
// On every rising edge of timer_irq_o, creates a systimer_vip_item with
// timer_irq_obs=1 and broadcasts it on the analysis port.
// The scoreboard subscribes to this port to perform TC_TMR_02 checking.
// =============================================================================
class systimer_vip_monitor extends uvm_monitor;

  virtual systimer_vip_if           vif;
  uvm_analysis_port #(systimer_vip_item) ap;

  `uvm_component_utils(systimer_vip_monitor)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: grab virtual interface from config DB
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual systimer_vip_if)::get(
          this, "", "systimer_vif", vif))
      `uvm_fatal("NOVIF",
        "systimer_vip_monitor: 'systimer_vif' not found in uvm_config_db")
  endfunction

  // ---------------------------------------------------------------------------
  // run_phase: detect every posedge on timer_irq_o, broadcast an item
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    systimer_vip_item item;

    forever begin
      // Wait for the rising edge of the DUT interrupt output
      @(posedge vif.timer_irq_o);

      item = systimer_vip_item::type_id::create("mon_item");
      item.timer_irq_obs = 1'b1;

      `uvm_info("TMR_MON",
        "timer_irq_o posedge detected — broadcasting item with timer_irq_obs=1",
        UVM_MEDIUM)

      ap.write(item);
    end
  endtask

endclass
