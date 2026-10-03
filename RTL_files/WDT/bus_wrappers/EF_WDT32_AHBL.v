/*
	Copyright 2025 Efabless Corp.

	Author: Efabless Corp. (ip_admin@efabless.com)

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

	    www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.

*/

/* THIS FILE IS GENERATED, DO NOT EDIT */

`timescale 1ns / 1ps
`default_nettype none

module EF_WDT32_AHBL (

    input  wire        HCLK,
    input  wire        HRESETn,
    input  wire        HWRITE,
    input  wire [31:0] HWDATA,
    input  wire [31:0] HADDR,
    input  wire [ 1:0] HTRANS,
    input  wire        HSEL,
    input  wire        HREADY,
    output wire        HREADYOUT,
    output wire [31:0] HRDATA,
    output wire        IRQ

);

  localparam timer_REG_OFFSET = 16'h0000;
  localparam load_REG_OFFSET = 16'h0004;
  localparam control_REG_OFFSET = 16'h0008;
  localparam IM_REG_OFFSET = 16'hFF00;
  localparam MIS_REG_OFFSET = 16'hFF04;
  localparam RIS_REG_OFFSET = 16'hFF08;
  localparam IC_REG_OFFSET = 16'hFF0C;

  reg [0:0] GCLK_REG;
  wire clk_g;

  wire clk_gated_en = GCLK_REG[0];
  ef_util_gating_cell clk_gate_cell (

      // USE_POWER_PINS
      .clk(HCLK),
      .clk_en(clk_gated_en),
      .clk_o(clk_g)
  );

  wire clk = clk_g;
  wire rst_n = HRESETn;

  reg last_HSEL, last_HWRITE;
  reg [31:0] last_HADDR;
  reg [ 1:0] last_HTRANS;
  always @(posedge HCLK or negedge HRESETn) begin
    if (~HRESETn) begin
      last_HSEL   <= 1'b0;
      last_HADDR  <= 1'b0;
      last_HWRITE <= 1'b0;
      last_HTRANS <= 1'b0;
    end else if (HREADY) begin
      last_HSEL   <= HSEL;
      last_HADDR  <= HADDR;
      last_HWRITE <= HWRITE;
      last_HTRANS <= HTRANS;
    end
  end
  wire    ahbl_valid = last_HSEL & last_HTRANS[1];
  wire ahbl_we = last_HWRITE & ahbl_valid;
  wire ahbl_re = ~last_HWRITE & ahbl_valid;

  wire [32-1:0] WDTMR;
  wire [32-1:0] WDTLOAD;
  wire [1-1:0] WDTTO;
  wire [1-1:0] WDTEN;

  // Register Definitions
  wire [32-1:0] timer_WIRE;
  assign timer_WIRE = WDTMR;

  reg [31:0] load_REG;
  assign WDTLOAD = load_REG;
  always @(posedge HCLK or negedge HRESETn)
    if (~HRESETn) load_REG <= 0;
    else if (ahbl_we & (last_HADDR[16-1:0] == load_REG_OFFSET)) load_REG <= HWDATA[32-1:0];

  reg [0:0] control_REG;
  assign WDTEN = control_REG;
  always @(posedge HCLK or negedge HRESETn)
    if (~HRESETn) control_REG <= 0;
    else if (ahbl_we & (last_HADDR[16-1:0] == control_REG_OFFSET)) control_REG <= HWDATA[1-1:0];

  localparam GCLK_REG_OFFSET = 16'hFF10;
  always @(posedge HCLK or negedge HRESETn)
    if (~HRESETn) GCLK_REG <= 0;
    else if (ahbl_we & (last_HADDR[16-1:0] == GCLK_REG_OFFSET)) GCLK_REG <= HWDATA[1-1:0];

  reg  [  0:0] IM_REG;
  reg  [  0:0] IC_REG;
  reg  [  0:0] RIS_REG;

  wire [1-1:0] MIS_REG = RIS_REG & IM_REG;
  always @(posedge HCLK or negedge HRESETn)
    if (~HRESETn) IM_REG <= 0;
    else if (ahbl_we & (last_HADDR[16-1:0] == IM_REG_OFFSET)) IM_REG <= HWDATA[1-1:0];
  always @(posedge HCLK or negedge HRESETn)
    if (~HRESETn) IC_REG <= 1'b0;
    else if (ahbl_we & (last_HADDR[16-1:0] == IC_REG_OFFSET)) IC_REG <= HWDATA[1-1:0];
    else IC_REG <= 1'd0;

  wire [0:0] wdtto = WDTTO;

  integer _i_;
  always @(posedge HCLK or negedge HRESETn)
    if (~HRESETn) RIS_REG <= 0;
    else begin
      for (_i_ = 0; _i_ < 1; _i_ = _i_ + 1) begin
        if (IC_REG[_i_]) RIS_REG[_i_] <= 1'b0;
        else if (wdtto[_i_-0] == 1'b1) RIS_REG[_i_] <= 1'b1;
      end
    end

  assign IRQ = |MIS_REG;

  EF_WDT32 instance_to_wrap (
      .clk(clk),
      .rst_n(rst_n),
      .WDTMR(WDTMR),
      .WDTLOAD(WDTLOAD),
      .WDTTO(WDTTO),
      .WDTEN(WDTEN)
  );

  assign	HRDATA = 
			(last_HADDR[16-1:0] == timer_REG_OFFSET)	? timer_WIRE :
			(last_HADDR[16-1:0] == load_REG_OFFSET)	? load_REG :
			(last_HADDR[16-1:0] == control_REG_OFFSET)	? control_REG :
			(last_HADDR[16-1:0] == IM_REG_OFFSET)	? IM_REG :
			(last_HADDR[16-1:0] == MIS_REG_OFFSET)	? MIS_REG :
			(last_HADDR[16-1:0] == RIS_REG_OFFSET)	? RIS_REG :
			(last_HADDR[16-1:0] == GCLK_REG_OFFSET)	? GCLK_REG :
			32'hDEADBEEF;

  assign HREADYOUT = 1'b1;

endmodule
