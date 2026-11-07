`timescale 1ns/1ps
// =============================================================================
// wdt_vip_monitor.sv — UVM monitor for WDT VIP
//
// Passively observes wdt_irq_o, wdt_nmi_o, wdt_reset_o on posedge clk.
// Detects posedge (0→1 transition) of each signal, creates a wdt_vip_item,
// and writes it to the analysis port so the scoreboard can check it.
//
// Virtual interface key: "wdt_vif"
// =============================================================================
class wdt_vip_monitor extends uvm_monitor;

  virtual wdt_vip_if               vif;
  uvm_analysis_port #(wdt_vip_item) ap;

  `uvm_component_utils(wdt_vip_monitor)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: grab virtual interface from config DB
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual wdt_vip_if)::get(this, "", "wdt_vif", vif))
      `uvm_fatal("NOVIF",
        "wdt_vip_monitor: virtual interface 'wdt_vif' not found in config DB")
  endfunction

  // ---------------------------------------------------------------------------
  // run_phase: spawn three parallel observers, one per DUT output signal
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    fork
      observe_irq();
      observe_nmi();
      observe_reset();
    join_none
  endtask

  // ---------------------------------------------------------------------------
  // observe_irq — watch for posedge wdt_irq_o
  // ---------------------------------------------------------------------------
  task observe_irq();
    wdt_vip_item item;
    bit          prev = 1'b0;
    forever begin
      @(posedge vif.clk);
      if (vif.wdt_irq_o && !prev) begin   // rising edge detected
        item           = wdt_vip_item::type_id::create("mon_irq");
        item.wdt_irq   = 1'b1;
        item.wdt_nmi   = vif.wdt_nmi_o;
        item.wdt_reset = vif.wdt_reset_o;
        `uvm_info("WDT_MON",
          $sformatf("wdt_irq_o POSEDGE detected  nmi=%0b reset=%0b",
                    item.wdt_nmi, item.wdt_reset),
          UVM_MEDIUM)
        ap.write(item);
      end
      prev = vif.wdt_irq_o;
    end
  endtask

  // ---------------------------------------------------------------------------
  // observe_nmi — watch for posedge wdt_nmi_o
  // ---------------------------------------------------------------------------
  task observe_nmi();
    wdt_vip_item item;
    bit          prev = 1'b0;
    forever begin
      @(posedge vif.clk);
      if (vif.wdt_nmi_o && !prev) begin   // rising edge detected
        item           = wdt_vip_item::type_id::create("mon_nmi");
        item.wdt_irq   = vif.wdt_irq_o;
        item.wdt_nmi   = 1'b1;
        item.wdt_reset = vif.wdt_reset_o;
        `uvm_info("WDT_MON",
          $sformatf("wdt_nmi_o POSEDGE detected  irq=%0b reset=%0b",
                    item.wdt_irq, item.wdt_reset),
          UVM_MEDIUM)
        ap.write(item);
      end
      prev = vif.wdt_nmi_o;
    end
  endtask

  // ---------------------------------------------------------------------------
  // observe_reset — watch for posedge wdt_reset_o
  // ---------------------------------------------------------------------------
  task observe_reset();
    wdt_vip_item item;
    bit          prev = 1'b0;
    forever begin
      @(posedge vif.clk);
      if (vif.wdt_reset_o && !prev) begin   // rising edge detected
        item           = wdt_vip_item::type_id::create("mon_reset");
        item.wdt_irq   = vif.wdt_irq_o;
        item.wdt_nmi   = vif.wdt_nmi_o;
        item.wdt_reset = 1'b1;
        `uvm_info("WDT_MON",
          $sformatf("wdt_reset_o POSEDGE detected  irq=%0b nmi=%0b",
                    item.wdt_irq, item.wdt_nmi),
          UVM_MEDIUM)
        ap.write(item);
      end
      prev = vif.wdt_reset_o;
    end
  endtask

endclass
