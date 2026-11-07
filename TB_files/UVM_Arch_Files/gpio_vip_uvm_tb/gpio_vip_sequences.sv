`timescale 1ns/1ps
// =============================================================================
// gpio_vip_sequences.sv — Directed test sequences for GPIO VIP
//
// Register map (base = 0x4000_5000):
//   GPIO_EN_REG  = 0x4000_5000  — output enable (1=output, 0=input)
//   GPIO_OUT_REG = 0x4000_5004  — output data
//   GPIO_IN_REG  = 0x4000_5008  — input data (read-only)
//   GPIO_RISE_EN = 0x4000_500C  — rising-edge IRQ enable
//   GPIO_INT_STAT= 0x4000_5010  — IRQ status (W1C)
//
// NOTE: This VIP is pin-level only.  CPU register writes to configure
// GPIO_EN / GPIO_OUT / GPIO_RISE_EN are performed by the SoC testbench
// through the interconnect.  These sequences only drive gpio_in_i
// (external pin stimulus) and the scoreboard observes DUT outputs.
//
// Sequences:
//   tc_gpio_01_seq — pin direction + output drive test
//   tc_gpio_02_seq — input sampling test
//   tc_gpio_03_seq — rising-edge IRQ test
// =============================================================================

// =============================================================================
// TC_GPIO_01 — Pin direction + output drive
//
// Expected setup (done externally by CPU / SoC TB before this sequence):
//   GPIO_EN_REG  = 0xFF  (pins [7:0] configured as outputs)
//   GPIO_OUT_REG = 0xA5  (drive 0xA5 on output pins)
//
// This sequence drives gpio_in_val just to produce a triggering item;
// the scoreboard checks: gpio_out_o[7:0]==8'hA5 AND gpio_tx_en_o[7:0]==8'hFF.
//
// Step 1 — drive gpio_in_i = 32'hFF  (mimic EN mask on input side)
// Step 2 — drive gpio_in_i = 32'hA5  (mimic output data pattern on input side)
//
// In a standalone pin-level VIP simulation the DUT outputs are driven by
// the tb_top stubs; in the integrated SoC simulation the CPU writes the
// GPIO registers and the DUT drives gpio_out_o / gpio_tx_en_o accordingly.
// =============================================================================
class tc_gpio_01_seq extends uvm_sequence #(gpio_vip_item);
  `uvm_object_utils(tc_gpio_01_seq)

  function new(string name = "tc_gpio_01_seq");
    super.new(name);
  endfunction

  task body();
    gpio_vip_item item;

    // ------------------------------------------------------------------
    // Step 1: drive gpio_in_i = 32'hFF
    //   (represents the enable-mask stimulus; triggers monitor sampling)
    // ------------------------------------------------------------------
    `uvm_do_with(item, { gpio_in_val == 32'h0000_00FF; })

    // ------------------------------------------------------------------
    // Step 2: drive gpio_in_i = 32'hA5
    //   (represents the output-pattern stimulus; scoreboard checks DUT
    //    outputs gpio_out_o[7:0]==0xA5, gpio_tx_en_o[7:0]==0xFF)
    // ------------------------------------------------------------------
    `uvm_do_with(item, { gpio_in_val == 32'h0000_00A5; })

    `uvm_info("TC01_GPIO", "TC_GPIO_01 sequence complete", UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_GPIO_02 — Input sampling
//
// Drive gpio_in_i = 32'h5A5A_A5A5 and hold it steady so the DUT's
// synchroniser registers latch the value.  The monitor will see gpio_in_i
// change and broadcast an item; the scoreboard verifies the captured
// gpio_in_val == 32'h5A5A_A5A5 (i.e. the GPIO_IN_REG would read that value).
// =============================================================================
class tc_gpio_02_seq extends uvm_sequence #(gpio_vip_item);
  `uvm_object_utils(tc_gpio_02_seq)

  function new(string name = "tc_gpio_02_seq");
    super.new(name);
  endfunction

  task body();
    gpio_vip_item item;

    // Drive the 32-bit test pattern on all GPIO input pins
    `uvm_do_with(item, { gpio_in_val == 32'h5A5A_A5A5; })

    `uvm_info("TC02_GPIO",
      "TC_GPIO_02 sequence complete: 32'h5A5A_A5A5 driven on gpio_in_i",
      UVM_LOW)
  endtask

endclass

// =============================================================================
// TC_GPIO_03 — Rising-edge interrupt
//
// Expected setup (done externally by CPU / SoC TB before this sequence):
//   GPIO_RISE_EN = 0x1  (rising-edge IRQ enabled on pin 0)
//
// Step 1 — drive gpio_in_i = 32'h0  (ensure pin 0 is LOW)
// Step 2 — drive gpio_in_i[0] = 1   (32'h1 → rising edge on pin 0)
//
// The DUT should assert gpio_irq_o after detecting the 0→1 transition on
// pin 0 with RISE_EN[0] set.  The scoreboard checks gpio_irq_obs == 1.
// =============================================================================
class tc_gpio_03_seq extends uvm_sequence #(gpio_vip_item);
  `uvm_object_utils(tc_gpio_03_seq)

  function new(string name = "tc_gpio_03_seq");
    super.new(name);
  endfunction

  task body();
    gpio_vip_item item;

    // ------------------------------------------------------------------
    // Step 1: drive gpio_in_i = 32'h0  (all pins LOW — establishes '0'
    //         on pin 0 before the rising edge)
    // ------------------------------------------------------------------
    `uvm_do_with(item, { gpio_in_val == 32'h0000_0000; })

    // ------------------------------------------------------------------
    // Step 2: drive gpio_in_i[0] = 1  (32'h0000_0001)
    //         Rising edge on pin 0 → should trigger gpio_irq_o
    // ------------------------------------------------------------------
    `uvm_do_with(item, { gpio_in_val == 32'h0000_0001; })

    `uvm_info("TC03_GPIO",
      "TC_GPIO_03 sequence complete: rising edge driven on gpio_in_i[0]",
      UVM_LOW)
  endtask

endclass
