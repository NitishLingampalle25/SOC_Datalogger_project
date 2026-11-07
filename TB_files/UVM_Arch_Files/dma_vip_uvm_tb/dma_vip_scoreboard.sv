`timescale 1ns/1ps
// =============================================================================
// dma_vip_scoreboard.sv — UVM scoreboard for DMA VIP
//
// Receives dma_vip_item from the monitor's analysis port.
//
// Checks implemented:
//   TC_DMA_01 — burst transfer:
//     PASS when  dma_done == 1  &&  dma_irq == 1  &&  dma_error == 0
//     FAIL otherwise (done missing, irq missing, or spurious error)
//
//   TC_DMA_02 — error-abort to unmapped address 0x4000_9000:
//     PASS when  dma_error == 1  &&  dma_done == 1
//     FAIL otherwise
//
// Discrimination:
//   The scoreboard uses dma_error to route an item to the appropriate check.
//   • dma_error == 0  →  evaluate TC_DMA_01 pass criteria
//   • dma_error == 1  →  evaluate TC_DMA_02 pass criteria
//
// report_phase prints a summary of pass/fail counts.
// =============================================================================
class dma_vip_scoreboard extends uvm_scoreboard;

  uvm_analysis_imp #(dma_vip_item, dma_vip_scoreboard) ap;

  int pass_cnt;
  int fail_cnt;
  int item_cnt;   // total items observed

  `uvm_component_utils(dma_vip_scoreboard)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
    pass_cnt = 0;
    fail_cnt = 0;
    item_cnt = 0;
  endfunction

  // ---------------------------------------------------------------------------
  // write() — called by analysis port for every terminal DMA event
  // ---------------------------------------------------------------------------
  function void write(dma_vip_item item);
    item_cnt++;

    // -----------------------------------------------------------------------
    // TC_DMA_01: Normal burst transfer
    //   Expected: dma_done=1, dma_irq=1, dma_error=0
    // -----------------------------------------------------------------------
    if (!item.dma_error) begin
      if (item.dma_done && item.dma_irq && !item.dma_error) begin
        `uvm_info("DMA_SB",
          "TC_DMA_01 PASS: dma_done=1, dma_irq=1, dma_error=0",
          UVM_LOW)
        pass_cnt++;
      end else begin
        // Report which field(s) were unexpected
        if (!item.dma_done)
          `uvm_error("DMA_SB",
            "TC_DMA_01 FAIL: dma_done NOT asserted after burst transfer")
        if (!item.dma_irq)
          `uvm_error("DMA_SB",
            "TC_DMA_01 FAIL: dma_irq_o NOT asserted (IRQ_EN was set in CTRL)")
        fail_cnt++;
      end
    end

    // -----------------------------------------------------------------------
    // TC_DMA_02: Error-abort on unmapped destination (0x4000_9000)
    //   Expected: dma_error=1, dma_done=1
    // -----------------------------------------------------------------------
    else begin
      if (item.dma_error && item.dma_done) begin
        `uvm_info("DMA_SB",
          "TC_DMA_02 PASS: dma_error=1, dma_done=1 (transfer aborted correctly)",
          UVM_LOW)
        pass_cnt++;
      end else begin
        if (!item.dma_error)
          `uvm_error("DMA_SB",
            "TC_DMA_02 FAIL: dma_error NOT asserted for unmapped destination")
        if (!item.dma_done)
          `uvm_error("DMA_SB",
            "TC_DMA_02 FAIL: dma_done NOT asserted after error abort")
        fail_cnt++;
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // report_phase — print summary
  // ---------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info("DMA_SB",
      $sformatf({"==============================\n",
                 "  DMA Scoreboard Summary\n",
                 "  Total items  : %0d\n",
                 "  PASS         : %0d\n",
                 "  FAIL         : %0d\n",
                 "=============================="},
                item_cnt, pass_cnt, fail_cnt),
      UVM_LOW)
    if (fail_cnt > 0)
      `uvm_error("DMA_SB", "One or more DMA VIP checks FAILED")
  endfunction

endclass
