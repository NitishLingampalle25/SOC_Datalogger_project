`timescale 1ns/1ps
// =============================================================================
// dma_vip_sequences.sv — Directed test sequences for DMA VIP
//
// DMA register address map (base = 0x4000_3000):
//   DMA_SRC_ADDR  0x4000_3000   source address
//   DMA_DST_ADDR  0x4000_3004   destination address
//   DMA_XFER_LEN  0x4000_3008   transfer length in bytes
//   DMA_CTRL      0x4000_300C   [1:0] START | IRQ_EN
//   DMA_STATUS    0x4000_3010   [2:0] BUSY | DONE | ERROR
//
// Relevant system addresses:
//   UART_BASE     0x4000_0000   source for TC_DMA_01
//   DCCM_BASE     0x1000_0000   destination for TC_DMA_01
//   UNMAPPED_DST  0x4000_9000   unmapped destination for TC_DMA_02
//
// Sentinel:
//   addr == 32'hFFFF_FFFF  →  driver skips AXI, burns one clock (polling gap)
// =============================================================================

// ---------------------------------------------------------------------------
// Address / control word constants
// ---------------------------------------------------------------------------
`define DMA_BASE        32'h4000_3000
`define DMA_SRC_ADDR    32'h4000_3000
`define DMA_DST_ADDR    32'h4000_3004
`define DMA_XFER_LEN    32'h4000_3008
`define DMA_CTRL        32'h4000_300C
`define DMA_STATUS      32'h4000_3010

`define UART_BASE       32'h4000_0000
`define DCCM_BASE       32'h1000_0000
`define UNMAPPED_DST    32'h4000_9000

// DMA_CTRL bit fields
`define DMA_CTRL_START  32'h0000_0001   // bit 0
`define DMA_CTRL_IRQ_EN 32'h0000_0002   // bit 1
`define DMA_CTRL_GO     32'h0000_0003   // START | IRQ_EN

// DMA_STATUS bit fields
`define DMA_STATUS_BUSY  32'h0000_0001   // bit 0
`define DMA_STATUS_DONE  32'h0000_0002   // bit 1
`define DMA_STATUS_ERROR 32'h0000_0004   // bit 2

