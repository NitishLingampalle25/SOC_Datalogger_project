// =============================================================================
// Module  : axi_interconnect_uart_top
// File    : RTL_files/axi_interconnect_uart_top.v
//
// Purpose : Top-level integration of:
//             1. AXI4 2x6 Interconnect  (axi_interconnect_wrap_2x6)
//             2. AXI4→AXI4-Lite Bridge  (axi4_to_axilite_bridge)     [m00]
//             3. AXI4-Lite UART IP Core (axi_uart_top)
//
// Topology:
//
//   ┌────────────────────────────────────────────────────────────────┐
//   │  [s00 / s01]                                                   │
//   │   upstream AXI4 masters (CPU / DMA / testbench)                │
//   │                                                                │
//   │              axi_interconnect_wrap_2x6 (2 masters × 6 slaves) │
//   │                                                                │
//   │   [m00] ──→ axi4_to_axilite_bridge ──→ axi_uart_top (UART)   │
//   │   [m01..m05] ──→ (unused – tied to default slave / open)      │
//   └────────────────────────────────────────────────────────────────┘
//
// Address map (M00):
//   UART base address : UART_BASE_ADDR
//   Address bits      : 5  (32 bytes; covers RBR/THR, IER, BAUD, LCR, LSR)
//
// Parameters:
//   DATA_WIDTH  – AXI data bus width     (32)
//   ADDR_WIDTH  – AXI address bus width  (32)
//   IC_ID_WIDTH – Interconnect ID width  (8)
//   UART_BASE   – UART base address in the system address map
//
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_interconnect_uart_top #(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 32,
    parameter IC_ID_WIDTH  = 8,         // interconnect ID width
    parameter UART_ID_W    = 12,        // UART IP fixed ID width
    parameter STRB_WIDTH   = DATA_WIDTH / 8,
    // UART base address in the interconnect address map.
    // The interconnect will route any access in [UART_BASE, UART_BASE+32) → m00.
    parameter [ADDR_WIDTH-1:0] UART_BASE_ADDR  = 32'h4000_0000,
    // Upstream (unused) master-port addresses – tied to a harmless base.
    // We keep the other 5 interconnect master ports at the same base with
    // the same width; they are not wired to any slave and will SLVERR.
    // In a real system replace these with actual peripheral addresses.
    parameter [ADDR_WIDTH-1:0] M01_BASE = 32'h4000_1000,
    parameter [ADDR_WIDTH-1:0] M02_BASE = 32'h4000_2000,
    parameter [ADDR_WIDTH-1:0] M03_BASE = 32'h4000_3000,
    parameter [ADDR_WIDTH-1:0] M04_BASE = 32'h4000_4000,
    parameter [ADDR_WIDTH-1:0] M05_BASE = 32'h4000_5000
)(
    // -------------------------------------------------------------------
    // Global signals
    // -------------------------------------------------------------------
    input  wire                    clk,       // system / AXI clock
    input  wire                    rst_n,     // active-low synchronous reset
    // The UART IP has a second fixed clock domain for its baud-rate generator.
    // Connect this to the same system clock (or a separate fixed clock if
    // baud accuracy is critical in hardware).
    input  wire                    fixed_clk,

    // -------------------------------------------------------------------
    // AXI4 slave port 0  (s00) – primary upstream master
    // -------------------------------------------------------------------
    input  wire [IC_ID_WIDTH-1:0]  s00_axi_awid,
    input  wire [ADDR_WIDTH-1:0]   s00_axi_awaddr,
    input  wire [7:0]              s00_axi_awlen,
    input  wire [2:0]              s00_axi_awsize,
    input  wire [1:0]              s00_axi_awburst,
    input  wire                    s00_axi_awlock,
    input  wire [3:0]              s00_axi_awcache,
    input  wire [2:0]              s00_axi_awprot,
    input  wire [3:0]              s00_axi_awqos,
    input  wire                    s00_axi_awvalid,
    output wire                    s00_axi_awready,

    input  wire [DATA_WIDTH-1:0]   s00_axi_wdata,
    input  wire [STRB_WIDTH-1:0]   s00_axi_wstrb,
    input  wire                    s00_axi_wlast,
    input  wire                    s00_axi_wvalid,
    output wire                    s00_axi_wready,

    output wire [IC_ID_WIDTH-1:0]  s00_axi_bid,
    output wire [1:0]              s00_axi_bresp,
    output wire                    s00_axi_bvalid,
    input  wire                    s00_axi_bready,

    input  wire [IC_ID_WIDTH-1:0]  s00_axi_arid,
    input  wire [ADDR_WIDTH-1:0]   s00_axi_araddr,
    input  wire [7:0]              s00_axi_arlen,
    input  wire [2:0]              s00_axi_arsize,
    input  wire [1:0]              s00_axi_arburst,
    input  wire                    s00_axi_arlock,
    input  wire [3:0]              s00_axi_arcache,
    input  wire [2:0]              s00_axi_arprot,
    input  wire [3:0]              s00_axi_arqos,
    input  wire                    s00_axi_arvalid,
    output wire                    s00_axi_arready,

    output wire [IC_ID_WIDTH-1:0]  s00_axi_rid,
    output wire [DATA_WIDTH-1:0]   s00_axi_rdata,
    output wire [1:0]              s00_axi_rresp,
    output wire                    s00_axi_rlast,
    output wire                    s00_axi_rvalid,
    input  wire                    s00_axi_rready,

    // -------------------------------------------------------------------
    // AXI4 slave port 1  (s01) – secondary upstream master
    // -------------------------------------------------------------------
    input  wire [IC_ID_WIDTH-1:0]  s01_axi_awid,
    input  wire [ADDR_WIDTH-1:0]   s01_axi_awaddr,
    input  wire [7:0]              s01_axi_awlen,
    input  wire [2:0]              s01_axi_awsize,
    input  wire [1:0]              s01_axi_awburst,
    input  wire                    s01_axi_awlock,
    input  wire [3:0]              s01_axi_awcache,
    input  wire [2:0]              s01_axi_awprot,
    input  wire [3:0]              s01_axi_awqos,
    input  wire                    s01_axi_awvalid,
    output wire                    s01_axi_awready,

    input  wire [DATA_WIDTH-1:0]   s01_axi_wdata,
    input  wire [STRB_WIDTH-1:0]   s01_axi_wstrb,
    input  wire                    s01_axi_wlast,
    input  wire                    s01_axi_wvalid,
    output wire                    s01_axi_wready,

    output wire [IC_ID_WIDTH-1:0]  s01_axi_bid,
    output wire [1:0]              s01_axi_bresp,
    output wire                    s01_axi_bvalid,
    input  wire                    s01_axi_bready,

    input  wire [IC_ID_WIDTH-1:0]  s01_axi_arid,
    input  wire [ADDR_WIDTH-1:0]   s01_axi_araddr,
    input  wire [7:0]              s01_axi_arlen,
    input  wire [2:0]              s01_axi_arsize,
    input  wire [1:0]              s01_axi_arburst,
    input  wire                    s01_axi_arlock,
    input  wire [3:0]              s01_axi_arcache,
    input  wire [2:0]              s01_axi_arprot,
    input  wire [3:0]              s01_axi_arqos,
    input  wire                    s01_axi_arvalid,
    output wire                    s01_axi_arready,

    output wire [IC_ID_WIDTH-1:0]  s01_axi_rid,
    output wire [DATA_WIDTH-1:0]   s01_axi_rdata,
    output wire [1:0]              s01_axi_rresp,
    output wire                    s01_axi_rlast,
    output wire                    s01_axi_rvalid,
    input  wire                    s01_axi_rready,

    // -------------------------------------------------------------------
    // UART physical signals
    // -------------------------------------------------------------------
    output wire                    uart_tx_o,
    input  wire                    uart_rx_i,
    output wire                    uart_read_irq_o     // RX data-ready interrupt
);

  // =========================================================================
  // Internal wires: Interconnect m00 master port ↔ bridge slave port
  // =========================================================================

  wire [IC_ID_WIDTH-1:0]  m00_awid;
  wire [ADDR_WIDTH-1:0]   m00_awaddr;
  wire [7:0]              m00_awlen;
  wire [2:0]              m00_awsize;
  wire [1:0]              m00_awburst;
  wire                    m00_awlock;
  wire [3:0]              m00_awcache;
  wire [2:0]              m00_awprot;
  wire [3:0]              m00_awqos;
  wire [3:0]              m00_awregion;
  wire                    m00_awvalid;
  wire                    m00_awready;

  wire [DATA_WIDTH-1:0]   m00_wdata;
  wire [STRB_WIDTH-1:0]   m00_wstrb;
  wire                    m00_wlast;
  wire                    m00_wvalid;
  wire                    m00_wready;

  wire [IC_ID_WIDTH-1:0]  m00_bid;
  wire [1:0]              m00_bresp;
  wire                    m00_bvalid;
  wire                    m00_bready;

  wire [IC_ID_WIDTH-1:0]  m00_arid;
  wire [ADDR_WIDTH-1:0]   m00_araddr;
  wire [7:0]              m00_arlen;
  wire [2:0]              m00_arsize;
  wire [1:0]              m00_arburst;
  wire                    m00_arlock;
  wire [3:0]              m00_arcache;
  wire [2:0]              m00_arprot;
  wire [3:0]              m00_arqos;
  wire [3:0]              m00_arregion;
  wire                    m00_arvalid;
  wire                    m00_arready;

  wire [IC_ID_WIDTH-1:0]  m00_rid;
  wire [DATA_WIDTH-1:0]   m00_rdata;
  wire [1:0]              m00_rresp;
  wire                    m00_rlast;
  wire                    m00_rvalid;
  wire                    m00_rready;

  // =========================================================================
  // Internal wires: bridge master port ↔ UART slave port
  // =========================================================================

  wire [UART_ID_W-1:0]   uart_awid;
  wire [4:0]             uart_awaddr;
  wire                   uart_awvalid;
  wire                   uart_awready;

  wire [DATA_WIDTH-1:0]  uart_wdata;
  wire [STRB_WIDTH-1:0]  uart_wstrb;
  wire                   uart_wvalid;
  wire                   uart_wready;

  wire [UART_ID_W-1:0]   uart_bid;
  wire [1:0]             uart_bresp;
  wire                   uart_bvalid;
  wire                   uart_bready;

  wire [UART_ID_W-1:0]   uart_arid;
  wire [4:0]             uart_araddr;
  wire                   uart_arvalid;
  wire                   uart_arready;

  wire [UART_ID_W-1:0]   uart_rid;
  wire [DATA_WIDTH-1:0]  uart_rdata;
  wire [1:0]             uart_rresp;
  wire                   uart_rvalid;
  wire                   uart_rready;

  // =========================================================================
  // Tie-off unused interconnect master ports (m01–m05) to default slave.
  // All ready signals are asserted; no valid data is ever generated so the
  // interconnect will simply receive SLVERR/DECERR for out-of-map accesses.
  // In a real design, replace with actual peripheral bridges.
  // =========================================================================

  // The interconnect rst port is active-high.
  wire rst_ic = ~rst_n;

  // =========================================================================
  // Instantiation 1: AXI4 2x6 Interconnect
  // =========================================================================

  axi_interconnect_wrap_2x6 #(
      .DATA_WIDTH           (DATA_WIDTH),
      .ADDR_WIDTH           (ADDR_WIDTH),
      .ID_WIDTH             (IC_ID_WIDTH),
      // --- Address map ---
      // m00 = UART  (12-bit aperture = 4 KB minimum required by interconnect)
      // The UART only uses the lower 5 bits internally; the extra address bits
      // are decoded by the interconnect and ignored inside axi_uart_top.
      .M00_BASE_ADDR        (UART_BASE_ADDR),
      .M00_ADDR_WIDTH       (32'd12),
      .M00_CONNECT_READ     (2'b11),   // both s00 & s01 can read  UART
      .M00_CONNECT_WRITE    (2'b11),   // both s00 & s01 can write UART
      // m01..m05 – placeholder addresses (not connected to real slaves)
      .M01_BASE_ADDR        (M01_BASE),
      .M01_ADDR_WIDTH       (32'd12),
      .M01_CONNECT_READ     (2'b11),
      .M01_CONNECT_WRITE    (2'b11),
      .M02_BASE_ADDR        (M02_BASE),
      .M02_ADDR_WIDTH       (32'd12),
      .M02_CONNECT_READ     (2'b11),
      .M02_CONNECT_WRITE    (2'b11),
      .M03_BASE_ADDR        (M03_BASE),
      .M03_ADDR_WIDTH       (32'd12),
      .M03_CONNECT_READ     (2'b11),
      .M03_CONNECT_WRITE    (2'b11),
      .M04_BASE_ADDR        (M04_BASE),
      .M04_ADDR_WIDTH       (32'd12),
      .M04_CONNECT_READ     (2'b11),
      .M04_CONNECT_WRITE    (2'b11),
      .M05_BASE_ADDR        (M05_BASE),
      .M05_ADDR_WIDTH       (32'd12),
      .M05_CONNECT_READ     (2'b11),
      .M05_CONNECT_WRITE    (2'b11)
  ) u_interconnect (
      .clk                  (clk),
      .rst                  (rst_ic),

      // ---- s00 slave port (primary master) ----
      .s00_axi_awid         (s00_axi_awid),
      .s00_axi_awaddr       (s00_axi_awaddr),
      .s00_axi_awlen        (s00_axi_awlen),
      .s00_axi_awsize       (s00_axi_awsize),
      .s00_axi_awburst      (s00_axi_awburst),
      .s00_axi_awlock       (s00_axi_awlock),
      .s00_axi_awcache      (s00_axi_awcache),
      .s00_axi_awprot       (s00_axi_awprot),
      .s00_axi_awqos        (s00_axi_awqos),
      .s00_axi_awuser       (1'b0),
      .s00_axi_awvalid      (s00_axi_awvalid),
      .s00_axi_awready      (s00_axi_awready),

      .s00_axi_wdata        (s00_axi_wdata),
      .s00_axi_wstrb        (s00_axi_wstrb),
      .s00_axi_wlast        (s00_axi_wlast),
      .s00_axi_wuser        (1'b0),
      .s00_axi_wvalid       (s00_axi_wvalid),
      .s00_axi_wready       (s00_axi_wready),

      .s00_axi_bid          (s00_axi_bid),
      .s00_axi_bresp        (s00_axi_bresp),
      .s00_axi_buser        (),
      .s00_axi_bvalid       (s00_axi_bvalid),
      .s00_axi_bready       (s00_axi_bready),

      .s00_axi_arid         (s00_axi_arid),
      .s00_axi_araddr       (s00_axi_araddr),
      .s00_axi_arlen        (s00_axi_arlen),
      .s00_axi_arsize       (s00_axi_arsize),
      .s00_axi_arburst      (s00_axi_arburst),
      .s00_axi_arlock       (s00_axi_arlock),
      .s00_axi_arcache      (s00_axi_arcache),
      .s00_axi_arprot       (s00_axi_arprot),
      .s00_axi_arqos        (s00_axi_arqos),
      .s00_axi_aruser       (1'b0),
      .s00_axi_arvalid      (s00_axi_arvalid),
      .s00_axi_arready      (s00_axi_arready),

      .s00_axi_rid          (s00_axi_rid),
      .s00_axi_rdata        (s00_axi_rdata),
      .s00_axi_rresp        (s00_axi_rresp),
      .s00_axi_rlast        (s00_axi_rlast),
      .s00_axi_ruser        (),
      .s00_axi_rvalid       (s00_axi_rvalid),
      .s00_axi_rready       (s00_axi_rready),

      // ---- s01 slave port (secondary master) ----
      .s01_axi_awid         (s01_axi_awid),
      .s01_axi_awaddr       (s01_axi_awaddr),
      .s01_axi_awlen        (s01_axi_awlen),
      .s01_axi_awsize       (s01_axi_awsize),
      .s01_axi_awburst      (s01_axi_awburst),
      .s01_axi_awlock       (s01_axi_awlock),
      .s01_axi_awcache      (s01_axi_awcache),
      .s01_axi_awprot       (s01_axi_awprot),
      .s01_axi_awqos        (s01_axi_awqos),
      .s01_axi_awuser       (1'b0),
      .s01_axi_awvalid      (s01_axi_awvalid),
      .s01_axi_awready      (s01_axi_awready),

      .s01_axi_wdata        (s01_axi_wdata),
      .s01_axi_wstrb        (s01_axi_wstrb),
      .s01_axi_wlast        (s01_axi_wlast),
      .s01_axi_wuser        (1'b0),
      .s01_axi_wvalid       (s01_axi_wvalid),
      .s01_axi_wready       (s01_axi_wready),

      .s01_axi_bid          (s01_axi_bid),
      .s01_axi_bresp        (s01_axi_bresp),
      .s01_axi_buser        (),
      .s01_axi_bvalid       (s01_axi_bvalid),
      .s01_axi_bready       (s01_axi_bready),

      .s01_axi_arid         (s01_axi_arid),
      .s01_axi_araddr       (s01_axi_araddr),
      .s01_axi_arlen        (s01_axi_arlen),
      .s01_axi_arsize       (s01_axi_arsize),
      .s01_axi_arburst      (s01_axi_arburst),
      .s01_axi_arlock       (s01_axi_arlock),
      .s01_axi_arcache      (s01_axi_arcache),
      .s01_axi_arprot       (s01_axi_arprot),
      .s01_axi_arqos        (s01_axi_arqos),
      .s01_axi_aruser       (1'b0),
      .s01_axi_arvalid      (s01_axi_arvalid),
      .s01_axi_arready      (s01_axi_arready),

      .s01_axi_rid          (s01_axi_rid),
      .s01_axi_rdata        (s01_axi_rdata),
      .s01_axi_rresp        (s01_axi_rresp),
      .s01_axi_rlast        (s01_axi_rlast),
      .s01_axi_ruser        (),
      .s01_axi_rvalid       (s01_axi_rvalid),
      .s01_axi_rready       (s01_axi_rready),

      // ---- m00 master port → bridge ----
      .m00_axi_awid         (m00_awid),
      .m00_axi_awaddr       (m00_awaddr),
      .m00_axi_awlen        (m00_awlen),
      .m00_axi_awsize       (m00_awsize),
      .m00_axi_awburst      (m00_awburst),
      .m00_axi_awlock       (m00_awlock),
      .m00_axi_awcache      (m00_awcache),
      .m00_axi_awprot       (m00_awprot),
      .m00_axi_awqos        (m00_awqos),
      .m00_axi_awregion     (m00_awregion),
      .m00_axi_awuser       (),
      .m00_axi_awvalid      (m00_awvalid),
      .m00_axi_awready      (m00_awready),

      .m00_axi_wdata        (m00_wdata),
      .m00_axi_wstrb        (m00_wstrb),
      .m00_axi_wlast        (m00_wlast),
      .m00_axi_wuser        (),
      .m00_axi_wvalid       (m00_wvalid),
      .m00_axi_wready       (m00_wready),

      .m00_axi_bid          (m00_bid),
      .m00_axi_bresp        (m00_bresp),
      .m00_axi_buser        (1'b0),
      .m00_axi_bvalid       (m00_bvalid),
      .m00_axi_bready       (m00_bready),

      .m00_axi_arid         (m00_arid),
      .m00_axi_araddr       (m00_araddr),
      .m00_axi_arlen        (m00_arlen),
      .m00_axi_arsize       (m00_arsize),
      .m00_axi_arburst      (m00_arburst),
      .m00_axi_arlock       (m00_arlock),
      .m00_axi_arcache      (m00_arcache),
      .m00_axi_arprot       (m00_arprot),
      .m00_axi_arqos        (m00_arqos),
      .m00_axi_arregion     (m00_arregion),
      .m00_axi_aruser       (),
      .m00_axi_arvalid      (m00_arvalid),
      .m00_axi_arready      (m00_arready),

      .m00_axi_rid          (m00_rid),
      .m00_axi_rdata        (m00_rdata),
      .m00_axi_rresp        (m00_rresp),
      .m00_axi_rlast        (m00_rlast),
      .m00_axi_ruser        (1'b0),
      .m00_axi_rvalid       (m00_rvalid),
      .m00_axi_rready       (m00_rready),

      // ---- m01..m05 – unused (outputs left open, inputs tied off) ----
      // Output ports (interconnect drives these; we discard them)
      .m01_axi_awid         (),
      .m01_axi_awaddr       (),
      .m01_axi_awlen        (),
      .m01_axi_awsize       (),
      .m01_axi_awburst      (),
      .m01_axi_awlock       (),
      .m01_axi_awcache      (),
      .m01_axi_awprot       (),
      .m01_axi_awqos        (),
      .m01_axi_awregion     (),
      .m01_axi_awuser       (),
      .m01_axi_awvalid      (),
      .m01_axi_wdata        (),
      .m01_axi_wstrb        (),
      .m01_axi_wlast        (),
      .m01_axi_wuser        (),
      .m01_axi_wvalid       (),
      .m01_axi_bready       (),
      .m01_axi_arid         (),
      .m01_axi_araddr       (),
      .m01_axi_arlen        (),
      .m01_axi_arsize       (),
      .m01_axi_arburst      (),
      .m01_axi_arlock       (),
      .m01_axi_arcache      (),
      .m01_axi_arprot       (),
      .m01_axi_arqos        (),
      .m01_axi_arregion     (),
      .m01_axi_aruser       (),
      .m01_axi_arvalid      (),
      .m01_axi_rready       (),
      // Input ports (interconnect reads these; tie to safe defaults)
      .m01_axi_awready      (1'b1),
      .m01_axi_wready       (1'b1),
      .m01_axi_bid          ({IC_ID_WIDTH{1'b0}}),
      .m01_axi_bresp        (2'b00),
      .m01_axi_buser        (1'b0),
      .m01_axi_bvalid       (1'b0),
      .m01_axi_arready      (1'b1),
      .m01_axi_rid          ({IC_ID_WIDTH{1'b0}}),
      .m01_axi_rdata        ({DATA_WIDTH{1'b0}}),
      .m01_axi_rresp        (2'b00),
      .m01_axi_rlast        (1'b1),
      .m01_axi_ruser        (1'b0),
      .m01_axi_rvalid       (1'b0),

      .m02_axi_awid         (),
      .m02_axi_awaddr       (),
      .m02_axi_awlen        (),
      .m02_axi_awsize       (),
      .m02_axi_awburst      (),
      .m02_axi_awlock       (),
      .m02_axi_awcache      (),
      .m02_axi_awprot       (),
      .m02_axi_awqos        (),
      .m02_axi_awregion     (),
      .m02_axi_awuser       (),
      .m02_axi_awvalid      (),
      .m02_axi_wdata        (),
      .m02_axi_wstrb        (),
      .m02_axi_wlast        (),
      .m02_axi_wuser        (),
      .m02_axi_wvalid       (),
      .m02_axi_bready       (),
      .m02_axi_arid         (),
      .m02_axi_araddr       (),
      .m02_axi_arlen        (),
      .m02_axi_arsize       (),
      .m02_axi_arburst      (),
      .m02_axi_arlock       (),
      .m02_axi_arcache      (),
      .m02_axi_arprot       (),
      .m02_axi_arqos        (),
      .m02_axi_arregion     (),
      .m02_axi_aruser       (),
      .m02_axi_arvalid      (),
      .m02_axi_rready       (),
      .m02_axi_awready      (1'b1),
      .m02_axi_wready       (1'b1),
      .m02_axi_bid          ({IC_ID_WIDTH{1'b0}}),
      .m02_axi_bresp        (2'b00),
      .m02_axi_buser        (1'b0),
      .m02_axi_bvalid       (1'b0),
      .m02_axi_arready      (1'b1),
      .m02_axi_rid          ({IC_ID_WIDTH{1'b0}}),
      .m02_axi_rdata        ({DATA_WIDTH{1'b0}}),
      .m02_axi_rresp        (2'b00),
      .m02_axi_rlast        (1'b1),
      .m02_axi_ruser        (1'b0),
      .m02_axi_rvalid       (1'b0),

      .m03_axi_awid         (),
      .m03_axi_awaddr       (),
      .m03_axi_awlen        (),
      .m03_axi_awsize       (),
      .m03_axi_awburst      (),
      .m03_axi_awlock       (),
      .m03_axi_awcache      (),
      .m03_axi_awprot       (),
      .m03_axi_awqos        (),
      .m03_axi_awregion     (),
      .m03_axi_awuser       (),
      .m03_axi_awvalid      (),
      .m03_axi_wdata        (),
      .m03_axi_wstrb        (),
      .m03_axi_wlast        (),
      .m03_axi_wuser        (),
      .m03_axi_wvalid       (),
      .m03_axi_bready       (),
      .m03_axi_arid         (),
      .m03_axi_araddr       (),
      .m03_axi_arlen        (),
      .m03_axi_arsize       (),
      .m03_axi_arburst      (),
      .m03_axi_arlock       (),
      .m03_axi_arcache      (),
      .m03_axi_arprot       (),
      .m03_axi_arqos        (),
      .m03_axi_arregion     (),
      .m03_axi_aruser       (),
      .m03_axi_arvalid      (),
      .m03_axi_rready       (),
      .m03_axi_awready      (1'b1),
      .m03_axi_wready       (1'b1),
      .m03_axi_bid          ({IC_ID_WIDTH{1'b0}}),
      .m03_axi_bresp        (2'b00),
      .m03_axi_buser        (1'b0),
      .m03_axi_bvalid       (1'b0),
      .m03_axi_arready      (1'b1),
      .m03_axi_rid          ({IC_ID_WIDTH{1'b0}}),
      .m03_axi_rdata        ({DATA_WIDTH{1'b0}}),
      .m03_axi_rresp        (2'b00),
      .m03_axi_rlast        (1'b1),
      .m03_axi_ruser        (1'b0),
      .m03_axi_rvalid       (1'b0),

      .m04_axi_awid         (),
      .m04_axi_awaddr       (),
      .m04_axi_awlen        (),
      .m04_axi_awsize       (),
      .m04_axi_awburst      (),
      .m04_axi_awlock       (),
      .m04_axi_awcache      (),
      .m04_axi_awprot       (),
      .m04_axi_awqos        (),
      .m04_axi_awregion     (),
      .m04_axi_awuser       (),
      .m04_axi_awvalid      (),
      .m04_axi_wdata        (),
      .m04_axi_wstrb        (),
      .m04_axi_wlast        (),
      .m04_axi_wuser        (),
      .m04_axi_wvalid       (),
      .m04_axi_bready       (),
      .m04_axi_arid         (),
      .m04_axi_araddr       (),
      .m04_axi_arlen        (),
      .m04_axi_arsize       (),
      .m04_axi_arburst      (),
      .m04_axi_arlock       (),
      .m04_axi_arcache      (),
      .m04_axi_arprot       (),
      .m04_axi_arqos        (),
      .m04_axi_arregion     (),
      .m04_axi_aruser       (),
      .m04_axi_arvalid      (),
      .m04_axi_rready       (),
      .m04_axi_awready      (1'b1),
      .m04_axi_wready       (1'b1),
      .m04_axi_bid          ({IC_ID_WIDTH{1'b0}}),
      .m04_axi_bresp        (2'b00),
      .m04_axi_buser        (1'b0),
      .m04_axi_bvalid       (1'b0),
      .m04_axi_arready      (1'b1),
      .m04_axi_rid          ({IC_ID_WIDTH{1'b0}}),
      .m04_axi_rdata        ({DATA_WIDTH{1'b0}}),
      .m04_axi_rresp        (2'b00),
      .m04_axi_rlast        (1'b1),
      .m04_axi_ruser        (1'b0),
      .m04_axi_rvalid       (1'b0),

      .m05_axi_awid         (),
      .m05_axi_awaddr       (),
      .m05_axi_awlen        (),
      .m05_axi_awsize       (),
      .m05_axi_awburst      (),
      .m05_axi_awlock       (),
      .m05_axi_awcache      (),
      .m05_axi_awprot       (),
      .m05_axi_awqos        (),
      .m05_axi_awregion     (),
      .m05_axi_awuser       (),
      .m05_axi_awvalid      (),
      .m05_axi_wdata        (),
      .m05_axi_wstrb        (),
      .m05_axi_wlast        (),
      .m05_axi_wuser        (),
      .m05_axi_wvalid       (),
      .m05_axi_bready       (),
      .m05_axi_arid         (),
      .m05_axi_araddr       (),
      .m05_axi_arlen        (),
      .m05_axi_arsize       (),
      .m05_axi_arburst      (),
      .m05_axi_arlock       (),
      .m05_axi_arcache      (),
      .m05_axi_arprot       (),
      .m05_axi_arqos        (),
      .m05_axi_arregion     (),
      .m05_axi_aruser       (),
      .m05_axi_arvalid      (),
      .m05_axi_rready       (),
      .m05_axi_awready      (1'b1),
      .m05_axi_wready       (1'b1),
      .m05_axi_bid          ({IC_ID_WIDTH{1'b0}}),
      .m05_axi_bresp        (2'b00),
      .m05_axi_buser        (1'b0),
      .m05_axi_bvalid       (1'b0),
      .m05_axi_arready      (1'b1),
      .m05_axi_rid          ({IC_ID_WIDTH{1'b0}}),
      .m05_axi_rdata        ({DATA_WIDTH{1'b0}}),
      .m05_axi_rresp        (2'b00),
      .m05_axi_rlast        (1'b1),
      .m05_axi_ruser        (1'b0),
      .m05_axi_rvalid       (1'b0)
  );

  // =========================================================================
  // Instantiation 2: AXI4 → AXI4-Lite Bridge  (m00 ↔ UART)
  // =========================================================================

  axi4_to_axilite_bridge #(
      .DATA_WIDTH  (DATA_WIDTH),
      .ADDR_WIDTH  (ADDR_WIDTH),
      .ID_WIDTH    (IC_ID_WIDTH)
  ) u_bridge (
      .clk             (clk),
      .rst_n           (rst_n),

      // AXI4 slave (from interconnect m00)
      .s_axi_awid      (m00_awid),
      .s_axi_awaddr    (m00_awaddr),
      .s_axi_awlen     (m00_awlen),
      .s_axi_awsize    (m00_awsize),
      .s_axi_awburst   (m00_awburst),
      .s_axi_awlock    (m00_awlock),
      .s_axi_awcache   (m00_awcache),
      .s_axi_awprot    (m00_awprot),
      .s_axi_awqos     (m00_awqos),
      .s_axi_awregion  (m00_awregion),
      .s_axi_awvalid   (m00_awvalid),
      .s_axi_awready   (m00_awready),

      .s_axi_wdata     (m00_wdata),
      .s_axi_wstrb     (m00_wstrb),
      .s_axi_wlast     (m00_wlast),
      .s_axi_wvalid    (m00_wvalid),
      .s_axi_wready    (m00_wready),

      .s_axi_bid       (m00_bid),
      .s_axi_bresp     (m00_bresp),
      .s_axi_bvalid    (m00_bvalid),
      .s_axi_bready    (m00_bready),

      .s_axi_arid      (m00_arid),
      .s_axi_araddr    (m00_araddr),
      .s_axi_arlen     (m00_arlen),
      .s_axi_arsize    (m00_arsize),
      .s_axi_arburst   (m00_arburst),
      .s_axi_arlock    (m00_arlock),
      .s_axi_arcache   (m00_arcache),
      .s_axi_arprot    (m00_arprot),
      .s_axi_arqos     (m00_arqos),
      .s_axi_arregion  (m00_arregion),
      .s_axi_arvalid   (m00_arvalid),
      .s_axi_arready   (m00_arready),

      .s_axi_rid       (m00_rid),
      .s_axi_rdata     (m00_rdata),
      .s_axi_rresp     (m00_rresp),
      .s_axi_rlast     (m00_rlast),
      .s_axi_rvalid    (m00_rvalid),
      .s_axi_rready    (m00_rready),

      // AXI4-Lite master (to UART)
      .m_axi_awid      (uart_awid),
      .m_axi_awaddr    (uart_awaddr),
      .m_axi_awvalid   (uart_awvalid),
      .m_axi_awready   (uart_awready),

      .m_axi_wdata     (uart_wdata),
      .m_axi_wstrb     (uart_wstrb),
      .m_axi_wvalid    (uart_wvalid),
      .m_axi_wready    (uart_wready),

      .m_axi_bid       (uart_bid),
      .m_axi_bresp     (uart_bresp),
      .m_axi_bvalid    (uart_bvalid),
      .m_axi_bready    (uart_bready),

      .m_axi_arid      (uart_arid),
      .m_axi_araddr    (uart_araddr),
      .m_axi_arvalid   (uart_arvalid),
      .m_axi_arready   (uart_arready),

      .m_axi_rid       (uart_rid),
      .m_axi_rdata     (uart_rdata),
      .m_axi_rresp     (uart_rresp),
      .m_axi_rvalid    (uart_rvalid),
      .m_axi_rready    (uart_rready)
  );

  // =========================================================================
  // Instantiation 3: AXI4-Lite UART IP Core  (slave)
  // =========================================================================

  axi_uart_top u_uart (
      // Clocks / reset
      .fixed_clk_i      (fixed_clk),
      .axi_aclk_i       (clk),
      .axi_aresetn_i    (rst_n),

      // Write address channel
      .axi_awid_i       (uart_awid),
      .axi_awaddr_i     (uart_awaddr),
      .axi_awvalid_i    (uart_awvalid),
      .axi_awready_o    (uart_awready),

      // Write data channel
      .axi_wdata_i      (uart_wdata),
      .axi_wstrb_i      (uart_wstrb),
      .axi_wvalid_i     (uart_wvalid),
      .axi_wready_o     (uart_wready),

      // Write response channel
      .axi_bid_o        (uart_bid),
      .axi_bresp_o      (uart_bresp),
      .axi_bvalid_o     (uart_bvalid),
      .axi_bready_i     (uart_bready),

      // Read address channel
      .axi_arid_i       (uart_arid),
      .axi_araddr_i     (uart_araddr),
      .axi_arvalid_i    (uart_arvalid),
      .axi_arready_o    (uart_arready),

      // Read data channel
      .axi_rid_o        (uart_rid),
      .axi_rdata_o      (uart_rdata),
      .axi_rresp_o      (uart_rresp),
      .axi_rvalid_o     (uart_rvalid),
      .axi_rready_i     (uart_rready),

      // UART physical signals
      .uart_tx_o        (uart_tx_o),
      .uart_rx_i        (uart_rx_i),
      .read_interrupt_o (uart_read_irq_o)
  );

endmodule

`default_nettype wire
