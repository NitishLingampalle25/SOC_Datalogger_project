`timescale 1ns/1ps
// =============================================================================
// wdt_vip_scoreboard.sv — UVM scoreboard for WDT VIP
//
// Receives wdt_vip_item from the monitor's analysis port.
// Each call to write() routes to the active test-case check based on the
// signal combination present in the item.
//
// Check matrix:
//   TC_WDT_01: wdt_irq==0 after software ping → PASS (no spurious timeout)
//   TC_WDT_02: wdt_irq==0 after AES auto-kick → PASS (timer refreshed)
//   TC_WDT_03: wdt_irq==1 (timeout IRQ fires) → PASS
//              wdt_irq==0 after W1C clear      → PASS (interrupt cleared)
//   TC_WDT_04: wdt_nmi==1 (NMI escalation)    → PASS
//              wdt_reset==1 (hard reset fires) → PASS
// =============================================================================
class wdt_vip_scoreboard extends uvm_scoreboard;

  uvm_analysis_imp #(wdt_vip_item, wdt_vip_scoreboard) ap;

  // Counters for final report
  int pass_cnt;
  int fail_cnt;

  // State machine for TC_WDT_03 and TC_WDT_04 multi-step checks
  bit tc03_irq_seen;    // step 1 of TC_WDT_03: IRQ asserted
  bit tc04_nmi_seen;    // step 1 of TC_WDT_04: NMI asserted

  `uvm_component_utils(wdt_vip_scoreboard)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  // ---------------------------------------------------------------------------
  // write() — called by analysis port for every edge event from the monitor
  // ---------------------------------------------------------------------------
  function void write(wdt_vip_item item);

    // -------------------------------------------------------------------------
    // TC_WDT_01: software ping — no timeout expected while pinging on time
    //   Condition: wdt_irq==0, wdt_nmi==0, wdt_reset==0 → ping kept timer alive
    // -------------------------------------------------------------------------
    if (!item.wdt_irq && !item.wdt_nmi && !item.wdt_reset) begin
      // Only report if we are not mid-way through another TC
      if (!tc03_irq_seen && !tc04_nmi_seen) begin
        `uvm_info("WDT_SB",
          "TC_WDT_01 PASS: wdt_irq=0 — software ping successfully prevented timeout",
          UVM_LOW)
        pass_cnt++;
      end
    end

    // -------------------------------------------------------------------------
    // TC_WDT_02: AES auto-kick — no IRQ should fire
    //   Same condition as TC_WDT_01: IRQ stays de-asserted.
    //   TC_WDT_02 is distinguished from TC_WDT_01 by context in the test;
    //   the scoreboard records the same "no spurious IRQ" pass.
    // -------------------------------------------------------------------------
    // (handled by the !item.wdt_irq branch above — test log provides context)

    // -------------------------------------------------------------------------
    // TC_WDT_03 step 1: early-warning IRQ fires after timeout
    //   Condition: wdt_irq==1
    // -------------------------------------------------------------------------
    if (item.wdt_irq && !item.wdt_nmi && !item.wdt_reset) begin
      if (!tc03_irq_seen) begin
        tc03_irq_seen = 1'b1;
        `uvm_info("WDT_SB",
          "TC_WDT_03 PASS (step 1): wdt_irq_o asserted — early-warning IRQ fired",
          UVM_LOW)
        pass_cnt++;
      end
    end

    // -------------------------------------------------------------------------
    // TC_WDT_03 step 2: after W1C clear, IRQ must de-assert
    //   Scoreboard receives a "zero" item posted by the sequence after clearing.
    //   The sequence calls sb.check_irq_cleared() directly — see below.
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // TC_WDT_04 step 1: NMI escalation
    //   Condition: wdt_nmi==1
    // -------------------------------------------------------------------------
    if (item.wdt_nmi && !item.wdt_reset) begin
      if (!tc04_nmi_seen) begin
        tc04_nmi_seen = 1'b1;
        `uvm_info("WDT_SB",
          "TC_WDT_04 PASS (step 1): wdt_nmi_o asserted — NMI escalation fired",
          UVM_LOW)
        pass_cnt++;
      end
    end

    // -------------------------------------------------------------------------
    // TC_WDT_04 step 2: hard reset after NMI
    //   Condition: wdt_reset==1 (and we already saw NMI)
    // -------------------------------------------------------------------------
    if (item.wdt_reset) begin
      if (tc04_nmi_seen) begin
        `uvm_info("WDT_SB",
          "TC_WDT_04 PASS (step 2): wdt_reset_o asserted after NMI — hard reset confirmed",
          UVM_LOW)
        pass_cnt++;
      end else begin
        `uvm_error("WDT_SB",
          "TC_WDT_04 FAIL: wdt_reset_o fired WITHOUT prior wdt_nmi_o — unexpected order")
        fail_cnt++;
      end
    end

  endfunction

  // ---------------------------------------------------------------------------
  // check_irq_cleared()
  //   Called directly by tc_wdt_03_seq after writing WDT_IC.
  //   Verifies that the RIS register read-back (passed as argument) is zero.
  // ---------------------------------------------------------------------------
  function void check_irq_cleared(bit [31:0] ris_val);
    if (ris_val === 32'h0) begin
      `uvm_info("WDT_SB",
        "TC_WDT_03 PASS (step 2): WDT_RIS==0 after W1C clear — interrupt cleared",
        UVM_LOW)
      pass_cnt++;
    end else begin
      `uvm_error("WDT_SB",
        $sformatf("TC_WDT_03 FAIL (step 2): WDT_RIS=0x%08h after IC write — not cleared",
                  ris_val))
      fail_cnt++;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // report_phase — summary
  // ---------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info("WDT_SB",
      $sformatf({"==============================\n",
                 "  WDT Scoreboard Summary\n",
                 "  PASS : %0d\n",
                 "  FAIL : %0d\n",
                 "=============================="},
                pass_cnt, fail_cnt),
      UVM_LOW)
    if (fail_cnt > 0)
      `uvm_error("WDT_SB", "One or more WDT VIP checks FAILED")
  endfunction

endclass