// Maximum poll iterations before timeout
`define DMA_POLL_LIMIT   1000

// =============================================================================
// tc_dma_01_seq — Burst transfer: UART_BASE → DCCM_BASE, length = 64 bytes
//
// Steps:
//   1. Write SRC  = 0x4000_0000 (UART RX staging base)
//   2. Write DST  = 0x1000_0000 (DCCM base)
//   3. Write LEN  = 64 bytes
//   4. Write CTRL = 0x3 (START | IRQ_EN) — kicks off the DMA
//   5. Poll STATUS[DONE] (bit 1) up to DMA_POLL_LIMIT cycles
//   6. Timeout is a non-fatal warning; scoreboard makes the pass/fail call
//      based on dma_done_o / dma_irq_o captured by the monitor.
// =============================================================================
class tc_dma_01_seq extends uvm_sequence #(dma_vip_item);
  `uvm_object_utils(tc_dma_01_seq)

  function new(string name = "tc_dma_01_seq");
    super.new(name);
  endfunction

  task body();
    dma_vip_item item;
    int          poll_cnt;
    bit          done_seen;

    `uvm_info("TC01_SEQ", "TC_DMA_01: Starting burst-transfer sequence", UVM_LOW)

    // ------------------------------------------------------------------
    // Step 1: program source address = UART_BASE
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `DMA_SRC_ADDR;
                         wdata    == `UART_BASE; })

    // ------------------------------------------------------------------
    // Step 2: program destination address = DCCM_BASE
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `DMA_DST_ADDR;
                         wdata    == `DCCM_BASE; })

    // ------------------------------------------------------------------
    // Step 3: program transfer length = 64 bytes
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `DMA_XFER_LEN;
                         wdata    == 32'd64; })

    // ------------------------------------------------------------------
    // Step 4: start the DMA with IRQ enabled
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `DMA_CTRL;
                         wdata    == `DMA_CTRL_GO; })

    `uvm_info("TC01_SEQ",
      "TC_DMA_01: DMA_CTRL written (START|IRQ_EN=0x3) — DMA running",
      UVM_MEDIUM)

    // ------------------------------------------------------------------
    // Step 5: poll DMA_STATUS[DONE] (bit 1) up to DMA_POLL_LIMIT times
    // ------------------------------------------------------------------
    poll_cnt  = 0;
    done_seen = 1'b0;

    while (!done_seen && poll_cnt < `DMA_POLL_LIMIT) begin
      `uvm_do_with(item, { do_write == 1'b0;
                           addr     == `DMA_STATUS; })
      if (item.rdata & `DMA_STATUS_DONE)
        done_seen = 1'b1;
      poll_cnt++;
    end

    if (done_seen)
      `uvm_info("TC01_SEQ",
        $sformatf("TC_DMA_01: STATUS[DONE] set after %0d poll cycles",
                  poll_cnt),
        UVM_LOW)
    else
      `uvm_warning("TC01_SEQ",
        $sformatf("TC_DMA_01: STATUS[DONE] NOT seen after %0d polls — monitor/scoreboard will catch timeout",
                  `DMA_POLL_LIMIT))

    `uvm_info("TC01_SEQ", "TC_DMA_01 sequence complete", UVM_LOW)
  endtask

endclass

// =============================================================================
// tc_dma_02_seq — Error-abort: write to unmapped destination 0x4000_9000
//
// Steps:
//   1. Write SRC  = 0x4000_0000
//   2. Write DST  = 0x4000_9000 (unmapped — will cause SLVERR on bus)
//   3. Write LEN  = 64 bytes
//   4. Write CTRL = START (no IRQ_EN; error abort does not need IRQ)
//   5. Poll STATUS[ERROR] (bit 2) up to DMA_POLL_LIMIT cycles
//   6. Timeout is a non-fatal warning; scoreboard evaluates dma_error_o.
// =============================================================================
class tc_dma_02_seq extends uvm_sequence #(dma_vip_item);
  `uvm_object_utils(tc_dma_02_seq)

  function new(string name = "tc_dma_02_seq");
    super.new(name);
  endfunction

  task body();
    dma_vip_item item;
    int          poll_cnt;
    bit          error_seen;

    `uvm_info("TC02_SEQ",
      "TC_DMA_02: Starting error-abort sequence (unmapped dst=0x4000_9000)",
      UVM_LOW)

    // ------------------------------------------------------------------
    // Step 1: program source address
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `DMA_SRC_ADDR;
                         wdata    == `UART_BASE; })

    // ------------------------------------------------------------------
    // Step 2: program unmapped destination — will trigger SLVERR
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `DMA_DST_ADDR;
                         wdata    == `UNMAPPED_DST; })

    // ------------------------------------------------------------------
    // Step 3: program transfer length = 64 bytes
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `DMA_XFER_LEN;
                         wdata    == 32'd64; })

    // ------------------------------------------------------------------
    // Step 4: start the DMA (no IRQ_EN for error test)
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `DMA_CTRL;
                         wdata    == `DMA_CTRL_START; })

    `uvm_info("TC02_SEQ",
      "TC_DMA_02: DMA_CTRL written (START=0x1) — expecting error abort",
      UVM_MEDIUM)

    // ------------------------------------------------------------------
    // Step 5: poll DMA_STATUS[ERROR] (bit 2) up to DMA_POLL_LIMIT times
    // ------------------------------------------------------------------
    poll_cnt  = 0;
    error_seen = 1'b0;

    while (!error_seen && poll_cnt < `DMA_POLL_LIMIT) begin
      `uvm_do_with(item, { do_write == 1'b0;
                           addr     == `DMA_STATUS; })
      if (item.rdata & `DMA_STATUS_ERROR)
        error_seen = 1'b1;
      poll_cnt++;
    end

    if (error_seen)
      `uvm_info("TC02_SEQ",
        $sformatf("TC_DMA_02: STATUS[ERROR] set after %0d poll cycles",
                  poll_cnt),
        UVM_LOW)
    else
      `uvm_warning("TC02_SEQ",
        $sformatf("TC_DMA_02: STATUS[ERROR] NOT seen after %0d polls — monitor/scoreboard will catch",
                  `DMA_POLL_LIMIT))

    `uvm_info("TC02_SEQ", "TC_DMA_02 sequence complete", UVM_LOW)
  endtask

endclass
