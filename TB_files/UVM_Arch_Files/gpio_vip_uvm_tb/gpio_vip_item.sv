`timescale 1ns/1ps
// =============================================================================
// gpio_vip_item.sv — UVM sequence item for GPIO VIP
//
// GPIO is a pin-level VIP: the CPU accesses GPIO control registers
// (GPIO_EN, GPIO_OUT, GPIO_IN, GPIO_RISE_EN, GPIO_INT_STAT) through the
// SoC interconnect.  This VIP only drives/samples the physical I/O pins.
//
// Register map (base = 0x4000_5000):
//   GPIO_EN_REG  = 0x00  — output enable per pin
//   GPIO_OUT_REG = 0x04  — output data register
//   GPIO_IN_REG  = 0x08  — input data register (read-only)
//   GPIO_RISE_EN = 0x0C  — rising-edge IRQ enable per pin
//   GPIO_INT_STAT= 0x10  — interrupt status (W1C)
// =============================================================================
class gpio_vip_item extends uvm_sequence_item;

  // -------------------------------------------------------------------------
  // AXI-Lite register access fields
  // (used when a test needs to log what address/data was written by the CPU;
  //  this VIP does not drive AXI — fields are informational / for extensions)
  // -------------------------------------------------------------------------
  rand bit        do_write;          // 1 = write transaction, 0 = read
  rand bit [31:0] addr;              // register address
  rand bit [31:0] wdata;             // write data
  bit      [31:0] rdata;             // read data captured
  bit      [1:0]  resp;              // AXI response code

  // -------------------------------------------------------------------------
  // Pin-level stimulus / observation fields
  // -------------------------------------------------------------------------
  rand bit [31:0] gpio_in_val;       // value to drive on gpio_in_i (DUT input)
  bit      [31:0] gpio_out_obs;      // observed gpio_out_o from DUT
  bit      [31:0] gpio_tx_en_obs;    // observed gpio_tx_en_o from DUT
  bit             gpio_irq_obs;      // observed gpio_irq_o from DUT

  // -------------------------------------------------------------------------
  // Constraints — keep addr within the GPIO aperture
  // -------------------------------------------------------------------------
  constraint c_gpio_addr {
    addr inside {
      32'h4000_5000,   // GPIO_EN_REG
      32'h4000_5004,   // GPIO_OUT_REG
      32'h4000_5008,   // GPIO_IN_REG  (read-only)
      32'h4000_500C,   // GPIO_RISE_EN
      32'h4000_5010    // GPIO_INT_STAT (W1C)
    };
  }

  // -------------------------------------------------------------------------
  // UVM field automation
  // -------------------------------------------------------------------------
  `uvm_object_utils_begin(gpio_vip_item)
    `uvm_field_int(do_write,       UVM_ALL_ON)
    `uvm_field_int(addr,           UVM_ALL_ON)
    `uvm_field_int(wdata,          UVM_ALL_ON)
    `uvm_field_int(rdata,          UVM_ALL_ON)
    `uvm_field_int(resp,           UVM_ALL_ON)
    `uvm_field_int(gpio_in_val,    UVM_ALL_ON)
    `uvm_field_int(gpio_out_obs,   UVM_ALL_ON)
    `uvm_field_int(gpio_tx_en_obs, UVM_ALL_ON)
    `uvm_field_int(gpio_irq_obs,   UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "gpio_vip_item");
    super.new(name);
    gpio_in_val = 32'h0;  // default: all inputs low
  endfunction

endclass
