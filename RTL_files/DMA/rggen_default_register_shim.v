// =============================================================================
// rggen_default_register_shim.v
//
// Compatibility wrapper: presents the OLD rggen port interface that csr_dma.v
// was generated against, and internally instantiates the actual
// rggen_default_register from rggen-verilog-rtl/.
//
// Old interface (csr_dma.v expects):
//   parameter REGISTER_INDEX           -- unused, absorbed here
//   output o_bit_field_valid           -- single valid for both R and W
//   output o_bit_field_read_mask       -- separate read mask
//   output o_bit_field_write_mask      -- separate write mask
//
// New interface (rggen-verilog-rtl/rggen_default_register.v has):
//   output o_bit_field_write_valid     -- write valid
//   output o_bit_field_read_valid      -- read valid
//   output o_bit_field_mask            -- unified mask
// =============================================================================
`timescale 1ns/1ps

module rggen_default_register #(
  parameter READABLE        = 1'b1,
  parameter WRITABLE        = 1'b1,
  parameter ADDRESS_WIDTH   = 8,
  parameter OFFSET_ADDRESS  = {ADDRESS_WIDTH{1'b0}},
  parameter BUS_WIDTH       = 32,
  parameter DATA_WIDTH      = BUS_WIDTH,
  parameter REGISTER_INDEX  = 0          // old rggen param — ignored
)(
  input                       i_clk,
  input                       i_rst_n,
  input                       i_register_valid,
  input   [1:0]               i_register_access,
  input   [ADDRESS_WIDTH-1:0] i_register_address,
  input   [BUS_WIDTH-1:0]     i_register_write_data,
  input   [BUS_WIDTH-1:0]     i_register_strobe,
  output                      o_register_active,
  output                      o_register_ready,
  output  [1:0]               o_register_status,
  output  [BUS_WIDTH-1:0]     o_register_read_data,
  output  [DATA_WIDTH-1:0]    o_register_value,
  // Old-style bit-field interface
  output                      o_bit_field_valid,       // = write_valid | read_valid
  output  [DATA_WIDTH-1:0]    o_bit_field_read_mask,   // = mask when read valid
  output  [DATA_WIDTH-1:0]    o_bit_field_write_mask,  // = mask when write valid
  output  [DATA_WIDTH-1:0]    o_bit_field_write_data,
  input   [DATA_WIDTH-1:0]    i_bit_field_read_data,
  input   [DATA_WIDTH-1:0]    i_bit_field_value
);

  wire w_write_valid;
  wire w_read_valid;
  wire [DATA_WIDTH-1:0] w_mask;

  // Instantiate the real primitive with new port names
  rggen_default_register_impl #(
    .READABLE       (READABLE),
    .WRITABLE       (WRITABLE),
    .ADDRESS_WIDTH  (ADDRESS_WIDTH),
    .OFFSET_ADDRESS (OFFSET_ADDRESS),
    .BUS_WIDTH      (BUS_WIDTH),
    .DATA_WIDTH     (DATA_WIDTH)
  ) u_impl (
    .i_clk                  (i_clk),
    .i_rst_n                (i_rst_n),
    .i_register_valid       (i_register_valid),
    .i_register_access      (i_register_access),
    .i_register_address     (i_register_address),
    .i_register_write_data  (i_register_write_data),
    .i_register_strobe      (i_register_strobe),
    .o_register_active      (o_register_active),
    .o_register_ready       (o_register_ready),
    .o_register_status      (o_register_status),
    .o_register_read_data   (o_register_read_data),
    .o_register_value       (o_register_value),
    .o_bit_field_write_valid(w_write_valid),
    .o_bit_field_read_valid (w_read_valid),
    .o_bit_field_mask       (w_mask),
    .o_bit_field_write_data (o_bit_field_write_data),
    .i_bit_field_read_data  (i_bit_field_read_data),
    .i_bit_field_value      (i_bit_field_value)
  );

  // Adapt old interface: valid = either R or W active
  assign o_bit_field_valid      = w_write_valid | w_read_valid;
  // When reading, expose mask on read_mask; when writing on write_mask
  assign o_bit_field_read_mask  = w_read_valid  ? w_mask : {DATA_WIDTH{1'b0}};
  assign o_bit_field_write_mask = w_write_valid ? w_mask : {DATA_WIDTH{1'b0}};

endmodule
