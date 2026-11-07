`timescale 1ns/1ps
// =============================================================================
// systimer_vip_sequences.sv — Directed test sequences for SysTimer VIP
//
// Timer register map (base = 0x4000_1000):
//   TIMER_VAL_LO  0x4000_1100  (read-only: current free-running counter)
//   TIMER_CMP     0x4000_1104  (compare threshold; IRQ fires at match)
//   TIMER_CTRL    0x4000_1108  (EN = bit0: 1=run, 0=halt)
//   TIMER_CFG0    0x4000_110C  (prescaler config)
//   TIMER_INTR_EN 0x4000_1110  (interrupt enable; bit0=1 enables IRQ)
//   TIMER_INTR_ST 0x4000_1114  (interrupt status; bit0=pending; W1C clear)
// =============================================================================

// Address constants (local to this file)
`define TMR_VAL_LO  32'h4000_1100
`define TMR_CMP     32'h4000_1104
`define TMR_CTRL    32'h4000_1108
`define TMR_CFG0    32'h4000_110C
`define TMR_INTR_EN 32'h4000_1110
`define TMR_INTR_ST 32'h4000_1114

// =============================================================================
// TC_TMR_01 — Prescaler configuration + counter increment verification
//
// Steps:
//   1. Write TIMER_CFG0 = 0x0000_0901  (prescaler = 9, divide-by-10)
//   2. Write TIMER_CMP  = 0xFFFF_FFFF  (no compare match during this test)
//   3. Write TIMER_CTRL = 0x1           (enable timer, EN=bit0)
//   4. Read  TIMER_VAL_LO → t0         (snapshot before wait)
//   5. Wait  50 clock cycles
//   6. Read  TIMER_VAL_LO → t1         (snapshot after wait)
//   7. Assert t1 > t0; log PASS or FAIL inline (scoreboard not involved)
// =============================================================================
class tc_tmr_01_seq extends uvm_sequence #(systimer_vip_item);

  `uvm_object_utils(tc_tmr_01_seq)

  function new(string name = "tc_tmr_01_seq");
    super.new(name);
  endfunction

  task body();
    systimer_vip_item item;

    // ------------------------------------------------------------------
    // Step 1: Configure prescaler — divide-by-10 (prescaler value = 9)
    //         CFG0[7:0] = 0x09 with mode bit[8]=1 → 0x0000_0901
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `TMR_CFG0;
                         wdata    == 32'h0000_0901; })

    // ------------------------------------------------------------------
    // Step 2: Set compare to max so no IRQ fires during counter read test
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `TMR_CMP;
                         wdata    == 32'hFFFF_FFFF; })

    // ------------------------------------------------------------------
    // Step 3: Enable timer (EN = bit0)
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `TMR_CTRL;
                         wdata    == 32'h0000_0001; })

    // ------------------------------------------------------------------
    // Step 4: Read TIMER_VAL_LO — capture t0 (initial counter value)
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == `TMR_VAL_LO; })
    begin
      automatic bit [31:0] t0 = item.rdata;
      automatic bit [31:0] t1;

      `uvm_info("TC_TMR_01",
        $sformatf("t0 = 0x%08h — waiting 50 clock cycles", t0),
        UVM_MEDIUM)

      // ------------------------------------------------------------------
      // Step 5: Wait 50 posedge clk cycles — use fork/join with the VIF
      // Access the virtual interface via the sequencer's parent agent.
      // The wait is performed by driving a null item that lets the driver
      // block for 50 cycles; instead we use a simpler repeat inside a
      // void sequence context via the built-in clocking.
      // ------------------------------------------------------------------
      // Note: sequences cannot directly access VIF; the standard UVM
      // approach is to drive additional items or use a p_sequencer handle.
      // Here we use `uvm_do with a 50-cycle wait leveraged through the
      // driver by issuing a read that naturally uses @posedge clk edges.
      // For portability we instead issue 50 back-to-back reads of VAL_LO
      // (each read takes at least 2-3 cycles through the AXI handshake),
      // which guarantees forward progress.  This is an acceptable
      // trade-off; see comment in test class for VIF-based alternative.
      repeat (50) begin
        `uvm_do_with(item, { do_write == 1'b0;
                             addr     == `TMR_VAL_LO; })
      end

      // ------------------------------------------------------------------
      // Step 6: Final read of VAL_LO — capture t1
      // ------------------------------------------------------------------
      `uvm_do_with(item, { do_write == 1'b0;
                           addr     == `TMR_VAL_LO; })
      t1 = item.rdata;

      `uvm_info("TC_TMR_01",
        $sformatf("t1 = 0x%08h", t1),
        UVM_MEDIUM)

      // ------------------------------------------------------------------
      // Step 7: Inline check — counter must have advanced
      // ------------------------------------------------------------------
      if (t1 > t0)
        `uvm_info("TC_TMR_01",
          $sformatf("PASS: counter incremented from 0x%08h to 0x%08h (delta=%0d)",
                    t0, t1, t1 - t0),
          UVM_LOW)
      else
        `uvm_error("TC_TMR_01",
          $sformatf("FAIL: counter did NOT increment — t0=0x%08h t1=0x%08h",
                    t0, t1))
    end

    `uvm_info("TC_TMR_01", "TC_TMR_01 COMPLETE", UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_TMR_02 — Compare-match interrupt + W1C clear verification
//
// Steps:
//   1. Read  TIMER_VAL_LO → t0
//   2. Write TIMER_CMP    = t0 + 100   (compare fires ~100 ticks later)
//   3. Write TIMER_INTR_EN = 0x1        (enable compare-match interrupt)
//   4. Poll  TIMER_INTR_ST until bit0 is set (interrupt pending)
//   5. Write TIMER_INTR_ST = 0x1        (W1C: clear the pending interrupt)
//   6. Read  TIMER_INTR_ST → assert it is 0x0 (successfully cleared)
//
// The monitor independently detects timer_irq_o posedge and the scoreboard
// logs TC_TMR_02 PASS.  The inline read-back of INTR_ST after W1C is a
// second independent check in the sequence itself.
// =============================================================================
class tc_tmr_02_seq extends uvm_sequence #(systimer_vip_item);

  `uvm_object_utils(tc_tmr_02_seq)

  function new(string name = "tc_tmr_02_seq");
    super.new(name);
  endfunction

  task body();
    systimer_vip_item item;

    // ------------------------------------------------------------------
    // Step 1: Read current counter value t0
    // ------------------------------------------------------------------
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == `TMR_VAL_LO; })
    begin
      automatic bit [31:0] t0        = item.rdata;
      automatic bit [31:0] cmp_val   = t0 + 32'd100;
      automatic bit        irq_seen  = 1'b0;
      automatic int        poll_iter = 0;
      automatic int        max_polls = 10000; // safety timeout

      `uvm_info("TC_TMR_02",
        $sformatf("t0=0x%08h  CMP target=0x%08h", t0, cmp_val),
        UVM_MEDIUM)

      // ------------------------------------------------------------------
      // Step 2: Write compare register = t0 + 100
      // ------------------------------------------------------------------
      `uvm_do_with(item, { do_write == 1'b1;
                           addr     == `TMR_CMP;
                           wdata    == cmp_val; })

      // ------------------------------------------------------------------
      // Step 3: Enable compare-match interrupt (INTR_EN[0] = 1)
      // ------------------------------------------------------------------
      `uvm_do_with(item, { do_write == 1'b1;
                           addr     == `TMR_INTR_EN;
                           wdata    == 32'h0000_0001; })

      // ------------------------------------------------------------------
      // Step 4: Poll TIMER_INTR_ST until bit0 is set
      //         Break on first assertion or on safety timeout.
      // ------------------------------------------------------------------
      irq_seen  = 1'b0;
      poll_iter = 0;
      while (!irq_seen && poll_iter < max_polls) begin
        `uvm_do_with(item, { do_write == 1'b0;
                             addr     == `TMR_INTR_ST; })
        if (item.rdata[0] === 1'b1)
          irq_seen = 1'b1;
        poll_iter++;
      end

      if (!irq_seen) begin
        `uvm_error("TC_TMR_02",
          $sformatf("FAIL: TIMER_INTR_ST[0] never set after %0d polls (CMP=0x%08h)",
                    max_polls, cmp_val))
      end else begin
        `uvm_info("TC_TMR_02",
          $sformatf("INTR_ST[0] set after %0d polls — issuing W1C clear",
                    poll_iter),
          UVM_MEDIUM)
      end

      // ------------------------------------------------------------------
      // Step 5: Clear interrupt status using W1C (write 1 to bit0)
      // ------------------------------------------------------------------
      `uvm_do_with(item, { do_write == 1'b1;
                           addr     == `TMR_INTR_ST;
                           wdata    == 32'h0000_0001; })

      // ------------------------------------------------------------------
      // Step 6: Read back INTR_ST — must be 0 after W1C
      // ------------------------------------------------------------------
      `uvm_do_with(item, { do_write == 1'b0;
                           addr     == `TMR_INTR_ST; })

      if (item.rdata[0] === 1'b0)
        `uvm_info("TC_TMR_02",
          "PASS: TIMER_INTR_ST[0] cleared to 0 after W1C write",
          UVM_LOW)
      else
        `uvm_error("TC_TMR_02",
          $sformatf("FAIL: TIMER_INTR_ST[0] still set after W1C write (rdata=0x%08h)",
                    item.rdata))
    end

    `uvm_info("TC_TMR_02", "TC_TMR_02 COMPLETE", UVM_LOW)
  endtask

endclass
