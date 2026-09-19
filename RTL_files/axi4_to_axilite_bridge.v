// =============================================================================
// Module  : axi4_to_axilite_bridge
// Purpose : Converts an AXI4 master port (from the interconnect) to an
//           AXI4-Lite slave interface (consumed by axi_uart_top).
//
// Key assumptions:
//   - The upstream interconnect always issues single-beat bursts (AWLEN=0 /
//     ARLEN=0) when targeting a Lite-only peripheral.  This is the standard
//     Xilinx/ARM behaviour when the M_REGIONS address map points to a
//     Lite device.
//   - WLAST is expected to be 1 on the only data beat.
//   - axi_uart_top does NOT expose AWLEN/ARLEN/WLAST signals – those are
//     silently dropped here; only valid/ready handshakes are forwarded.
//
// Data / address widths must match both sides (32-bit data, 5-bit address as
// required by the UART IP).
//
// Parameterisation allows reuse with different slaves.
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi4_to_axilite_bridge #(
    parameter DATA_WIDTH  = 32,
    parameter ADDR_WIDTH  = 32,   // interconnect side address width
    parameter ID_WIDTH    = 8,
    parameter STRB_WIDTH  = DATA_WIDTH/8
)(
    input  wire                    clk,
    input  wire                    rst_n,   // active-low synchronous reset

    // -------------------------------------------------------------------
    // AXI4 slave port  (connects to one master port of the interconnect)
    // -------------------------------------------------------------------

    // Write address channel
    input  wire [ID_WIDTH-1:0]    s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,   // burst length – must be 0
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire                   s_axi_awlock,
    input  wire [3:0]             s_axi_awcache,
    input  wire [2:0]             s_axi_awprot,
    input  wire [3:0]             s_axi_awqos,
    input  wire [3:0]             s_axi_awregion,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,

    // Write data channel
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axi_wstrb,
    input  wire                   s_axi_wlast,   // ignored (must be 1)
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,

    // Write response channel
    output wire [ID_WIDTH-1:0]    s_axi_bid,
    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,

    // Read address channel
    input  wire [ID_WIDTH-1:0]    s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,   // burst length – must be 0
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire                   s_axi_arlock,
    input  wire [3:0]             s_axi_arcache,
    input  wire [2:0]             s_axi_arprot,
    input  wire [3:0]             s_axi_arqos,
    input  wire [3:0]             s_axi_arregion,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,

    // Read data channel
    output wire [ID_WIDTH-1:0]    s_axi_rid,
    output wire [DATA_WIDTH-1:0]  s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rlast,   // always 1 for single beat
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready,

    // -------------------------------------------------------------------
    // AXI4-Lite master port  (connects to axi_uart_top slave port)
    // The UART slave only exposes a 5-bit address bus.
    // We slice the lower AXI_UART_ADDR_WIDTH bits.
    // -------------------------------------------------------------------

    output wire [11:0]            m_axi_awid,
    output wire [4:0]             m_axi_awaddr,  // 5-bit AXI4-Lite address
    output wire                   m_axi_awvalid,
    input  wire                   m_axi_awready,

    output wire [DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                   m_axi_wvalid,
    input  wire                   m_axi_wready,

    input  wire [11:0]            m_axi_bid,
    input  wire [1:0]             m_axi_bresp,
    input  wire                   m_axi_bvalid,
    output wire                   m_axi_bready,

    output wire [11:0]            m_axi_arid,
    output wire [4:0]             m_axi_araddr,  // 5-bit AXI4-Lite address
    output wire                   m_axi_arvalid,
    input  wire                   m_axi_arready,

    input  wire [11:0]            m_axi_rid,
    input  wire [DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]             m_axi_rresp,
    input  wire                   m_axi_rvalid,
    output wire                   m_axi_rready
);

  // -------------------------------------------------------------------------
  // ID latching
  // We must return the same AW-ID on B channel and AR-ID on R channel.
  // Store the ID when the address is accepted.
  // -------------------------------------------------------------------------

  reg [ID_WIDTH-1:0] wr_id_q;
  reg [ID_WIDTH-1:0] rd_id_q;

  // Track whether we currently hold an in-flight write / read
  reg wr_id_valid;
  reg rd_id_valid;

  // Write address accepted
  wire aw_handshake = s_axi_awvalid & s_axi_awready;
  // Write response consumed
  wire b_handshake  = s_axi_bvalid  & s_axi_bready;
  // Read address accepted
  wire ar_handshake = s_axi_arvalid & s_axi_arready;
  // Read data consumed
  wire r_handshake  = s_axi_rvalid  & s_axi_rready;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_id_q     <= {ID_WIDTH{1'b0}};
      wr_id_valid <= 1'b0;
    end else begin
      if (aw_handshake) begin
        wr_id_q     <= s_axi_awid;
        wr_id_valid <= 1'b1;
      end else if (b_handshake) begin
        wr_id_valid <= 1'b0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_id_q     <= {ID_WIDTH{1'b0}};
      rd_id_valid <= 1'b0;
    end else begin
      if (ar_handshake) begin
        rd_id_q     <= s_axi_arid;
        rd_id_valid <= 1'b1;
      end else if (r_handshake) begin
        rd_id_valid <= 1'b0;
      end
    end
  end

  // -------------------------------------------------------------------------
  // AXI4 → AXI4-Lite passthrough (burst signals dropped)
  // -------------------------------------------------------------------------

  // --- Write address ---
  // Forward directly; AWREADY from the Lite slave controls the handshake.
  // m_axi_awid is 12-bit (UART fixed); s_axi_awid is ID_WIDTH-bit (interconnect).
  // Zero-pad upward if ID_WIDTH < 12, or truncate to lower 12 bits if wider.
  assign m_axi_awid    = {{(12-ID_WIDTH){1'b0}}, s_axi_awid};  // pad to 12 bits
  assign m_axi_awaddr  = s_axi_awaddr[4:0];                    // lower 5 bits
  assign m_axi_awvalid = s_axi_awvalid;
  assign s_axi_awready = m_axi_awready;

  // --- Write data ---
  assign m_axi_wdata   = s_axi_wdata;
  assign m_axi_wstrb   = s_axi_wstrb;
  assign m_axi_wvalid  = s_axi_wvalid;
  assign s_axi_wready  = m_axi_wready;

  // --- Write response ---
  // Truncate 12-bit UART bid back down to ID_WIDTH for the interconnect.
  assign s_axi_bid     = m_axi_bid[ID_WIDTH-1:0];
  assign s_axi_bresp   = m_axi_bresp;
  assign s_axi_bvalid  = m_axi_bvalid;
  assign m_axi_bready  = s_axi_bready;

  // --- Read address ---
  assign m_axi_arid    = {{(12-ID_WIDTH){1'b0}}, s_axi_arid};  // pad to 12 bits
  assign m_axi_araddr  = s_axi_araddr[4:0];
  assign m_axi_arvalid = s_axi_arvalid;
  assign s_axi_arready = m_axi_arready;

  // --- Read data ---
  // RLAST is always 1 (single-beat AXI4-Lite response).
  assign s_axi_rid     = m_axi_rid[ID_WIDTH-1:0];
  assign s_axi_rdata   = m_axi_rdata;
  assign s_axi_rresp   = m_axi_rresp;
  assign s_axi_rlast   = 1'b1;
  assign s_axi_rvalid  = m_axi_rvalid;
  assign m_axi_rready  = s_axi_rready;

endmodule

`default_nettype wire
