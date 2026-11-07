`timescale 1ns/1ps
// =============================================================================
// dma_vip_monitor.sv — UVM monitor for DMA VIP
//
// Passively observes three DMA output signals on every posedge clk:
//   dma_done_o   — transfer completion
//   dma_error_o  — transfer error / address decode error
//   dma_irq_o    — interrupt output (asserted together with dma_done_o
//                  when IRQ_EN is set in DMA_CTRL)
//
// When either dma_done_o or dma_error_o is detected HIGH, the monitor
// creates a dma_vip_item, fills the three status fields, and broadcasts
// it on the analysis port for the scoreboard.
//
// Virtual interface is obtained from uvm_config_db using key "dma_vif".
// =============================================================================
class dma_vip_monitor extends uvm_monitor;

  virtual dma_vip_if        vif;
  uvm_analysis_port #(dma_vip_item) ap;

  `uvm_component_utils(dma_vip_monitor)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: retrieve virtual interface from config DB
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual dma_vip_if)::get(this, "", "dma_vif", vif))
      `uvm_fatal("NOVIF",
        "dma_vip_monitor: virtual interface 'dma_vif' not found in config DB")
  endfunction

  // ---------------------------------------------------------------------------
  // run_phase: sample status signals, broadcast item on terminal events
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    dma_vip_item item;

    // Wait for reset de-assertion before monitoring
    @(posedge vif.rst_n);

    forever begin
      // Sample on every positive clock edge
      @(posedge vif.clk);

      // Only generate an item when a terminal event fires
      if (vif.dma_done_o || vif.dma_error_o) begin
        item           = dma_vip_item::type_id::create("mon_item");
        item.dma_done  = vif.dma_done_o;
        item.dma_error = vif.dma_error_o;
        item.dma_irq   = vif.dma_irq_o;

        `uvm_info("DMA_MON",
          $sformatf("DMA terminal event — done=%0b  error=%0b  irq=%0b",
                    item.dma_done, item.dma_error, item.dma_irq),
          UVM_MEDIUM)

        ap.write(item);

        // Advance past the pulse so we do not re-trigger on the same edge
        @(posedge vif.clk);
      end
    end
  endtask

endclass
