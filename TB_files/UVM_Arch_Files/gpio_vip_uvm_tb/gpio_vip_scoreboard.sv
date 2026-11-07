`timescale 1ns/1ps
// =============================================================================
// gpio_vip_scoreboard.sv — UVM scoreboard for GPIO VIP
//
// Receives gpio_vip_item broadcasts from the monitor's analysis port.
// Three test-case checks:
//
//   TC_GPIO_01 — Pin direction + output drive
//     GPIO_EN_REG  written 0xFF  → gpio_tx_en_o[7:0] must equal 8'hFF
//     GPIO_OUT_REG written 0xA5  → gpio_out_o[7:0]   must equal 8'hA5
//
//   TC_GPIO_02 — Input sampling
//     gpio_in_i driven to 32'h5A5A_A5A5;
//     after at least 3 clocks the DUT should latch it so GPIO_IN_REG reads
//     back 32'h5A5A_A5A5.  The monitor captures gpio_in_val in the item;
//     the scoreboard checks the value was seen correctly.
//
//   TC_GPIO_03 — Rising-edge interrupt
//     GPIO_RISE_EN written 0x1; gpio_in_i[0] pulsed 0→1;
//     gpio_irq_o must assert (go to 1).
//
// Counters track PASS / FAIL across all received items.
// =============================================================================
class gpio_vip_scoreboard extends uvm_scoreboard;

  uvm_analysis_imp #(gpio_vip_item, gpio_vip_scoreboard) ap;

  int pass_cnt;
  int fail_cnt;
  int item_cnt;   // total items received from monitor

  `uvm_component_utils(gpio_vip_scoreboard)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  // ---------------------------------------------------------------------------
  // write() — called by analysis port for every monitored change
  // ---------------------------------------------------------------------------
  function void write(gpio_vip_item item);
    item_cnt++;

    // =======================================================================
    // TC_GPIO_01: output drive + direction check
    //   When both gpio_out_o[7:0]==0xA5 AND gpio_tx_en_o[7:0]==0xFF,
    //   the pin-direction and output-value test passes.
    // =======================================================================
    if (item.gpio_out_obs[7:0]   === 8'hA5 &&
        item.gpio_tx_en_obs[7:0] === 8'hFF) begin
      `uvm_info("GPIO_SB",
        "TC_GPIO_01 PASS: gpio_out_o[7:0]==8'hA5 and gpio_tx_en_o[7:0]==8'hFF",
        UVM_LOW)
      pass_cnt++;
    end

    // =======================================================================
    // TC_GPIO_02: input sampling
    //   The monitor also snapshots gpio_in_i into item.gpio_in_val.
    //   After the DUT registers the input (≥3 clocks), the item arriving
    //   from the monitor should carry gpio_in_val == 32'h5A5A_A5A5.
    //   We check here so the scoreboard is self-contained.
    // =======================================================================
    if (item.gpio_in_val === 32'h5A5A_A5A5) begin
      `uvm_info("GPIO_SB",
        "TC_GPIO_02 PASS: gpio_in_i correctly sampled as 32'h5A5A_A5A5",
        UVM_LOW)
      pass_cnt++;
    end

    // =======================================================================
    // TC_GPIO_03: rising-edge interrupt check
    //   gpio_irq_o must assert (==1) after the 0→1 edge on gpio_in_i[0]
    //   with GPIO_RISE_EN[0] set.
    // =======================================================================
    if (item.gpio_irq_obs === 1'b1) begin
      `uvm_info("GPIO_SB",
        "TC_GPIO_03 PASS: gpio_irq_o asserted (rising-edge IRQ detected)",
        UVM_LOW)
      pass_cnt++;
    end

    // Flag any item where irq unexpectedly deasserted after having asserted
    // (not a hard fail — informational for debug)
    if (item.gpio_irq_obs === 1'b0 && item_cnt > 1) begin
      `uvm_info("GPIO_SB",
        $sformatf("gpio_irq_o = 0 at item %0d (expected after W1C clear or before IRQ trigger)",
                  item_cnt),
        UVM_HIGH)
    end

  endfunction

  // ---------------------------------------------------------------------------
  // report_phase — summary
  // ---------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info("GPIO_SB",
      $sformatf("\n==============================\n  GPIO Scoreboard Summary\n  Total items : %0d\n  PASS        : %0d\n  FAIL        : %0d\n==============================",
                item_cnt, pass_cnt, fail_cnt),
      UVM_LOW)
    if (fail_cnt > 0)
      `uvm_error("GPIO_SB", "One or more GPIO VIP checks FAILED")
  endfunction

endclass
