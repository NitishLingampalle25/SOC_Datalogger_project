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

`timescale			1ns/1ps
`default_nettype	none

`define				AHBL_AW		16

`include			"ahbl_wrapper.vh"

module EF_WDT32_AHBL (
`ifdef USE_POWER_PINS
	inout VPWR,
	inout VGND,
`endif
	`AHBL_SLAVE_PORTS
);

	localparam	timer_REG_OFFSET = `AHBL_AW'h0000;
	localparam	load_REG_OFFSET = `AHBL_AW'h0004;
	localparam	control_REG_OFFSET = `AHBL_AW'h0008;
	localparam	IM_REG_OFFSET = `AHBL_AW'hFF00;
	localparam	MIS_REG_OFFSET = `AHBL_AW'hFF04;
	localparam	RIS_REG_OFFSET = `AHBL_AW'hFF08;
	localparam	IC_REG_OFFSET = `AHBL_AW'hFF0C;

    reg [0:0] GCLK_REG;
    wire clk_g;

    wire clk_gated_en = GCLK_REG[0];
    ef_util_gating_cell clk_gate_cell(
        `ifdef USE_POWER_PINS 
        .vpwr(VPWR),
        .vgnd(VGND),
        `endif // USE_POWER_PINS
        .clk(HCLK),
        .clk_en(clk_gated_en),
        .clk_o(clk_g)
    );
    
	wire		clk = clk_g;
	wire		rst_n = HRESETn;


	`AHBL_CTRL_SIGNALS

	wire [32-1:0]	WDTMR;
	wire [32-1:0]	WDTLOAD;
	wire [1-1:0]	WDTTO;
	wire [1-1:0]	WDTEN;

	// Register Definitions
	wire [32-1:0]	timer_WIRE;
	assign	timer_WIRE = WDTMR;

	reg [31:0]	load_REG;
	assign	WDTLOAD = load_REG;
	`AHBL_REG(load_REG, 0, 32)

	reg [0:0]	control_REG;
	assign	WDTEN = control_REG;
	`AHBL_REG(control_REG, 0, 1)

	localparam	GCLK_REG_OFFSET = `AHBL_AW'hFF10;
	`AHBL_REG(GCLK_REG, 0, 1)

	reg [0:0] IM_REG;
	reg [0:0] IC_REG;
	reg [0:0] RIS_REG;

	`AHBL_MIS_REG(1)
	`AHBL_REG(IM_REG, 0, 1)
	`AHBL_IC_REG(1)

	wire [0:0] wdtto = WDTTO;


	integer _i_;
	`AHBL_BLOCK(RIS_REG, 0) else begin
		for(_i_ = 0; _i_ < 1; _i_ = _i_ + 1) begin
			if(IC_REG[_i_]) RIS_REG[_i_] <= 1'b0; else if(wdtto[_i_ - 0] == 1'b1) RIS_REG[_i_] <= 1'b1;
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
			(last_HADDR[`AHBL_AW-1:0] == timer_REG_OFFSET)	? timer_WIRE :
			(last_HADDR[`AHBL_AW-1:0] == load_REG_OFFSET)	? load_REG :
			(last_HADDR[`AHBL_AW-1:0] == control_REG_OFFSET)	? control_REG :
			(last_HADDR[`AHBL_AW-1:0] == IM_REG_OFFSET)	? IM_REG :
			(last_HADDR[`AHBL_AW-1:0] == MIS_REG_OFFSET)	? MIS_REG :
			(last_HADDR[`AHBL_AW-1:0] == RIS_REG_OFFSET)	? RIS_REG :
			(last_HADDR[`AHBL_AW-1:0] == GCLK_REG_OFFSET)	? GCLK_REG :
			32'hDEADBEEF;

	assign	HREADYOUT = 1'b1;

endmodule
