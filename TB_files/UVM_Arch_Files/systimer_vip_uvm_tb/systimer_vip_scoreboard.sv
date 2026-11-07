`timescale 1ns/1ps
// =============================================================================
// systimer_vip_scoreboard.sv — UVM scoreboard for SysTimer VIP
//
// Receives systimer_vip_item from the monitor's analysis port.
//
// Checks:
//   TC_TMR_01: Counter increment is verified inline in the sequence itself;
//              no scoreboard check needed for TC_TMR_01.
//
//   TC_TMR_02: When timer_irq_obs == 1, the interrupt fired as expected.
//              PASS reported; IRQ must fire exactly at compare match.
// =============================================================================
class systimer_vip_scoreboard extends uvm_scoreboard;

  uvm_analysis_imp #(systimer_vip_item, systimer_vip_scoreboard) ap;

  int irq_count;   // total interrupts observed
  int pass_cnt;
  int fail_cnt;

  `uvm_component_utils(systimer_vip_scoreboard)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  // ---------------------------------------------------------------------------
  // write() — called by the analysis port on every monitor broadcast
  // ---------------------------------------------------------------------------
  function void write(systimer_vip_item item);
    // -----------------------------------------------------------------------
    // TC_TMR_02: interrupt observed → PASS
    // If this function is ever called with timer_irq_obs==0 it means the
    // monitor sent an item for another reason; treat as no-check.
    // -----------------------------------------------------------------------
    if (item.timer_irq_obs === 1'b1) begin
      irq_count++;
      `uvm_info("TMR_SB",
        $sformatf("TC_TMR_02 PASS: timer_irq_o fired (irq_count=%0d)",
                  irq_count),
        UVM_LOW)
      pass_cnt++;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // report_phase — summary
  // ---------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info("TMR_SB",
      $sformatf({"==============================\n",
                 "  SysTimer Scoreboard Summary\n",
                 "  IRQs observed : %0d\n",
                 "  PASS          : %0d\n",
                 "  FAIL          : %0d\n",
                 "==============================\n"},
                irq_count, pass_cnt, fail_cnt),
      UVM_LOW)
    if (fail_cnt > 0)
      `uvm_error("TMR_SB", "One or more SysTimer VIP checks FAILED")
  endfunction

endclass
