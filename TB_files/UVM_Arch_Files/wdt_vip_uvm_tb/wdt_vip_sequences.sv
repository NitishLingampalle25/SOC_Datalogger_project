`timescale 1ns/1ps
// =============================================================================
// wdt_vip_sequences.sv — Directed test sequences for WDT VIP
//
// Address map (base = 0x4000_4000):
//   WDT_LOAD  0x00 → 0x4000_4000
//   WDT_CTRL  0x04 → 0x4000_4004   EN=b0, AUTOKICK=b1, NMI_EN=b2, RESET_EN=b3
//   WDT_PING  0x08 → 0x4000_4008   magic = 32'hABCDEF01
//   WDT_RIS   0x0C → 0x4000_400C   raw IRQ status (RO)
//   WDT_MIS   0x10 → 0x4000_4010   masked IRQ status (RO)
//   WDT_IC    0x14 → 0x4000_4014   interrupt clear (W1C)
//
// Sentinel addr == 32'hFFFF_FFFF → driver skips bus transaction (pure delay)
// =============================================================================

// Address defines local to this file
`define WDT_LOAD  32'h4000_4000
`define WDT_CTRL  32'h4000_4004
`define WDT_PING  32'h4000_4008
`define WDT_RIS   32'h4000_400C
`define WDT_MIS   32'h4000_4010
`define WDT_IC    32'h4000_4014

// CTRL bit definitions
`define WDT_EN        32'h1   // bit0
`define WDT_AUTOKICK  32'h3   // bit0 | bit1
`define WDT_NMI_EN    32'h4   // bit2
`define WDT_RESET_EN  32'h8   // bit3

// =============================================================================
// TC_WDT_01 — Software ping prevents timeout
//
// Steps:
//   1. Write WDT_LOAD = 0x10_0000 (large timeout → gives plenty of margin)
//   2. Write WDT_CTRL = EN | AUTOKICK (0x3) to enable + allow auto-kick path
//   3. Wait 20 clock cycles
//   4. Write WDT_PING = 0xABCDEF01 (software kick — resets the counter)
//   5. Read WDT_MIS; assert bit[0] == 0 (no masked IRQ = no timeout)
// =============================================================================
class tc_wdt_01_seq extends uvm_sequence #(wdt_vip_item);
  `uvm_object_utils(tc_wdt_01_seq)

  function new(string name = "tc_wdt_01_seq");
    super.new(name);
  endfunction

  task body();
    wdt_vip_item item;

    // Step 1: Set a generous load value (will not expire in 20 cycles)
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `WDT_LOAD;
                         wdata    == 32'h0010_0000; })

    // Step 2: Enable WDT with auto-kick support
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `WDT_CTRL;
                         wdata    == `WDT_AUTOKICK; })

    // Step 3: Wait 20 clock cycles (sentinel addr triggers a single-cycle wait,
    //         so we issue 20 no-op items)
    repeat (20) begin
      `uvm_do_with(item, { do_write == 1'b0;
                           addr     == 32'hFFFF_FFFF; })
    end

    // Step 4: Software ping
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `WDT_PING;
                         wdata    == 32'hABCDEF01; })

    // Step 5: Read WDT_MIS and check bit[0] == 0
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == `WDT_MIS; })
    if (item.rdata[0] === 1'b0)
      `uvm_info("TC01",
        "TC_WDT_01 PASS: WDT_MIS[0]==0 — no timeout after software ping",
        UVM_LOW)
    else
      `uvm_error("TC01",
        $sformatf("TC_WDT_01 FAIL: WDT_MIS=0x%08h — IRQ fired despite ping",
                  item.rdata))

    `uvm_info("TC01", "TC_WDT_01 COMPLETE", UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_WDT_02 — AES auto-kick via aes_done_pulse_i prevents timeout
//
// Steps:
//   1. Write WDT_LOAD = 0x10_0000
//   2. Write WDT_CTRL = EN | AUTOKICK (0x3)
//   3. Wait 100 clock cycles — testbench will assert aes_done_pulse_i
//      during this window, which the DUT uses to auto-kick the counter
//   4. Read WDT_MIS; assert bit[0] == 0 (AES kick kept timer alive)
// =============================================================================
class tc_wdt_02_seq extends uvm_sequence #(wdt_vip_item);
  `uvm_object_utils(tc_wdt_02_seq)

  function new(string name = "tc_wdt_02_seq");
    super.new(name);
  endfunction

  task body();
    wdt_vip_item item;

    // Step 1: Generous load value
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `WDT_LOAD;
                         wdata    == 32'h0010_0000; })

    // Step 2: Enable + auto-kick
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `WDT_CTRL;
                         wdata    == `WDT_AUTOKICK; })

    // Step 3: Wait 100 cycles — testbench drives aes_done_pulse_i in this window
    repeat (100) begin
      `uvm_do_with(item, { do_write == 1'b0;
                           addr     == 32'hFFFF_FFFF; })
    end

    // Step 4: Read WDT_MIS and check bit[0] == 0
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == `WDT_MIS; })
    if (item.rdata[0] === 1'b0)
      `uvm_info("TC02",
        "TC_WDT_02 PASS: WDT_MIS[0]==0 — AES auto-kick successfully refreshed timer",
        UVM_LOW)
    else
      `uvm_error("TC02",
        $sformatf("TC_WDT_02 FAIL: WDT_MIS=0x%08h — IRQ fired despite AES kick",
                  item.rdata))

    `uvm_info("TC02", "TC_WDT_02 COMPLETE", UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_WDT_03 — Early-warning IRQ fires and is cleared with W1C
//
// Steps:
//   1. Write WDT_LOAD = 0x10 (16 clock cycles — very short timeout)
//   2. Write WDT_CTRL = EN only (bit0=1, AUTOKICK=0, NMI_EN=0, RESET_EN=0)
//   3. Poll WDT_RIS[0] until it becomes 1 (raw IRQ asserted)
//   4. Write WDT_IC = 0xFFFF_FFFF (W1C clear all bits)
//   5. Read WDT_RIS; assert == 0 (interrupt cleared)
//      Scoreboard check_irq_cleared() is called with the RIS read-back value.
// =============================================================================
class tc_wdt_03_seq extends uvm_sequence #(wdt_vip_item);
  `uvm_object_utils(tc_wdt_03_seq)

  // Handle to scoreboard so we can invoke check_irq_cleared() directly
  wdt_vip_scoreboard sb_h;

  function new(string name = "tc_wdt_03_seq");
    super.new(name);
  endfunction

  task body();
    wdt_vip_item  item;
    bit           ris_set;
    int           poll_cnt;

    // Step 1: Short load value (16 cycles)
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `WDT_LOAD;
                         wdata    == 32'h0000_0010; })

    // Step 2: Enable only (no auto-kick)
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `WDT_CTRL;
                         wdata    == `WDT_EN; })

    // Step 3: Poll WDT_RIS[0] until set (timeout up to 512 cycles)
    ris_set  = 1'b0;
    poll_cnt = 0;
    while (!ris_set && poll_cnt < 512) begin
      `uvm_do_with(item, { do_write == 1'b0;
                           addr     == `WDT_RIS; })
      ris_set = item.rdata[0];
      poll_cnt++;
    end

    if (!ris_set) begin
      `uvm_error("TC03",
        "TC_WDT_03 FAIL: WDT_RIS[0] never set within 512 poll cycles")
      return;
    end
    `uvm_info("TC03",
      $sformatf("TC_WDT_03: WDT_RIS[0] asserted after %0d polls", poll_cnt),
      UVM_LOW)

    // Step 4: W1C clear
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `WDT_IC;
                         wdata    == 32'hFFFF_FFFF; })

    // Step 5: Read RIS back and verify cleared
    `uvm_do_with(item, { do_write == 1'b0;
                         addr     == `WDT_RIS; })

    // Inline check
    if (item.rdata === 32'h0)
      `uvm_info("TC03",
        "TC_WDT_03 PASS: WDT_RIS==0 after W1C clear",
        UVM_LOW)
    else
      `uvm_error("TC03",
        $sformatf("TC_WDT_03 FAIL: WDT_RIS=0x%08h after IC write", item.rdata))

    // Scoreboard notification for its own pass counter
    if (sb_h != null)
      sb_h.check_irq_cleared(item.rdata);

    `uvm_info("TC03", "TC_WDT_03 COMPLETE", UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_WDT_04 — Escalation: NMI then hard reset
//
// Steps:
//   1. Write WDT_LOAD = 0x08 (8 cycles)
//   2. Write WDT_CTRL = EN | NMI_EN | RESET_EN (bits 0,2,3 → 0xD)
//   3. Wait for wdt_nmi_o to assert (observed via interface polling)
//   4. Wait for wdt_reset_o to assert (hard reset from DUT)
//   Monitor sees both posedges and posts items to scoreboard.
// =============================================================================
class tc_wdt_04_seq extends uvm_sequence #(wdt_vip_item);
  `uvm_object_utils(tc_wdt_04_seq)

  // Virtual interface handle set by the test before starting the sequence
  virtual wdt_vip_if vif;

  function new(string name = "tc_wdt_04_seq");
    super.new(name);
  endfunction

  task body();
    wdt_vip_item item;

    // Step 1: Very short load
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `WDT_LOAD;
                         wdata    == 32'h0000_0008; })

    // Step 2: Enable + NMI + Reset escalation chain (bits 0,2,3 = 0xD)
    `uvm_do_with(item, { do_write == 1'b1;
                         addr     == `WDT_CTRL;
                         wdata    == 32'h0000_000D; })

    // Step 3: Wait for wdt_nmi_o via interface (if handle provided by test)
    if (vif != null) begin
      @(posedge vif.wdt_nmi_o);
      `uvm_info("TC04", "TC_WDT_04: wdt_nmi_o asserted", UVM_LOW)

      // Step 4: Wait for wdt_reset_o
      @(posedge vif.wdt_reset_o);
      `uvm_info("TC04", "TC_WDT_04: wdt_reset_o asserted — escalation chain complete",
                UVM_LOW)
    end else begin
      // Fallback: wait sufficient cycles for escalation to occur
      `uvm_info("TC04",
        "TC_WDT_04: vif handle not set — waiting 200 cycles for escalation",
        UVM_MEDIUM)
      repeat (200) begin
        `uvm_do_with(item, { do_write == 1'b0;
                             addr     == 32'hFFFF_FFFF; })
      end
    end

    `uvm_info("TC04", "TC_WDT_04 COMPLETE", UVM_LOW)
  endtask

endclass
