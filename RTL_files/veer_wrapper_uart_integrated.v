// =============================================================================
// Module  : veer_wrapper_uart_integrated
// File    : RTL_files/veer_wrapper_uart_integrated.v
//
// Purpose : Top-level SoC integration of:
//             1. el2_veer_wrapper  – VeeR EL2 RISC-V core (AXI4 build)
//             2. axi_interconnect_uart_top – AXI4 2x6 interconnect + UART
//
// Connectivity overview:
//
//   ┌─────────────────────────────────────────────────────────────────┐
//   │                   veer_wrapper_uart_integrated                  │
//   │                                                                 │
//   │  ┌────────────────────┐    lsu_axi (32-bit addr, 64-bit data)  │
//   │  │  el2_veer_wrapper  │──►┌──────────────────────────┐         │
//   │  │  (RISC-V VeeR EL2) │   │ axi_dwidth_converter     │         │
//   │  │                    │   │   64-bit → 32-bit        │──► s00  │
//   │  │                    │   │ (byte-lane steering,      │         │
//   │  │                    │   │  awsize clamp, read-lane) │         │
//   │  │                    │   └──────────────────────────┘         │
//   │  │                    │    ifu_axi ──────────────────────────►  │
//   │  │                    │ ◄── dma_axi ──────────────────────────  │
//   │  └────────────────────┘                                         │
//   │                                                                 │
//   │  ┌──────────────────────────────────┐                           │
//   │  │  axi_interconnect_uart_top       │                           │
//   │  │  s00 ◄── VeeR LSU (via adapter)  │                           │
//   │  │  s01 ◄── exposed externally      │                           │
//   │  │  m00 ──► UART (0x4000_0000)      │                           │
//   │  │  m01-05 tied-off                 │                           │
//   │  └──────────────────────────────────┘                           │
//   └─────────────────────────────────────────────────────────────────┘
//
// Data-width note:
//   The VeeR EL2 LSU AXI master uses a 64-bit data bus; the
//   axi_interconnect_uart_top is parameterised for 32-bit data.
//   A dedicated axi_dwidth_converter_64to32 adapter module (defined at the
//   bottom of this file) is instantiated between the two to perform correct
//   AXI4 data-width conversion:
//     • awsize clamped to max 2 (32-bit) when VeeR issues a 64-bit beat
//     • Write data  : byte-lane steered using awaddr[2]
//     • Write strobe: byte-lane steered using awaddr[2]
//     • Read data   : 32-bit result replicated to the correct 64-bit lane
//                     (lane selected by araddr[2])
//   This is sufficient for 32-bit MMIO (UART) access; full split-beat
//   support for wider transfers is not required in this integration.
//
// Parameters:
//   IC_ID_WIDTH   – AXI ID width for the interconnect / UART side (8)
//   LSU_BUS_TAG   – VeeR LSU AXI ID width  (matches pt.LSU_BUS_TAG, default 4)
//   IFU_BUS_TAG   – VeeR IFU AXI ID width  (matches pt.IFU_BUS_TAG, default 3)
//   SB_BUS_TAG    – VeeR SB  AXI ID width  (matches pt.SB_BUS_TAG,  default 2)
//   DMA_BUS_TAG   – VeeR DMA AXI ID width  (matches pt.DMA_BUS_TAG, default 1)
//   UART_BASE_ADDR – UART peripheral base address in the system map
//
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module veer_wrapper_uart_integrated #(
    // -----------------------------------------------------------------------
    // Interconnect / UART parameters
    // -----------------------------------------------------------------------
    parameter IC_ID_WIDTH   = 8,
    parameter DATA_WIDTH    = 32,          // interconnect data width
    parameter ADDR_WIDTH    = 32,
    parameter [ADDR_WIDTH-1:0] UART_BASE_ADDR = 32'h4000_0000,

    // -----------------------------------------------------------------------
    // VeeR EL2 AXI tag / ID widths – must match el2_param.vh settings
    // -----------------------------------------------------------------------
    parameter LSU_BUS_TAG   = 4,
    parameter IFU_BUS_TAG   = 3,
    parameter SB_BUS_TAG    = 2,
    parameter DMA_BUS_TAG   = 1,

    // -----------------------------------------------------------------------
    // PIC interrupt count – must match pt.PIC_TOTAL_INT
    // -----------------------------------------------------------------------
    parameter PIC_TOTAL_INT = 31
)(
    // -----------------------------------------------------------------------
    // Global clocks / resets
    // -----------------------------------------------------------------------
    input  wire                         clk,          // main system clock
    input  wire                         rst_l,        // VeeR core reset, active-low
    input  wire                         dbg_rst_l,    // VeeR debug reset, active-low
    input  wire                         fixed_clk,    // UART baud-rate reference clock

    // -----------------------------------------------------------------------
    // VeeR boot / identification
    // -----------------------------------------------------------------------
    input  wire [31:1]                  rst_vec,      // reset vector (tie to constant)
    input  wire [31:1]                  nmi_vec,      // NMI vector   (tie to constant)
    input  wire [31:1]                  jtag_id,      // JTAG ID      (tie to constant)
    input  wire [31:4]                  core_id,      // Core ID      (tie to constant)

    // -----------------------------------------------------------------------
    // VeeR interrupts
    // -----------------------------------------------------------------------
    input  wire                         nmi_int,
    input  wire                         timer_int,
    input  wire                         soft_int,
    input  wire [PIC_TOTAL_INT:1]       extintsrc_req,
    // UART RX interrupt wired into extintsrc_req[1] internally; also exposed:
    output wire                         uart_read_irq_o,

    // -----------------------------------------------------------------------
    // UART physical signals
    // -----------------------------------------------------------------------
    output wire                         uart_tx_o,
    input  wire                         uart_rx_i,

    // -----------------------------------------------------------------------
    // VeeR IFU AXI master port (instruction fetch – connect to IMEM/Flash)
    // -----------------------------------------------------------------------
    output wire                         ifu_axi_arvalid,
    input  wire                         ifu_axi_arready,
    output wire [IFU_BUS_TAG-1:0]       ifu_axi_arid,
    output wire [31:0]                  ifu_axi_araddr,
    output wire [3:0]                   ifu_axi_arregion,
    output wire [7:0]                   ifu_axi_arlen,
    output wire [2:0]                   ifu_axi_arsize,
    output wire [1:0]                   ifu_axi_arburst,
    output wire                         ifu_axi_arlock,
    output wire [3:0]                   ifu_axi_arcache,
    output wire [2:0]                   ifu_axi_arprot,
    output wire [3:0]                   ifu_axi_arqos,

    input  wire                         ifu_axi_rvalid,
    output wire                         ifu_axi_rready,
    input  wire [IFU_BUS_TAG-1:0]       ifu_axi_rid,
    input  wire [63:0]                  ifu_axi_rdata,
    input  wire [1:0]                   ifu_axi_rresp,
    input  wire                         ifu_axi_rlast,

    // IFU write channel (IFU never writes; tie these off at board level)
    output wire                         ifu_axi_awvalid,
    input  wire                         ifu_axi_awready,
    output wire [IFU_BUS_TAG-1:0]       ifu_axi_awid,
    output wire [31:0]                  ifu_axi_awaddr,
    output wire [3:0]                   ifu_axi_awregion,
    output wire [7:0]                   ifu_axi_awlen,
    output wire [2:0]                   ifu_axi_awsize,
    output wire [1:0]                   ifu_axi_awburst,
    output wire                         ifu_axi_awlock,
    output wire [3:0]                   ifu_axi_awcache,
    output wire [2:0]                   ifu_axi_awprot,
    output wire [3:0]                   ifu_axi_awqos,

    output wire                         ifu_axi_wvalid,
    input  wire                         ifu_axi_wready,
    output wire [63:0]                  ifu_axi_wdata,
    output wire [7:0]                   ifu_axi_wstrb,
    output wire                         ifu_axi_wlast,

    input  wire                         ifu_axi_bvalid,
    output wire                         ifu_axi_bready,
    input  wire [1:0]                   ifu_axi_bresp,
    input  wire [IFU_BUS_TAG-1:0]       ifu_axi_bid,

    // -----------------------------------------------------------------------
    // VeeR Debug System Bus (SB) AXI master port
    // -----------------------------------------------------------------------
    output wire                         sb_axi_awvalid,
    input  wire                         sb_axi_awready,
    output wire [SB_BUS_TAG-1:0]        sb_axi_awid,
    output wire [31:0]                  sb_axi_awaddr,
    output wire [3:0]                   sb_axi_awregion,
    output wire [7:0]                   sb_axi_awlen,
    output wire [2:0]                   sb_axi_awsize,
    output wire [1:0]                   sb_axi_awburst,
    output wire                         sb_axi_awlock,
    output wire [3:0]                   sb_axi_awcache,
    output wire [2:0]                   sb_axi_awprot,
    output wire [3:0]                   sb_axi_awqos,

    output wire                         sb_axi_wvalid,
    input  wire                         sb_axi_wready,
    output wire [63:0]                  sb_axi_wdata,
    output wire [7:0]                   sb_axi_wstrb,
    output wire                         sb_axi_wlast,

    input  wire                         sb_axi_bvalid,
    output wire                         sb_axi_bready,
    input  wire [1:0]                   sb_axi_bresp,
    input  wire [SB_BUS_TAG-1:0]        sb_axi_bid,

    output wire                         sb_axi_arvalid,
    input  wire                         sb_axi_arready,
    output wire [SB_BUS_TAG-1:0]        sb_axi_arid,
    output wire [31:0]                  sb_axi_araddr,
    output wire [3:0]                   sb_axi_arregion,
    output wire [7:0]                   sb_axi_arlen,
    output wire [2:0]                   sb_axi_arsize,
    output wire [1:0]                   sb_axi_arburst,
    output wire                         sb_axi_arlock,
    output wire [3:0]                   sb_axi_arcache,
    output wire [2:0]                   sb_axi_arprot,
    output wire [3:0]                   sb_axi_arqos,

    input  wire                         sb_axi_rvalid,
    output wire                         sb_axi_rready,
    input  wire [SB_BUS_TAG-1:0]        sb_axi_rid,
    input  wire [63:0]                  sb_axi_rdata,
    input  wire [1:0]                   sb_axi_rresp,
    input  wire                         sb_axi_rlast,

    // -----------------------------------------------------------------------
    // VeeR DMA AXI slave port (external DMA master → core DCCM/ICCM)
    // -----------------------------------------------------------------------
    input  wire                         dma_axi_awvalid,
    output wire                         dma_axi_awready,
    input  wire [DMA_BUS_TAG-1:0]       dma_axi_awid,
    input  wire [31:0]                  dma_axi_awaddr,
    input  wire [2:0]                   dma_axi_awsize,
    input  wire [2:0]                   dma_axi_awprot,
    input  wire [7:0]                   dma_axi_awlen,
    input  wire [1:0]                   dma_axi_awburst,

    input  wire                         dma_axi_wvalid,
    output wire                         dma_axi_wready,
    input  wire [63:0]                  dma_axi_wdata,
    input  wire [7:0]                   dma_axi_wstrb,
    input  wire                         dma_axi_wlast,

    output wire                         dma_axi_bvalid,
    input  wire                         dma_axi_bready,
    output wire [1:0]                   dma_axi_bresp,
    output wire [DMA_BUS_TAG-1:0]       dma_axi_bid,

    input  wire                         dma_axi_arvalid,
    output wire                         dma_axi_arready,
    input  wire [DMA_BUS_TAG-1:0]       dma_axi_arid,
    input  wire [31:0]                  dma_axi_araddr,
    input  wire [2:0]                   dma_axi_arsize,
    input  wire [2:0]                   dma_axi_arprot,
    input  wire [7:0]                   dma_axi_arlen,
    input  wire [1:0]                   dma_axi_arburst,

    output wire                         dma_axi_rvalid,
    input  wire                         dma_axi_rready,
    output wire [DMA_BUS_TAG-1:0]       dma_axi_rid,
    output wire [63:0]                  dma_axi_rdata,
    output wire [1:0]                   dma_axi_rresp,
    output wire                         dma_axi_rlast,

    // -----------------------------------------------------------------------
    // Interconnect secondary slave port (s01) – external AXI4 master
    // (e.g., a debug master or second DMA engine accessing peripherals)
    // -----------------------------------------------------------------------
    input  wire [IC_ID_WIDTH-1:0]       s01_axi_awid,
    input  wire [ADDR_WIDTH-1:0]        s01_axi_awaddr,
    input  wire [7:0]                   s01_axi_awlen,
    input  wire [2:0]                   s01_axi_awsize,
    input  wire [1:0]                   s01_axi_awburst,
    input  wire                         s01_axi_awlock,
    input  wire [3:0]                   s01_axi_awcache,
    input  wire [2:0]                   s01_axi_awprot,
    input  wire [3:0]                   s01_axi_awqos,
    input  wire                         s01_axi_awvalid,
    output wire                         s01_axi_awready,

    input  wire [DATA_WIDTH-1:0]        s01_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]      s01_axi_wstrb,
    input  wire                         s01_axi_wlast,
    input  wire                         s01_axi_wvalid,
    output wire                         s01_axi_wready,

    output wire [IC_ID_WIDTH-1:0]       s01_axi_bid,
    output wire [1:0]                   s01_axi_bresp,
    output wire                         s01_axi_bvalid,
    input  wire                         s01_axi_bready,

    input  wire [IC_ID_WIDTH-1:0]       s01_axi_arid,
    input  wire [ADDR_WIDTH-1:0]        s01_axi_araddr,
    input  wire [7:0]                   s01_axi_arlen,
    input  wire [2:0]                   s01_axi_arsize,
    input  wire [1:0]                   s01_axi_arburst,
    input  wire                         s01_axi_arlock,
    input  wire [3:0]                   s01_axi_arcache,
    input  wire [2:0]                   s01_axi_arprot,
    input  wire [3:0]                   s01_axi_arqos,
    input  wire                         s01_axi_arvalid,
    output wire                         s01_axi_arready,

    output wire [IC_ID_WIDTH-1:0]       s01_axi_rid,
    output wire [DATA_WIDTH-1:0]        s01_axi_rdata,
    output wire [1:0]                   s01_axi_rresp,
    output wire                         s01_axi_rlast,
    output wire                         s01_axi_rvalid,
    input  wire                         s01_axi_rready,

    // -----------------------------------------------------------------------
    // VeeR trace outputs
    // -----------------------------------------------------------------------
    output wire [31:0]                  trace_rv_i_insn_ip,
    output wire [31:0]                  trace_rv_i_address_ip,
    output wire                         trace_rv_i_valid_ip,
    output wire                         trace_rv_i_exception_ip,
    output wire [4:0]                   trace_rv_i_ecause_ip,
    output wire                         trace_rv_i_interrupt_ip,
    output wire [31:0]                  trace_rv_i_tval_ip,

    // -----------------------------------------------------------------------
    // VeeR ECC status
    // -----------------------------------------------------------------------
    output wire                         iccm_ecc_single_error,
    output wire                         iccm_ecc_double_error,
    output wire                         dccm_ecc_single_error,
    output wire                         dccm_ecc_double_error,
    output wire                         dccm_write_readback_error,

    // -----------------------------------------------------------------------
    // VeeR performance counters
    // -----------------------------------------------------------------------
    output wire                         dec_tlu_perfcnt0,
    output wire                         dec_tlu_perfcnt1,
    output wire                         dec_tlu_perfcnt2,
    output wire                         dec_tlu_perfcnt3,

    // -----------------------------------------------------------------------
    // JTAG
    // -----------------------------------------------------------------------
    input  wire                         jtag_tck,
    input  wire                         jtag_tms,
    input  wire                         jtag_tdi,
    input  wire                         jtag_trst_n,
    output wire                         jtag_tdo,
    output wire                         jtag_tdoEn,

    // -----------------------------------------------------------------------
    // VeeR MPC / halt / run interface
    // -----------------------------------------------------------------------
    input  wire                         mpc_debug_halt_req,
    input  wire                         mpc_debug_run_req,
    input  wire                         mpc_reset_run_req,
    output wire                         mpc_debug_halt_ack,
    output wire                         mpc_debug_run_ack,
    output wire                         debug_brkpt_status,

    input  wire                         i_cpu_halt_req,
    output wire                         o_cpu_halt_ack,
    output wire                         o_cpu_halt_status,
    output wire                         o_debug_mode_status,
    input  wire                         i_cpu_run_req,
    output wire                         o_cpu_run_ack,

    // -----------------------------------------------------------------------
    // Miscellaneous VeeR inputs
    // -----------------------------------------------------------------------
    input  wire                         lsu_bus_clk_en,
    input  wire                         ifu_bus_clk_en,
    input  wire                         dbg_bus_clk_en,
    input  wire                         dma_bus_clk_en,
    input  wire                         scan_mode,
    input  wire                         mbist_mode,

    // -----------------------------------------------------------------------
    // DMI uncore interface
    // -----------------------------------------------------------------------
    input  wire                         dmi_core_enable,
    input  wire                         dmi_uncore_enable,
    output wire                         dmi_uncore_en,
    output wire                         dmi_uncore_wr_en,
    output wire [6:0]                   dmi_uncore_addr,
    output wire [31:0]                  dmi_uncore_wdata,
    input  wire [31:0]                  dmi_uncore_rdata,
    output wire                         dmi_active
);

    // =========================================================================
    // Internal wires: VeeR LSU AXI master ↔ interconnect s00 slave
    // =========================================================================
    // VeeR LSU has a 64-bit data bus; the interconnect is 32-bit.
    // We connect the lower 32 bits for data and zero-pad on read.
    // The wstrb is 8-bit (for 64-bit data); only the lower 4 bits are used.

    wire                        lsu_axi_awvalid_w;
    wire                        lsu_axi_awready_w;
    wire [LSU_BUS_TAG-1:0]      lsu_axi_awid_w;
    wire [31:0]                 lsu_axi_awaddr_w;
    wire [3:0]                  lsu_axi_awregion_w;
    wire [7:0]                  lsu_axi_awlen_w;
    wire [2:0]                  lsu_axi_awsize_w;
    wire [1:0]                  lsu_axi_awburst_w;
    wire                        lsu_axi_awlock_w;
    wire [3:0]                  lsu_axi_awcache_w;
    wire [2:0]                  lsu_axi_awprot_w;
    wire [3:0]                  lsu_axi_awqos_w;

    wire                        lsu_axi_wvalid_w;
    wire                        lsu_axi_wready_w;
    wire [63:0]                 lsu_axi_wdata_w;
    wire [7:0]                  lsu_axi_wstrb_w;
    wire                        lsu_axi_wlast_w;

    wire                        lsu_axi_bvalid_w;
    wire                        lsu_axi_bready_w;
    wire [1:0]                  lsu_axi_bresp_w;
    wire [LSU_BUS_TAG-1:0]      lsu_axi_bid_w;

    wire                        lsu_axi_arvalid_w;
    wire                        lsu_axi_arready_w;
    wire [LSU_BUS_TAG-1:0]      lsu_axi_arid_w;
    wire [31:0]                 lsu_axi_araddr_w;
    wire [3:0]                  lsu_axi_arregion_w;
    wire [7:0]                  lsu_axi_arlen_w;
    wire [2:0]                  lsu_axi_arsize_w;
    wire [1:0]                  lsu_axi_arburst_w;
    wire                        lsu_axi_arlock_w;
    wire [3:0]                  lsu_axi_arcache_w;
    wire [2:0]                  lsu_axi_arprot_w;
    wire [3:0]                  lsu_axi_arqos_w;

    wire                        lsu_axi_rvalid_w;
    wire                        lsu_axi_rready_w;
    wire [LSU_BUS_TAG-1:0]      lsu_axi_rid_w;
    wire [63:0]                 lsu_axi_rdata_w;
    wire [1:0]                  lsu_axi_rresp_w;
    wire                        lsu_axi_rlast_w;

    // =========================================================================
    // Internal wires: s00 port of interconnect (32-bit data side)
    // =========================================================================
    wire [IC_ID_WIDTH-1:0]      s00_awid_w;
    wire [ADDR_WIDTH-1:0]       s00_awaddr_w;
    wire [7:0]                  s00_awlen_w;
    wire [2:0]                  s00_awsize_w;
    wire [1:0]                  s00_awburst_w;
    wire                        s00_awlock_w;
    wire [3:0]                  s00_awcache_w;
    wire [2:0]                  s00_awprot_w;
    wire [3:0]                  s00_awqos_w;
    wire                        s00_awvalid_w;
    wire                        s00_awready_w;

    wire [DATA_WIDTH-1:0]       s00_wdata_w;
    wire [DATA_WIDTH/8-1:0]     s00_wstrb_w;
    wire                        s00_wlast_w;
    wire                        s00_wvalid_w;
    wire                        s00_wready_w;

    wire [IC_ID_WIDTH-1:0]      s00_bid_w;
    wire [1:0]                  s00_bresp_w;
    wire                        s00_bvalid_w;
    wire                        s00_bready_w;

    wire [IC_ID_WIDTH-1:0]      s00_arid_w;
    wire [ADDR_WIDTH-1:0]       s00_araddr_w;
    wire [7:0]                  s00_arlen_w;
    wire [2:0]                  s00_arsize_w;
    wire [1:0]                  s00_arburst_w;
    wire                        s00_arlock_w;
    wire [3:0]                  s00_arcache_w;
    wire [2:0]                  s00_arprot_w;
    wire [3:0]                  s00_arqos_w;
    wire                        s00_arvalid_w;
    wire                        s00_arready_w;

    wire [IC_ID_WIDTH-1:0]      s00_rid_w;
    wire [DATA_WIDTH-1:0]       s00_rdata_w;
    wire [1:0]                  s00_rresp_w;
    wire                        s00_rlast_w;
    wire                        s00_rvalid_w;
    wire                        s00_rready_w;

    // =========================================================================
    // Wire: UART interrupt → VeeR extintsrc_req[1]
    // (The top-level extintsrc_req bus is driven externally; we expose the
    //  UART IRQ separately so the integrator can OR it into the extintsrc_req
    //  vector.  Here we simply re-export uart_read_irq_o.)
    // =========================================================================

    // =========================================================================
    // Data-width adaptation: VeeR LSU (64-bit) ↔ Interconnect s00 (32-bit)
    // Implemented via axi_dwidth_converter_64to32 (defined at end of file).
    // =========================================================================
    axi_dwidth_converter_64to32 #(
        .ID_WIDTH_M  (LSU_BUS_TAG),
        .ID_WIDTH_S  (IC_ID_WIDTH),
        .ADDR_WIDTH  (32)
    ) u_dwidth_conv (
        .clk             (clk),
        .rst_n           (rst_l),

        // ---- Master side: VeeR LSU (64-bit) ----
        .m_axi_awid      (lsu_axi_awid_w),
        .m_axi_awaddr    (lsu_axi_awaddr_w),
        .m_axi_awlen     (lsu_axi_awlen_w),
        .m_axi_awsize    (lsu_axi_awsize_w),
        .m_axi_awburst   (lsu_axi_awburst_w),
        .m_axi_awlock    (lsu_axi_awlock_w),
        .m_axi_awcache   (lsu_axi_awcache_w),
        .m_axi_awprot    (lsu_axi_awprot_w),
        .m_axi_awqos     (lsu_axi_awqos_w),
        .m_axi_awregion  (lsu_axi_awregion_w),
        .m_axi_awvalid   (lsu_axi_awvalid_w),
        .m_axi_awready   (lsu_axi_awready_w),

        .m_axi_wdata     (lsu_axi_wdata_w),
        .m_axi_wstrb     (lsu_axi_wstrb_w),
        .m_axi_wlast     (lsu_axi_wlast_w),
        .m_axi_wvalid    (lsu_axi_wvalid_w),
        .m_axi_wready    (lsu_axi_wready_w),

        .m_axi_bid       (lsu_axi_bid_w),
        .m_axi_bresp     (lsu_axi_bresp_w),
        .m_axi_bvalid    (lsu_axi_bvalid_w),
        .m_axi_bready    (lsu_axi_bready_w),

        .m_axi_arid      (lsu_axi_arid_w),
        .m_axi_araddr    (lsu_axi_araddr_w),
        .m_axi_arlen     (lsu_axi_arlen_w),
        .m_axi_arsize    (lsu_axi_arsize_w),
        .m_axi_arburst   (lsu_axi_arburst_w),
        .m_axi_arlock    (lsu_axi_arlock_w),
        .m_axi_arcache   (lsu_axi_arcache_w),
        .m_axi_arprot    (lsu_axi_arprot_w),
        .m_axi_arqos     (lsu_axi_arqos_w),
        .m_axi_arregion  (lsu_axi_arregion_w),
        .m_axi_arvalid   (lsu_axi_arvalid_w),
        .m_axi_arready   (lsu_axi_arready_w),

        .m_axi_rid       (lsu_axi_rid_w),
        .m_axi_rdata     (lsu_axi_rdata_w),
        .m_axi_rresp     (lsu_axi_rresp_w),
        .m_axi_rlast     (lsu_axi_rlast_w),
        .m_axi_rvalid    (lsu_axi_rvalid_w),
        .m_axi_rready    (lsu_axi_rready_w),

        // ---- Slave side: Interconnect s00 (32-bit) ----
        .s_axi_awid      (s00_awid_w),
        .s_axi_awaddr    (s00_awaddr_w),
        .s_axi_awlen     (s00_awlen_w),
        .s_axi_awsize    (s00_awsize_w),
        .s_axi_awburst   (s00_awburst_w),
        .s_axi_awlock    (s00_awlock_w),
        .s_axi_awcache   (s00_awcache_w),
        .s_axi_awprot    (s00_awprot_w),
        .s_axi_awqos     (s00_awqos_w),
        .s_axi_awvalid   (s00_awvalid_w),
        .s_axi_awready   (s00_awready_w),

        .s_axi_wdata     (s00_wdata_w),
        .s_axi_wstrb     (s00_wstrb_w),
        .s_axi_wlast     (s00_wlast_w),
        .s_axi_wvalid    (s00_wvalid_w),
        .s_axi_wready    (s00_wready_w),

        .s_axi_bid       (s00_bid_w),
        .s_axi_bresp     (s00_bresp_w),
        .s_axi_bvalid    (s00_bvalid_w),
        .s_axi_bready    (s00_bready_w),

        .s_axi_arid      (s00_arid_w),
        .s_axi_araddr    (s00_araddr_w),
        .s_axi_arlen     (s00_arlen_w),
        .s_axi_arsize    (s00_arsize_w),
        .s_axi_arburst   (s00_arburst_w),
        .s_axi_arlock    (s00_arlock_w),
        .s_axi_arcache   (s00_arcache_w),
        .s_axi_arprot    (s00_arprot_w),
        .s_axi_arqos     (s00_arqos_w),
        .s_axi_arvalid   (s00_arvalid_w),
        .s_axi_arready   (s00_arready_w),

        .s_axi_rid       (s00_rid_w),
        .s_axi_rdata     (s00_rdata_w),
        .s_axi_rresp     (s00_rresp_w),
        .s_axi_rlast     (s00_rlast_w),
        .s_axi_rvalid    (s00_rvalid_w),
        .s_axi_rready    (s00_rready_w)
    );

    // =========================================================================
    // el2_mem_if interface instances
    // -------------------------------------------------------------------------
    // el2_veer_wrapper exposes two interface ports:
    //   el2_mem_export   (modport veer_sram_src)  – ICCM + DCCM SRAM signals
    //   el2_icache_export(modport veer_icache_src) – ICache data + tag signals
    //
    // A single el2_mem_if instance covers all signals for both ports (the
    // icache modport and sram modport share the same interface object, as done
    // in the reference veer_wrapper.sv in the VeeR testbench directory).
    //
    // The read-back (sink) signals – iccm_bank_dout, dccm_bank_dout,
    // wb_packeddout_pre, wb_dout_pre_up, ic_tag_data_raw_packed_pre,
    // ic_tag_data_raw_pre – are tied to zero here because no SRAM model is
    // instantiated in this integration wrapper.  Connect el2_mem to these
    // signals in a full SoC build.
    // =========================================================================
    el2_mem_if el2_mem_export_if ();

    // Tie read-back (sink) ports to zero – no SRAM model in this wrapper
    assign el2_mem_export_if.iccm_bank_dout          = '0;
    assign el2_mem_export_if.iccm_bank_ecc           = '0;
    assign el2_mem_export_if.dccm_bank_dout          = '0;
    assign el2_mem_export_if.dccm_bank_ecc           = '0;
    assign el2_mem_export_if.wb_packeddout_pre        = '0;
    assign el2_mem_export_if.wb_dout_pre_up           = '0;
    assign el2_mem_export_if.ic_tag_data_raw_packed_pre = '0;
    assign el2_mem_export_if.ic_tag_data_raw_pre      = '0;

    // =========================================================================
    // Instantiation 1: VeeR EL2 Wrapper
    // =========================================================================
    el2_veer_wrapper veer_inst (
        .clk                        (clk),
        .rst_l                      (rst_l),
        .dbg_rst_l                  (dbg_rst_l),
        .rst_vec                    (rst_vec),
        .nmi_int                    (nmi_int),
        .nmi_vec                    (nmi_vec),
        .jtag_id                    (jtag_id),

        // Trace
        .trace_rv_i_insn_ip         (trace_rv_i_insn_ip),
        .trace_rv_i_address_ip      (trace_rv_i_address_ip),
        .trace_rv_i_valid_ip        (trace_rv_i_valid_ip),
        .trace_rv_i_exception_ip    (trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip       (trace_rv_i_ecause_ip),
        .trace_rv_i_interrupt_ip    (trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip         (trace_rv_i_tval_ip),

        // ---- LSU AXI master (→ interconnect s00) ----
        .lsu_axi_awvalid            (lsu_axi_awvalid_w),
        .lsu_axi_awready            (lsu_axi_awready_w),
        .lsu_axi_awid               (lsu_axi_awid_w),
        .lsu_axi_awaddr             (lsu_axi_awaddr_w),
        .lsu_axi_awregion           (lsu_axi_awregion_w),
        .lsu_axi_awlen              (lsu_axi_awlen_w),
        .lsu_axi_awsize             (lsu_axi_awsize_w),
        .lsu_axi_awburst            (lsu_axi_awburst_w),
        .lsu_axi_awlock             (lsu_axi_awlock_w),
        .lsu_axi_awcache            (lsu_axi_awcache_w),
        .lsu_axi_awprot             (lsu_axi_awprot_w),
        .lsu_axi_awqos              (lsu_axi_awqos_w),

        .lsu_axi_wvalid             (lsu_axi_wvalid_w),
        .lsu_axi_wready             (lsu_axi_wready_w),
        .lsu_axi_wdata              (lsu_axi_wdata_w),
        .lsu_axi_wstrb              (lsu_axi_wstrb_w),
        .lsu_axi_wlast              (lsu_axi_wlast_w),

        .lsu_axi_bvalid             (lsu_axi_bvalid_w),
        .lsu_axi_bready             (lsu_axi_bready_w),
        .lsu_axi_bresp              (lsu_axi_bresp_w),
        .lsu_axi_bid                (lsu_axi_bid_w),

        .lsu_axi_arvalid            (lsu_axi_arvalid_w),
        .lsu_axi_arready            (lsu_axi_arready_w),
        .lsu_axi_arid               (lsu_axi_arid_w),
        .lsu_axi_araddr             (lsu_axi_araddr_w),
        .lsu_axi_arregion           (lsu_axi_arregion_w),
        .lsu_axi_arlen              (lsu_axi_arlen_w),
        .lsu_axi_arsize             (lsu_axi_arsize_w),
        .lsu_axi_arburst            (lsu_axi_arburst_w),
        .lsu_axi_arlock             (lsu_axi_arlock_w),
        .lsu_axi_arcache            (lsu_axi_arcache_w),
        .lsu_axi_arprot             (lsu_axi_arprot_w),
        .lsu_axi_arqos              (lsu_axi_arqos_w),

        .lsu_axi_rvalid             (lsu_axi_rvalid_w),
        .lsu_axi_rready             (lsu_axi_rready_w),
        .lsu_axi_rid                (lsu_axi_rid_w),
        .lsu_axi_rdata              (lsu_axi_rdata_w),
        .lsu_axi_rresp              (lsu_axi_rresp_w),
        .lsu_axi_rlast              (lsu_axi_rlast_w),

        // ---- IFU AXI master (→ top-level ports for IMEM) ----
        .ifu_axi_awvalid            (ifu_axi_awvalid),
        .ifu_axi_awready            (ifu_axi_awready),
        .ifu_axi_awid               (ifu_axi_awid),
        .ifu_axi_awaddr             (ifu_axi_awaddr),
        .ifu_axi_awregion           (ifu_axi_awregion),
        .ifu_axi_awlen              (ifu_axi_awlen),
        .ifu_axi_awsize             (ifu_axi_awsize),
        .ifu_axi_awburst            (ifu_axi_awburst),
        .ifu_axi_awlock             (ifu_axi_awlock),
        .ifu_axi_awcache            (ifu_axi_awcache),
        .ifu_axi_awprot             (ifu_axi_awprot),
        .ifu_axi_awqos              (ifu_axi_awqos),

        .ifu_axi_wvalid             (ifu_axi_wvalid),
        .ifu_axi_wready             (ifu_axi_wready),
        .ifu_axi_wdata              (ifu_axi_wdata),
        .ifu_axi_wstrb              (ifu_axi_wstrb),
        .ifu_axi_wlast              (ifu_axi_wlast),

        .ifu_axi_bvalid             (ifu_axi_bvalid),
        .ifu_axi_bready             (ifu_axi_bready),
        .ifu_axi_bresp              (ifu_axi_bresp),
        .ifu_axi_bid                (ifu_axi_bid),

        .ifu_axi_arvalid            (ifu_axi_arvalid),
        .ifu_axi_arready            (ifu_axi_arready),
        .ifu_axi_arid               (ifu_axi_arid),
        .ifu_axi_araddr             (ifu_axi_araddr),
        .ifu_axi_arregion           (ifu_axi_arregion),
        .ifu_axi_arlen              (ifu_axi_arlen),
        .ifu_axi_arsize             (ifu_axi_arsize),
        .ifu_axi_arburst            (ifu_axi_arburst),
        .ifu_axi_arlock             (ifu_axi_arlock),
        .ifu_axi_arcache            (ifu_axi_arcache),
        .ifu_axi_arprot             (ifu_axi_arprot),
        .ifu_axi_arqos              (ifu_axi_arqos),

        .ifu_axi_rvalid             (ifu_axi_rvalid),
        .ifu_axi_rready             (ifu_axi_rready),
        .ifu_axi_rid                (ifu_axi_rid),
        .ifu_axi_rdata              (ifu_axi_rdata),
        .ifu_axi_rresp              (ifu_axi_rresp),
        .ifu_axi_rlast              (ifu_axi_rlast),

        // ---- SB AXI master (debug system bus → top-level ports) ----
        .sb_axi_awvalid             (sb_axi_awvalid),
        .sb_axi_awready             (sb_axi_awready),
        .sb_axi_awid                (sb_axi_awid),
        .sb_axi_awaddr              (sb_axi_awaddr),
        .sb_axi_awregion            (sb_axi_awregion),
        .sb_axi_awlen               (sb_axi_awlen),
        .sb_axi_awsize              (sb_axi_awsize),
        .sb_axi_awburst             (sb_axi_awburst),
        .sb_axi_awlock              (sb_axi_awlock),
        .sb_axi_awcache             (sb_axi_awcache),
        .sb_axi_awprot              (sb_axi_awprot),
        .sb_axi_awqos               (sb_axi_awqos),

        .sb_axi_wvalid              (sb_axi_wvalid),
        .sb_axi_wready              (sb_axi_wready),
        .sb_axi_wdata               (sb_axi_wdata),
        .sb_axi_wstrb               (sb_axi_wstrb),
        .sb_axi_wlast               (sb_axi_wlast),

        .sb_axi_bvalid              (sb_axi_bvalid),
        .sb_axi_bready              (sb_axi_bready),
        .sb_axi_bresp               (sb_axi_bresp),
        .sb_axi_bid                 (sb_axi_bid),

        .sb_axi_arvalid             (sb_axi_arvalid),
        .sb_axi_arready             (sb_axi_arready),
        .sb_axi_arid                (sb_axi_arid),
        .sb_axi_araddr              (sb_axi_araddr),
        .sb_axi_arregion            (sb_axi_arregion),
        .sb_axi_arlen               (sb_axi_arlen),
        .sb_axi_arsize              (sb_axi_arsize),
        .sb_axi_arburst             (sb_axi_arburst),
        .sb_axi_arlock              (sb_axi_arlock),
        .sb_axi_arcache             (sb_axi_arcache),
        .sb_axi_arprot              (sb_axi_arprot),
        .sb_axi_arqos               (sb_axi_arqos),

        .sb_axi_rvalid              (sb_axi_rvalid),
        .sb_axi_rready              (sb_axi_rready),
        .sb_axi_rid                 (sb_axi_rid),
        .sb_axi_rdata               (sb_axi_rdata),
        .sb_axi_rresp               (sb_axi_rresp),
        .sb_axi_rlast               (sb_axi_rlast),

        // ---- DMA AXI slave (top-level ports) ----
        .dma_axi_awvalid            (dma_axi_awvalid),
        .dma_axi_awready            (dma_axi_awready),
        .dma_axi_awid               (dma_axi_awid),
        .dma_axi_awaddr             (dma_axi_awaddr),
        .dma_axi_awsize             (dma_axi_awsize),
        .dma_axi_awprot             (dma_axi_awprot),
        .dma_axi_awlen              (dma_axi_awlen),
        .dma_axi_awburst            (dma_axi_awburst),

        .dma_axi_wvalid             (dma_axi_wvalid),
        .dma_axi_wready             (dma_axi_wready),
        .dma_axi_wdata              (dma_axi_wdata),
        .dma_axi_wstrb              (dma_axi_wstrb),
        .dma_axi_wlast              (dma_axi_wlast),

        .dma_axi_bvalid             (dma_axi_bvalid),
        .dma_axi_bready             (dma_axi_bready),
        .dma_axi_bresp              (dma_axi_bresp),
        .dma_axi_bid                (dma_axi_bid),

        .dma_axi_arvalid            (dma_axi_arvalid),
        .dma_axi_arready            (dma_axi_arready),
        .dma_axi_arid               (dma_axi_arid),
        .dma_axi_araddr             (dma_axi_araddr),
        .dma_axi_arsize             (dma_axi_arsize),
        .dma_axi_arprot             (dma_axi_arprot),
        .dma_axi_arlen              (dma_axi_arlen),
        .dma_axi_arburst            (dma_axi_arburst),

        .dma_axi_rvalid             (dma_axi_rvalid),
        .dma_axi_rready             (dma_axi_rready),
        .dma_axi_rid                (dma_axi_rid),
        .dma_axi_rdata              (dma_axi_rdata),
        .dma_axi_rresp              (dma_axi_rresp),
        .dma_axi_rlast              (dma_axi_rlast),

        // ---- Clock enables ----
        .lsu_bus_clk_en             (lsu_bus_clk_en),
        .ifu_bus_clk_en             (ifu_bus_clk_en),
        .dbg_bus_clk_en             (dbg_bus_clk_en),
        .dma_bus_clk_en             (dma_bus_clk_en),

        // ---- ECC status ----
        .iccm_ecc_single_error      (iccm_ecc_single_error),
        .iccm_ecc_double_error      (iccm_ecc_double_error),
        .dccm_ecc_single_error      (dccm_ecc_single_error),
        .dccm_ecc_double_error      (dccm_ecc_double_error),
        .dccm_write_readback_error  (dccm_write_readback_error),

        // ---- Interrupts ----
        .timer_int                  (timer_int),
        .soft_int                   (soft_int),
        .extintsrc_req              (extintsrc_req),

        // ---- Performance counters ----
        .dec_tlu_perfcnt0           (dec_tlu_perfcnt0),
        .dec_tlu_perfcnt1           (dec_tlu_perfcnt1),
        .dec_tlu_perfcnt2           (dec_tlu_perfcnt2),
        .dec_tlu_perfcnt3           (dec_tlu_perfcnt3),

        // ---- JTAG ----
        .jtag_tck                   (jtag_tck),
        .jtag_tms                   (jtag_tms),
        .jtag_tdi                   (jtag_tdi),
        .jtag_trst_n                (jtag_trst_n),
        .jtag_tdo                   (jtag_tdo),
        .jtag_tdoEn                 (jtag_tdoEn),

        // ---- Core ID ----
        .core_id                    (core_id),

        // ---- MPC / halt / run ----
        .mpc_debug_halt_req         (mpc_debug_halt_req),
        .mpc_debug_run_req          (mpc_debug_run_req),
        .mpc_reset_run_req          (mpc_reset_run_req),
        .mpc_debug_halt_ack         (mpc_debug_halt_ack),
        .mpc_debug_run_ack          (mpc_debug_run_ack),
        .debug_brkpt_status         (debug_brkpt_status),

        .i_cpu_halt_req             (i_cpu_halt_req),
        .o_cpu_halt_ack             (o_cpu_halt_ack),
        .o_cpu_halt_status          (o_cpu_halt_status),
        .o_debug_mode_status        (o_debug_mode_status),
        .i_cpu_run_req              (i_cpu_run_req),
        .o_cpu_run_ack              (o_cpu_run_ack),

        // ---- Misc ----
        .scan_mode                  (scan_mode),
        .mbist_mode                 (mbist_mode),

        // ---- DMI uncore ----
        .dmi_core_enable            (dmi_core_enable),
        .dmi_uncore_enable          (dmi_uncore_enable),
        .dmi_uncore_en              (dmi_uncore_en),
        .dmi_uncore_wr_en           (dmi_uncore_wr_en),
        .dmi_uncore_addr            (dmi_uncore_addr),
        .dmi_uncore_wdata           (dmi_uncore_wdata),
        .dmi_uncore_rdata           (dmi_uncore_rdata),
        .dmi_active                 (dmi_active),

        // ---- Memory export interfaces (ICCM/DCCM/ICache SRAM signals) ----
        .el2_mem_export             (el2_mem_export_if.veer_sram_src),
        .el2_icache_export          (el2_mem_export_if.veer_icache_src)
    );

    // =========================================================================
    // Instantiation 2: AXI Interconnect + UART
    // =========================================================================
    axi_interconnect_uart_top #(
        .DATA_WIDTH                 (DATA_WIDTH),
        .ADDR_WIDTH                 (ADDR_WIDTH),
        .IC_ID_WIDTH                (IC_ID_WIDTH),
        .UART_BASE_ADDR             (UART_BASE_ADDR)
    ) uart_ic_inst (
        .clk                        (clk),
        .rst_n                      (rst_l),      // VeeR rst_l is active-low; same polarity
        .fixed_clk                  (fixed_clk),

        // ---- s00: VeeR LSU (via data-width adapt wires) ----
        .s00_axi_awid               (s00_awid_w),
        .s00_axi_awaddr             (s00_awaddr_w),
        .s00_axi_awlen              (s00_awlen_w),
        .s00_axi_awsize             (s00_awsize_w),
        .s00_axi_awburst            (s00_awburst_w),
        .s00_axi_awlock             (s00_awlock_w),
        .s00_axi_awcache            (s00_awcache_w),
        .s00_axi_awprot             (s00_awprot_w),
        .s00_axi_awqos              (s00_awqos_w),
        .s00_axi_awvalid            (s00_awvalid_w),
        .s00_axi_awready            (s00_awready_w),

        .s00_axi_wdata              (s00_wdata_w),
        .s00_axi_wstrb              (s00_wstrb_w),
        .s00_axi_wlast              (s00_wlast_w),
        .s00_axi_wvalid             (s00_wvalid_w),
        .s00_axi_wready             (s00_wready_w),

        .s00_axi_bid                (s00_bid_w),
        .s00_axi_bresp              (s00_bresp_w),
        .s00_axi_bvalid             (s00_bvalid_w),
        .s00_axi_bready             (s00_bready_w),

        .s00_axi_arid               (s00_arid_w),
        .s00_axi_araddr             (s00_araddr_w),
        .s00_axi_arlen              (s00_arlen_w),
        .s00_axi_arsize             (s00_arsize_w),
        .s00_axi_arburst            (s00_arburst_w),
        .s00_axi_arlock             (s00_arlock_w),
        .s00_axi_arcache            (s00_arcache_w),
        .s00_axi_arprot             (s00_arprot_w),
        .s00_axi_arqos              (s00_arqos_w),
        .s00_axi_arvalid            (s00_arvalid_w),
        .s00_axi_arready            (s00_arready_w),

        .s00_axi_rid                (s00_rid_w),
        .s00_axi_rdata              (s00_rdata_w),
        .s00_axi_rresp              (s00_rresp_w),
        .s00_axi_rlast              (s00_rlast_w),
        .s00_axi_rvalid             (s00_rvalid_w),
        .s00_axi_rready             (s00_rready_w),

        // ---- s01: external secondary AXI4 master ----
        .s01_axi_awid               (s01_axi_awid),
        .s01_axi_awaddr             (s01_axi_awaddr),
        .s01_axi_awlen              (s01_axi_awlen),
        .s01_axi_awsize             (s01_axi_awsize),
        .s01_axi_awburst            (s01_axi_awburst),
        .s01_axi_awlock             (s01_axi_awlock),
        .s01_axi_awcache            (s01_axi_awcache),
        .s01_axi_awprot             (s01_axi_awprot),
        .s01_axi_awqos              (s01_axi_awqos),
        .s01_axi_awvalid            (s01_axi_awvalid),
        .s01_axi_awready            (s01_axi_awready),

        .s01_axi_wdata              (s01_axi_wdata),
        .s01_axi_wstrb              (s01_axi_wstrb),
        .s01_axi_wlast              (s01_axi_wlast),
        .s01_axi_wvalid             (s01_axi_wvalid),
        .s01_axi_wready             (s01_axi_wready),

        .s01_axi_bid                (s01_axi_bid),
        .s01_axi_bresp              (s01_axi_bresp),
        .s01_axi_bvalid             (s01_axi_bvalid),
        .s01_axi_bready             (s01_axi_bready),

        .s01_axi_arid               (s01_axi_arid),
        .s01_axi_araddr             (s01_axi_araddr),
        .s01_axi_arlen              (s01_axi_arlen),
        .s01_axi_arsize             (s01_axi_arsize),
        .s01_axi_arburst            (s01_axi_arburst),
        .s01_axi_arlock             (s01_axi_arlock),
        .s01_axi_arcache            (s01_axi_arcache),
        .s01_axi_arprot             (s01_axi_arprot),
        .s01_axi_arqos              (s01_axi_arqos),
        .s01_axi_arvalid            (s01_axi_arvalid),
        .s01_axi_arready            (s01_axi_arready),

        .s01_axi_rid                (s01_axi_rid),
        .s01_axi_rdata              (s01_axi_rdata),
        .s01_axi_rresp              (s01_axi_rresp),
        .s01_axi_rlast              (s01_axi_rlast),
        .s01_axi_rvalid             (s01_axi_rvalid),
        .s01_axi_rready             (s01_axi_rready),

        // ---- UART physical signals ----
        .uart_tx_o                  (uart_tx_o),
        .uart_rx_i                  (uart_rx_i),
        .uart_read_irq_o            (uart_read_irq_o)
    );

endmodule

`default_nettype wire

// =============================================================================
// Module  : axi_dwidth_converter_64to32
//
// Purpose : AXI4 data-width converter – 64-bit master side to 32-bit slave side.
//
// Scope   : Single-beat MMIO transactions (awlen/arlen == 0).
//           Designed for VeeR EL2 LSU → 32-bit AXI interconnect path.
//
// Features:
//   Write path
//   ----------
//   • awsize clamp  : if master requests size=3 (8 bytes), clamp to size=2
//                     (4 bytes) since the slave bus is 32-bit wide.
//   • Write data    : byte-lane steered by awaddr[2].
//                       awaddr[2]==0  → forward wdata[31:0]  (lower word)
//                       awaddr[2]==1  → forward wdata[63:32] (upper word)
//   • Write strobes : same steering as data.
//   • All other AW / W / B signals pass through unchanged.
//
//   Read path
//   ---------
//   • arsize clamp  : same as awsize clamp.
//   • The 32-bit slave returns rdata[31:0].  This is replicated to both
//     32-bit lanes of the 64-bit rdata bus, so VeeR can read whichever
//     lane it addressed:
//       rdata[31: 0]  = s_rdata[31:0]  (lower lane)
//       rdata[63:32]  = s_rdata[31:0]  (upper lane – same data, VeeR picks
//                                        the correct byte via its byte-enable)
//
//   ID width conversion
//   -------------------
//   • Master IDs (ID_WIDTH_M bits) are truncated to ID_WIDTH_S bits going
//     downstream.  Returned IDs are zero-extended back to ID_WIDTH_M bits.
//
// Parameters:
//   ID_WIDTH_M  – Master-side AXI ID width (e.g. LSU_BUS_TAG = 4)
//   ID_WIDTH_S  – Slave-side  AXI ID width (e.g. IC_ID_WIDTH  = 8)
//   ADDR_WIDTH  – Address width (32)
// =============================================================================
module axi_dwidth_converter_64to32 #(
    parameter ID_WIDTH_M = 4,
    parameter ID_WIDTH_S = 8,
    parameter ADDR_WIDTH = 32
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // -------------------------------------------------------------------------
    // Master side – 64-bit data bus (connects to VeeR EL2 LSU)
    // -------------------------------------------------------------------------
    // Write address channel
    input  wire [ID_WIDTH_M-1:0]    m_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    m_axi_awaddr,
    input  wire [7:0]               m_axi_awlen,
    input  wire [2:0]               m_axi_awsize,
    input  wire [1:0]               m_axi_awburst,
    input  wire                     m_axi_awlock,
    input  wire [3:0]               m_axi_awcache,
    input  wire [2:0]               m_axi_awprot,
    input  wire [3:0]               m_axi_awqos,
    input  wire [3:0]               m_axi_awregion,
    input  wire                     m_axi_awvalid,
    output wire                     m_axi_awready,

    // Write data channel
    input  wire [63:0]              m_axi_wdata,
    input  wire [7:0]               m_axi_wstrb,
    input  wire                     m_axi_wlast,
    input  wire                     m_axi_wvalid,
    output wire                     m_axi_wready,

    // Write response channel
    output wire [ID_WIDTH_M-1:0]    m_axi_bid,
    output wire [1:0]               m_axi_bresp,
    output wire                     m_axi_bvalid,
    input  wire                     m_axi_bready,

    // Read address channel
    input  wire [ID_WIDTH_M-1:0]    m_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    m_axi_araddr,
    input  wire [7:0]               m_axi_arlen,
    input  wire [2:0]               m_axi_arsize,
    input  wire [1:0]               m_axi_arburst,
    input  wire                     m_axi_arlock,
    input  wire [3:0]               m_axi_arcache,
    input  wire [2:0]               m_axi_arprot,
    input  wire [3:0]               m_axi_arqos,
    input  wire [3:0]               m_axi_arregion,
    input  wire                     m_axi_arvalid,
    output wire                     m_axi_arready,

    // Read data channel
    output wire [ID_WIDTH_M-1:0]    m_axi_rid,
    output wire [63:0]              m_axi_rdata,
    output wire [1:0]               m_axi_rresp,
    output wire                     m_axi_rlast,
    output wire                     m_axi_rvalid,
    input  wire                     m_axi_rready,

    // -------------------------------------------------------------------------
    // Slave side – 32-bit data bus (connects to AXI interconnect s00)
    // -------------------------------------------------------------------------
    // Write address channel
    output wire [ID_WIDTH_S-1:0]    s_axi_awid,
    output wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    output wire [7:0]               s_axi_awlen,
    output wire [2:0]               s_axi_awsize,
    output wire [1:0]               s_axi_awburst,
    output wire                     s_axi_awlock,
    output wire [3:0]               s_axi_awcache,
    output wire [2:0]               s_axi_awprot,
    output wire [3:0]               s_axi_awqos,
    output wire                     s_axi_awvalid,
    input  wire                     s_axi_awready,

    // Write data channel
    output wire [31:0]              s_axi_wdata,
    output wire [3:0]               s_axi_wstrb,
    output wire                     s_axi_wlast,
    output wire                     s_axi_wvalid,
    input  wire                     s_axi_wready,

    // Write response channel
    input  wire [ID_WIDTH_S-1:0]    s_axi_bid,
    input  wire [1:0]               s_axi_bresp,
    input  wire                     s_axi_bvalid,
    output wire                     s_axi_bready,

    // Read address channel
    output wire [ID_WIDTH_S-1:0]    s_axi_arid,
    output wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    output wire [7:0]               s_axi_arlen,
    output wire [2:0]               s_axi_arsize,
    output wire [1:0]               s_axi_arburst,
    output wire                     s_axi_arlock,
    output wire [3:0]               s_axi_arcache,
    output wire [2:0]               s_axi_arprot,
    output wire [3:0]               s_axi_arqos,
    output wire                     s_axi_arvalid,
    input  wire                     s_axi_arready,

    // Read data channel
    input  wire [ID_WIDTH_S-1:0]    s_axi_rid,
    input  wire [31:0]              s_axi_rdata,
    input  wire [1:0]               s_axi_rresp,
    input  wire                     s_axi_rlast,
    input  wire                     s_axi_rvalid,
    output wire                     s_axi_rready
);

    // =========================================================================
    // Internal: latch awaddr[2] and araddr[2] in AW/AR acceptance registers
    // so the W-channel and R-channel can use the correct byte lane.
    // This covers the single-beat (awlen=0) MMIO case used by VeeR for UART.
    // =========================================================================

    // -- Write: capture lane select at AW handshake --
    reg         aw_lane_r;      // 0 → lower word, 1 → upper word
    reg         aw_pending_r;   // beats are in-flight

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_lane_r    <= 1'b0;
            aw_pending_r <= 1'b0;
        end else begin
            if (m_axi_awvalid && s_axi_awready && !aw_pending_r) begin
                aw_lane_r    <= m_axi_awaddr[2];
                aw_pending_r <= 1'b1;
            end
            // clear after write-data accepted
            if (aw_pending_r && m_axi_wvalid && s_axi_wready && m_axi_wlast)
                aw_pending_r <= 1'b0;
        end
    end

    // Use captured lane once pending, else use live awaddr[2]
    wire aw_lane = aw_pending_r ? aw_lane_r : m_axi_awaddr[2];

    // -- Read: capture lane select at AR handshake --
    reg         ar_lane_r;
    reg         ar_pending_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_lane_r    <= 1'b0;
            ar_pending_r <= 1'b0;
        end else begin
            if (m_axi_arvalid && s_axi_arready && !ar_pending_r) begin
                ar_lane_r    <= m_axi_araddr[2];
                ar_pending_r <= 1'b1;
            end
            // clear after read-data accepted
            if (ar_pending_r && s_axi_rvalid && m_axi_rready && s_axi_rlast)
                ar_pending_r <= 1'b0;
        end
    end

    wire ar_lane = ar_pending_r ? ar_lane_r : m_axi_araddr[2];

    // =========================================================================
    // Write address channel – pass through with ID truncation + size clamp
    // =========================================================================
    // Clamp size: 3'b011 (8 bytes, 64-bit) → 3'b010 (4 bytes, 32-bit)
    wire [2:0] aw_size_clamped = (m_axi_awsize == 3'b011) ? 3'b010 : m_axi_awsize;
    wire [2:0] ar_size_clamped = (m_axi_arsize == 3'b011) ? 3'b010 : m_axi_arsize;

    // ID truncation: take lower ID_WIDTH_S bits (or zero-pad if M < S)
    // Handles both M wider-than-S and M narrower-than-S safely.
    generate
        if (ID_WIDTH_M >= ID_WIDTH_S) begin : id_trunc
            assign s_axi_awid = m_axi_awid[ID_WIDTH_S-1:0];
            assign s_axi_arid = m_axi_arid[ID_WIDTH_S-1:0];
        end else begin : id_pad
            assign s_axi_awid = {{(ID_WIDTH_S-ID_WIDTH_M){1'b0}}, m_axi_awid};
            assign s_axi_arid = {{(ID_WIDTH_S-ID_WIDTH_M){1'b0}}, m_axi_arid};
        end
    endgenerate

    assign s_axi_awaddr   = m_axi_awaddr;
    assign s_axi_awlen    = m_axi_awlen;
    assign s_axi_awsize   = aw_size_clamped;
    assign s_axi_awburst  = m_axi_awburst;
    assign s_axi_awlock   = m_axi_awlock;
    assign s_axi_awcache  = m_axi_awcache;
    assign s_axi_awprot   = m_axi_awprot;
    assign s_axi_awqos    = m_axi_awqos;
    assign s_axi_awvalid  = m_axi_awvalid;
    assign m_axi_awready  = s_axi_awready;

    // =========================================================================
    // Write data channel – byte-lane steer using aw_lane
    // =========================================================================
    // aw_lane==0 : VeeR is writing to lower 32-bit word (addr[2]==0)
    // aw_lane==1 : VeeR is writing to upper 32-bit word (addr[2]==1)
    assign s_axi_wdata  = aw_lane ? m_axi_wdata[63:32] : m_axi_wdata[31:0];
    assign s_axi_wstrb  = aw_lane ? m_axi_wstrb[7:4]   : m_axi_wstrb[3:0];
    assign s_axi_wlast  = m_axi_wlast;
    assign s_axi_wvalid = m_axi_wvalid;
    assign m_axi_wready = s_axi_wready;

    // =========================================================================
    // Write response channel – zero-extend slave ID back to master width
    // =========================================================================
    generate
        if (ID_WIDTH_M >= ID_WIDTH_S) begin : bid_extend
            assign m_axi_bid = {{(ID_WIDTH_M-ID_WIDTH_S){1'b0}}, s_axi_bid};
        end else begin : bid_trunc
            assign m_axi_bid = s_axi_bid[ID_WIDTH_M-1:0];
        end
    endgenerate

    assign m_axi_bresp  = s_axi_bresp;
    assign m_axi_bvalid = s_axi_bvalid;
    assign s_axi_bready = m_axi_bready;

    // =========================================================================
    // Read address channel – pass through with ID truncation + size clamp
    // =========================================================================
    assign s_axi_araddr   = m_axi_araddr;
    assign s_axi_arlen    = m_axi_arlen;
    assign s_axi_arsize   = ar_size_clamped;
    assign s_axi_arburst  = m_axi_arburst;
    assign s_axi_arlock   = m_axi_arlock;
    assign s_axi_arcache  = m_axi_arcache;
    assign s_axi_arprot   = m_axi_arprot;
    assign s_axi_arqos    = m_axi_arqos;
    assign s_axi_arvalid  = m_axi_arvalid;
    assign m_axi_arready  = s_axi_arready;

    // =========================================================================
    // Read data channel – replicate 32-bit slave data to both 64-bit lanes
    // =========================================================================
    // VeeR will use its internal byte-enable to extract the correct bytes from
    // whichever 32-bit lane it addressed.  Replicating to both lanes ensures
    // it always finds valid data regardless of which lane it targets.
    generate
        if (ID_WIDTH_M >= ID_WIDTH_S) begin : rid_extend
            assign m_axi_rid = {{(ID_WIDTH_M-ID_WIDTH_S){1'b0}}, s_axi_rid};
        end else begin : rid_trunc
            assign m_axi_rid = s_axi_rid[ID_WIDTH_M-1:0];
        end
    endgenerate

    assign m_axi_rdata  = {s_axi_rdata, s_axi_rdata};  // replicate to both lanes
    assign m_axi_rresp  = s_axi_rresp;
    assign m_axi_rlast  = s_axi_rlast;
    assign m_axi_rvalid = s_axi_rvalid;
    assign s_axi_rready = m_axi_rready;

endmodule

`default_nettype wire
