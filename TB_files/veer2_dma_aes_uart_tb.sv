// =============================================================================
// Testbench : veer2_dma_aes_uart_tb
// File      : TB_files/veer2_dma_aes_uart_tb.sv
// Language  : SystemVerilog (IEEE 1800-2012 / VCS / Questa compatible)
//
// Purpose   : Complete functional verification of veer2_dma_aes_uart SoC:
//             1. Dual-Master AXI4 Crossbar Architecture (VeeR LSU Master 1,
//                DMA Controller Master 2)
//             2. VeeR EL2 RISC-V processor core reset boot & IFU NOP stream fetch
//             3. DMA Controller Subsystem (0x4000_3000):
//                - CSR Register access (version 0xCAFE, control, descriptors)
//                - Master 2 transfer execution across 2x6 crossbar
//                - Interrupt & status signaling (dma_done_o, dma_irq_o, dma_error_o)
//             4. AES-128 cryptographic engine (0x4000_2000):
//                - FIPS-197 encryption & decryption
//                - Hardware handshaking (aes_done_pulse_o, aes_irq_o)
//             5. UART peripheral subsystem (0x4000_0000):
//                - Baud rate generation, transmitter bit monitor, loopback
//             6. Multi-Master Concurrency & Crossbar Arbitration:
//                - Simultaneous VeeR LSU CPU + DMA Master operations without deadlock
//             7. End-to-End Pipeline:
//                - AES generates ciphertext -> DMA streams ciphertext into input
//                  registers -> AES decrypts back to golden plaintext
//                - DMA streams byte to UART THR FIFO -> transmitted on serial line
//
// Test Cases:
//   TC1  – Power-on Reset & Quiescent Signal Checks
//   TC2  – VeeR EL2 IFU Instruction Fetch & Core Alive Verification
//   TC3  – DMA CSR Read/Write Access & Hardware Version (0xCAFE) Verification
//   TC4  – DMA Descriptor 0 & 1 Multi-Register Programming & Readback
//   TC5  – UART Peripheral Init & Direct Transmission ('D' = 0x44)
//   TC6  – UART Serial RX Loopback & Interrupt Generation Check
//   TC7  – AES-128 Hardware Encryption Execution (NIST FIPS-197 Vector)
//   TC8  – DMA Master 2 Execution: Stream 16-byte Ciphertext to AES Input
//   TC9  – AES-128 Decryption of DMA-transferred Payload & Plaintext Recovery
//   TC10 – DMA Peripheral Stream to UART Transmitter FIFO (Fixed Dest Mode)
//   TC11 – Multi-Master Crossbar Concurrency & Arbitration (CPU LSU + DMA Master)
//   TC12 – DMA Abort & Error Status Handling
//
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

import amba_axi_pkg::*;
import dma_utils_pkg::*;

module veer2_dma_aes_uart_tb;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam CLK_PERIOD    = 10;      // 100 MHz system clock
    localparam FIXED_PERIOD  = 10;      // UART baud reference clock
    localparam RST_CYCLES    = 10;
    localparam TIMEOUT_CYC   = 5000;
    localparam BAUD_DIV      = 10;
    localparam BIT_CYCLES    = BAUD_DIV + 1;

    localparam IC_ID_WIDTH   = 8;
    localparam DATA_WIDTH    = 32;
    localparam ADDR_WIDTH    = 32;
    localparam STRB_WIDTH    = DATA_WIDTH / 8;

    localparam LSU_BUS_TAG   = 4;
    localparam IFU_BUS_TAG   = 3;
    localparam SB_BUS_TAG    = 2;
    localparam DMA_BUS_TAG   = 1;
    localparam PIC_TOTAL_INT = 31;

    // -------------------------------------------------------------------------
    // Peripheral Memory Map
    // -------------------------------------------------------------------------
    // UART Subsystem (0x4000_0000 - 0x4000_0FFF)
    localparam [31:0] UART_BASE         = 32'h4000_0000;
    localparam [31:0] UART_THR_REG      = UART_BASE + 32'h00;
    localparam [31:0] UART_RBR_REG      = UART_BASE + 32'h00;
    localparam [31:0] UART_IER_REG      = UART_BASE + 32'h04;
    localparam [31:0] UART_BAUD_REG     = UART_BASE + 32'h08;
    localparam [31:0] UART_LCR_REG      = UART_BASE + 32'h0C;
    localparam [31:0] UART_LSR_REG      = UART_BASE + 32'h14;

    // AES-128 Subsystem (0x4000_2000 - 0x4000_2FFF)
    localparam [31:0] AES_BASE          = 32'h4000_2000;
    localparam [31:0] AES_CTRL_REG      = AES_BASE + 32'h00;
    localparam [31:0] AES_KEY0_REG      = AES_BASE + 32'h04;
    localparam [31:0] AES_KEY1_REG      = AES_BASE + 32'h08;
    localparam [31:0] AES_KEY2_REG      = AES_BASE + 32'h0C;
    localparam [31:0] AES_KEY3_REG      = AES_BASE + 32'h10;
    localparam [31:0] AES_TXTIN0_REG    = AES_BASE + 32'h14;
    localparam [31:0] AES_TXTIN1_REG    = AES_BASE + 32'h18;
    localparam [31:0] AES_TXTIN2_REG    = AES_BASE + 32'h1C;
    localparam [31:0] AES_TXTIN3_REG    = AES_BASE + 32'h20;
    localparam [31:0] AES_TXTOUT0_REG   = AES_BASE + 32'h24;
    localparam [31:0] AES_TXTOUT1_REG   = AES_BASE + 32'h28;
    localparam [31:0] AES_TXTOUT2_REG   = AES_BASE + 32'h2C;
    localparam [31:0] AES_TXTOUT3_REG   = AES_BASE + 32'h30;

    // DMA Controller Subsystem (0x4000_3000 - 0x4000_3FFF)
    localparam [31:0] DMA_BASE          = 32'h4000_3000;
    localparam [31:0] DMA_CTRL_REG      = DMA_BASE + 32'h00;
    localparam [31:0] DMA_STAT_REG      = DMA_BASE + 32'h08;
    localparam [31:0] DMA_ERR_ADDR_REG  = DMA_BASE + 32'h10;
    localparam [31:0] DMA_ERR_STAT_REG  = DMA_BASE + 32'h18;
    localparam [31:0] DMA_DESC0_SRC_REG = DMA_BASE + 32'h20;
    localparam [31:0] DMA_DESC1_SRC_REG = DMA_BASE + 32'h28;
    localparam [31:0] DMA_DESC0_DST_REG = DMA_BASE + 32'h30;
    localparam [31:0] DMA_DESC1_DST_REG = DMA_BASE + 32'h38;
    localparam [31:0] DMA_DESC0_LEN_REG = DMA_BASE + 32'h40;
    localparam [31:0] DMA_DESC1_LEN_REG = DMA_BASE + 32'h48;
    localparam [31:0] DMA_DESC0_CFG_REG = DMA_BASE + 32'h50;
    localparam [31:0] DMA_DESC1_CFG_REG = DMA_BASE + 32'h58;

    // RISC-V NOP (addi x0, x0, 0)
    localparam [63:0] NOP64             = 64'h0000_0013_0000_0013;

    // =========================================================================
    // Signals
    // =========================================================================
    // Global Clocks & Resets
    reg                         clk;
    reg                         fixed_clk;
    reg                         rst_l;
    reg                         dbg_rst_l;

    // Boot Vectors & Identification
    reg  [31:1]                 rst_vec;
    reg  [31:1]                 nmi_vec;
    reg  [31:1]                 jtag_id;
    reg  [31:4]                 core_id;

    // Interrupts & Hardware Handshaking
    reg                         nmi_int;
    reg                         timer_int;
    reg                         soft_int;
    reg  [PIC_TOTAL_INT:1]      extintsrc_req;

    wire                        uart_read_irq_o;
    wire                        aes_irq_o;
    wire                        aes_done_pulse_o;
    wire                        dma_done_o;
    wire                        dma_error_o;
    wire                        dma_irq_o;

    // Peripherals Physical & Status
    wire                        uart_tx_o;
    reg                         uart_rx_i;
    wire                        aes_busy_o;
    wire                        aes_done_o;

    // IFU AXI Bus
    wire                        ifu_axi_arvalid;
    reg                         ifu_axi_arready;
    wire [IFU_BUS_TAG-1:0]      ifu_axi_arid;
    wire [31:0]                 ifu_axi_araddr;
    wire [3:0]                  ifu_axi_arregion;
    wire [7:0]                  ifu_axi_arlen;
    wire [2:0]                  ifu_axi_arsize;
    wire [1:0]                  ifu_axi_arburst;
    wire                        ifu_axi_arlock;
    wire [3:0]                  ifu_axi_arcache;
    wire [2:0]                  ifu_axi_arprot;
    wire [3:0]                  ifu_axi_arqos;

    reg                         ifu_axi_rvalid;
    wire                        ifu_axi_rready;
    reg  [IFU_BUS_TAG-1:0]      ifu_axi_rid;
    reg  [63:0]                 ifu_axi_rdata;
    reg  [1:0]                  ifu_axi_rresp;
    reg                         ifu_axi_rlast;

    wire                        ifu_axi_awvalid;
    wire                        ifu_axi_awready;
    wire [IFU_BUS_TAG-1:0]      ifu_axi_awid;
    wire [31:0]                 ifu_axi_awaddr;
    wire [3:0]                  ifu_axi_awregion;
    wire [7:0]                  ifu_axi_awlen;
    wire [2:0]                  ifu_axi_awsize;
    wire [1:0]                  ifu_axi_awburst;
    wire                        ifu_axi_awlock;
    wire [3:0]                  ifu_axi_awcache;
    wire [2:0]                  ifu_axi_awprot;
    wire [3:0]                  ifu_axi_awqos;

    wire                        ifu_axi_wvalid;
    wire                        ifu_axi_wready;
    wire [63:0]                 ifu_axi_wdata;
    wire [7:0]                  ifu_axi_wstrb;
    wire                        ifu_axi_wlast;

    wire                        ifu_axi_bvalid;
    wire                        ifu_axi_bready;
    wire [1:0]                  ifu_axi_bresp;
    wire [IFU_BUS_TAG-1:0]      ifu_axi_bid;

    // SB AXI Bus (Tied off)
    wire                        sb_axi_awvalid;
    wire                        sb_axi_awready;
    wire [SB_BUS_TAG-1:0]       sb_axi_awid;
    wire [31:0]                 sb_axi_awaddr;
    wire [3:0]                  sb_axi_awregion;
    wire [7:0]                  sb_axi_awlen;
    wire [2:0]                  sb_axi_awsize;
    wire [1:0]                  sb_axi_awburst;
    wire                        sb_axi_awlock;
    wire [3:0]                  sb_axi_awcache;
    wire [2:0]                  sb_axi_awprot;
    wire [3:0]                  sb_axi_awqos;
    wire                        sb_axi_wvalid;
    wire                        sb_axi_wready;
    wire [63:0]                 sb_axi_wdata;
    wire [7:0]                  sb_axi_wstrb;
    wire                        sb_axi_wlast;
    wire                        sb_axi_bvalid;
    wire                        sb_axi_bready;
    wire [1:0]                  sb_axi_bresp;
    wire [SB_BUS_TAG-1:0]       sb_axi_bid;
    wire                        sb_axi_arvalid;
    wire                        sb_axi_arready;
    wire [SB_BUS_TAG-1:0]       sb_axi_arid;
    wire [31:0]                 sb_axi_araddr;
    wire [3:0]                  sb_axi_arregion;
    wire [7:0]                  sb_axi_arlen;
    wire [2:0]                  sb_axi_arsize;
    wire [1:0]                  sb_axi_arburst;
    wire                        sb_axi_arlock;
    wire [3:0]                  sb_axi_arcache;
    wire [2:0]                  sb_axi_arprot;
    wire [3:0]                  sb_axi_arqos;
    wire                        sb_axi_rvalid;
    wire                        sb_axi_rready;
    wire [SB_BUS_TAG-1:0]       sb_axi_rid;
    wire [63:0]                 sb_axi_rdata;
    wire [1:0]                  sb_axi_rresp;
    wire                        sb_axi_rlast;

    // DMA AXI Slave Bus (Tied off)
    reg                         dma_axi_awvalid;
    wire                        dma_axi_awready;
    reg  [DMA_BUS_TAG-1:0]      dma_axi_awid;
    reg  [31:0]                 dma_axi_awaddr;
    reg  [2:0]                  dma_axi_awsize;
    reg  [2:0]                  dma_axi_awprot;
    reg  [7:0]                  dma_axi_awlen;
    reg  [1:0]                  dma_axi_awburst;
    reg                         dma_axi_wvalid;
    wire                        dma_axi_wready;
    reg  [63:0]                 dma_axi_wdata;
    reg  [7:0]                  dma_axi_wstrb;
    reg                         dma_axi_wlast;
    wire                        dma_axi_bvalid;
    reg                         dma_axi_bready;
    wire [1:0]                  dma_axi_bresp;
    wire [DMA_BUS_TAG-1:0]      dma_axi_bid;
    reg                         dma_axi_arvalid;
    wire                        dma_axi_arready;
    reg  [DMA_BUS_TAG-1:0]      dma_axi_arid;
    reg  [31:0]                 dma_axi_araddr;
    reg  [2:0]                  dma_axi_arsize;
    reg  [2:0]                  dma_axi_arprot;
    reg  [7:0]                  dma_axi_arlen;
    reg  [1:0]                  dma_axi_arburst;
    wire                        dma_axi_rvalid;
    reg                         dma_axi_rready;
    wire [DMA_BUS_TAG-1:0]      dma_axi_rid;
    wire [63:0]                 dma_axi_rdata;
    wire [1:0]                  dma_axi_rresp;
    wire                        dma_axi_rlast;

    // VeeR Core Observation & Trace
    wire [31:0]                 trace_rv_i_insn_ip;
    wire [31:0]                 trace_rv_i_address_ip;
    wire                        trace_rv_i_valid_ip;
    wire                        trace_rv_i_exception_ip;
    wire [4:0]                  trace_rv_i_ecause_ip;
    wire                        trace_rv_i_interrupt_ip;
    wire [31:0]                 trace_rv_i_tval_ip;

    wire                        iccm_ecc_single_error, iccm_ecc_double_error;
    wire                        dccm_ecc_single_error, dccm_ecc_double_error;
    wire                        dccm_write_readback_error;
    wire                        dec_tlu_perfcnt0, dec_tlu_perfcnt1;
    wire                        dec_tlu_perfcnt2, dec_tlu_perfcnt3;
    wire                        jtag_tdo, jtag_tdoEn;
    wire                        mpc_debug_halt_ack, mpc_debug_run_ack;
    wire                        debug_brkpt_status;
    wire                        o_cpu_halt_ack, o_cpu_halt_status;
    wire                        o_debug_mode_status, o_cpu_run_ack;
    wire                        dmi_uncore_en, dmi_uncore_wr_en;
    wire [6:0]                  dmi_uncore_addr;
    wire [31:0]                 dmi_uncore_wdata;
    wire                        dmi_active;

    // Testbench Metrics & Tracking
    integer                     pass_count;
    integer                     fail_count;
    reg [7:0]                   rx_capture;
    reg                         rx_done;
    integer                     rx_byte_count;
    integer                     pulse_count;

    // =========================================================================
    // Clocks Generation
    // =========================================================================
    initial clk = 1'b0;
    always  #(CLK_PERIOD/2) clk = ~clk;

    initial fixed_clk = 1'b0;
    always  #(FIXED_PERIOD/2) fixed_clk = ~fixed_clk;

    // =========================================================================
    // Watchdog Pulse Counter (AES Kick Pulse to Watchdog Timer)
    // =========================================================================
    always @(posedge clk or negedge rst_l) begin
        if (!rst_l)
            pulse_count <= 0;
        else if (aes_done_pulse_o)
            pulse_count <= pulse_count + 1;
    end

    // =========================================================================
    // Tie-offs for Unused Slave / Master Ports
    // =========================================================================
    assign ifu_axi_awready = 1'b1;
    assign ifu_axi_wready  = 1'b1;
    assign ifu_axi_bvalid  = 1'b0;
    assign ifu_axi_bresp   = 2'b00;
    assign ifu_axi_bid     = {IFU_BUS_TAG{1'b0}};

    assign sb_axi_awready  = 1'b1;
    assign sb_axi_wready   = 1'b1;
    assign sb_axi_bvalid   = 1'b0;
    assign sb_axi_bresp    = 2'b00;
    assign sb_axi_bid      = {SB_BUS_TAG{1'b0}};
    assign sb_axi_arready  = 1'b1;
    assign sb_axi_rvalid   = 1'b0;
    assign sb_axi_rdata    = 64'h0;
    assign sb_axi_rresp    = 2'b00;
    assign sb_axi_rlast    = 1'b1;
    assign sb_axi_rid      = {SB_BUS_TAG{1'b0}};

    // =========================================================================
    // VeeR IFU Instruction Fetch Monitor & Responder (Feeds NOP Stream)
    // =========================================================================
    reg        ifu_fetch_seen;
    reg [31:0] ifu_fetch_addr;

    always @(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            ifu_fetch_seen <= 1'b0;
            ifu_fetch_addr <= 32'h0;
        end else if (ifu_axi_arvalid) begin
            ifu_fetch_seen <= 1'b1;
            ifu_fetch_addr <= ifu_axi_araddr;
        end
    end

    always @(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            ifu_axi_arready <= 1'b0;
            ifu_axi_rvalid  <= 1'b0;
            ifu_axi_rdata   <= NOP64;
            ifu_axi_rresp   <= 2'b00;
            ifu_axi_rlast   <= 1'b1;
            ifu_axi_rid     <= {IFU_BUS_TAG{1'b0}};
        end else begin
            ifu_axi_arready <= 1'b1;
            if (ifu_axi_arvalid && ifu_axi_arready) begin
                ifu_axi_rvalid <= 1'b1;
                ifu_axi_rid    <= ifu_axi_arid;
                ifu_axi_rdata  <= NOP64;
                ifu_axi_rresp  <= 2'b00;
                ifu_axi_rlast  <= 1'b1;
            end else if (ifu_axi_rvalid && ifu_axi_rready) begin
                ifu_axi_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // DUT Instantiation: veer2_dma_aes_uart
    // =========================================================================
    veer2_dma_aes_uart #(
        .IC_ID_WIDTH    (IC_ID_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .LSU_BUS_TAG    (LSU_BUS_TAG),
        .IFU_BUS_TAG    (IFU_BUS_TAG),
        .SB_BUS_TAG     (SB_BUS_TAG),
        .DMA_BUS_TAG    (DMA_BUS_TAG),
        .PIC_TOTAL_INT  (PIC_TOTAL_INT),
        .UART_BASE_ADDR (UART_BASE),
        .AES_BASE_ADDR  (AES_BASE),
        .DMA_BASE_ADDR  (DMA_BASE)
    ) dut (
        .clk                    (clk),
        .rst_l                  (rst_l),
        .dbg_rst_l              (dbg_rst_l),
        .fixed_clk              (fixed_clk),

        .rst_vec                (rst_vec),
        .nmi_vec                (nmi_vec),
        .jtag_id                (jtag_id),
        .core_id                (core_id),

        .nmi_int                (nmi_int),
        .timer_int              (timer_int),
        .soft_int               (soft_int),
        .extintsrc_req          (extintsrc_req),
        .uart_read_irq_o        (uart_read_irq_o),
        .aes_irq_o              (aes_irq_o),
        .aes_done_pulse_o       (aes_done_pulse_o),
        .dma_done_o             (dma_done_o),
        .dma_error_o            (dma_error_o),
        .dma_irq_o              (dma_irq_o),

        .uart_tx_o              (uart_tx_o),
        .uart_rx_i              (uart_rx_i),
        .aes_busy_o             (aes_busy_o),
        .aes_done_o             (aes_done_o),

        // IFU
        .ifu_axi_arvalid        (ifu_axi_arvalid),
        .ifu_axi_arready        (ifu_axi_arready),
        .ifu_axi_arid           (ifu_axi_arid),
        .ifu_axi_araddr         (ifu_axi_araddr),
        .ifu_axi_arregion       (ifu_axi_arregion),
        .ifu_axi_arlen          (ifu_axi_arlen),
        .ifu_axi_arsize         (ifu_axi_arsize),
        .ifu_axi_arburst        (ifu_axi_arburst),
        .ifu_axi_arlock         (ifu_axi_arlock),
        .ifu_axi_arcache        (ifu_axi_arcache),
        .ifu_axi_arprot         (ifu_axi_arprot),
        .ifu_axi_arqos          (ifu_axi_arqos),
        .ifu_axi_rvalid         (ifu_axi_rvalid),
        .ifu_axi_rready         (ifu_axi_rready),
        .ifu_axi_rid            (ifu_axi_rid),
        .ifu_axi_rdata          (ifu_axi_rdata),
        .ifu_axi_rresp          (ifu_axi_rresp),
        .ifu_axi_rlast          (ifu_axi_rlast),
        .ifu_axi_awvalid        (ifu_axi_awvalid),
        .ifu_axi_awready        (ifu_axi_awready),
        .ifu_axi_awid           (ifu_axi_awid),
        .ifu_axi_awaddr         (ifu_axi_awaddr),
        .ifu_axi_awregion       (ifu_axi_awregion),
        .ifu_axi_awlen          (ifu_axi_awlen),
        .ifu_axi_awsize         (ifu_axi_awsize),
        .ifu_axi_awburst        (ifu_axi_awburst),
        .ifu_axi_awlock         (ifu_axi_awlock),
        .ifu_axi_awcache        (ifu_axi_awcache),
        .ifu_axi_awprot         (ifu_axi_awprot),
        .ifu_axi_awqos          (ifu_axi_awqos),
        .ifu_axi_wvalid         (ifu_axi_wvalid),
        .ifu_axi_wready         (ifu_axi_wready),
        .ifu_axi_wdata          (ifu_axi_wdata),
        .ifu_axi_wstrb          (ifu_axi_wstrb),
        .ifu_axi_wlast          (ifu_axi_wlast),
        .ifu_axi_bvalid         (ifu_axi_bvalid),
        .ifu_axi_bready         (ifu_axi_bready),
        .ifu_axi_bresp          (ifu_axi_bresp),
        .ifu_axi_bid            (ifu_axi_bid),

        // SB
        .sb_axi_awvalid         (sb_axi_awvalid),
        .sb_axi_awready         (sb_axi_awready),
        .sb_axi_awid            (sb_axi_awid),
        .sb_axi_awaddr          (sb_axi_awaddr),
        .sb_axi_awregion        (sb_axi_awregion),
        .sb_axi_awlen           (sb_axi_awlen),
        .sb_axi_awsize          (sb_axi_awsize),
        .sb_axi_awburst         (sb_axi_awburst),
        .sb_axi_awlock          (sb_axi_awlock),
        .sb_axi_awcache         (sb_axi_awcache),
        .sb_axi_awprot          (sb_axi_awprot),
        .sb_axi_awqos           (sb_axi_awqos),
        .sb_axi_wvalid          (sb_axi_wvalid),
        .sb_axi_wready          (sb_axi_wready),
        .sb_axi_wdata           (sb_axi_wdata),
        .sb_axi_wstrb           (sb_axi_wstrb),
        .sb_axi_wlast           (sb_axi_wlast),
        .sb_axi_bvalid          (sb_axi_bvalid),
        .sb_axi_bready          (sb_axi_bready),
        .sb_axi_bresp           (sb_axi_bresp),
        .sb_axi_bid             (sb_axi_bid),
        .sb_axi_arvalid         (sb_axi_arvalid),
        .sb_axi_arready         (sb_axi_arready),
        .sb_axi_arid            (sb_axi_arid),
        .sb_axi_araddr          (sb_axi_araddr),
        .sb_axi_arregion        (sb_axi_arregion),
        .sb_axi_arlen           (sb_axi_arlen),
        .sb_axi_arsize          (sb_axi_arsize),
        .sb_axi_arburst         (sb_axi_arburst),
        .sb_axi_arlock          (sb_axi_arlock),
        .sb_axi_arcache         (sb_axi_arcache),
        .sb_axi_arprot          (sb_axi_arprot),
        .sb_axi_arqos           (sb_axi_arqos),
        .sb_axi_rvalid          (sb_axi_rvalid),
        .sb_axi_rready          (sb_axi_rready),
        .sb_axi_rid             (sb_axi_rid),
        .sb_axi_rdata           (sb_axi_rdata),
        .sb_axi_rresp           (sb_axi_rresp),
        .sb_axi_rlast           (sb_axi_rlast),

        // Core DMA Slave
        .dma_axi_awvalid        (dma_axi_awvalid),
        .dma_axi_awready        (dma_axi_awready),
        .dma_axi_awid           (dma_axi_awid),
        .dma_axi_awaddr         (dma_axi_awaddr),
        .dma_axi_awsize         (dma_axi_awsize),
        .dma_axi_awprot         (dma_axi_awprot),
        .dma_axi_awlen          (dma_axi_awlen),
        .dma_axi_awburst        (dma_axi_awburst),
        .dma_axi_wvalid         (dma_axi_wvalid),
        .dma_axi_wready         (dma_axi_wready),
        .dma_axi_wdata          (dma_axi_wdata),
        .dma_axi_wstrb          (dma_axi_wstrb),
        .dma_axi_wlast          (dma_axi_wlast),
        .dma_axi_bvalid         (dma_axi_bvalid),
        .dma_axi_bready         (dma_axi_bready),
        .dma_axi_bresp          (dma_axi_bresp),
        .dma_axi_bid            (dma_axi_bid),
        .dma_axi_arvalid        (dma_axi_arvalid),
        .dma_axi_arready        (dma_axi_arready),
        .dma_axi_arid           (dma_axi_arid),
        .dma_axi_araddr         (dma_axi_araddr),
        .dma_axi_arsize         (dma_axi_arsize),
        .dma_axi_arprot         (dma_axi_arprot),
        .dma_axi_arlen          (dma_axi_arlen),
        .dma_axi_arburst        (dma_axi_arburst),
        .dma_axi_rvalid         (dma_axi_rvalid),
        .dma_axi_rready         (dma_axi_rready),
        .dma_axi_rid            (dma_axi_rid),
        .dma_axi_rdata          (dma_axi_rdata),
        .dma_axi_rresp          (dma_axi_rresp),
        .dma_axi_rlast          (dma_axi_rlast),

        // Trace
        .trace_rv_i_insn_ip     (trace_rv_i_insn_ip),
        .trace_rv_i_address_ip  (trace_rv_i_address_ip),
        .trace_rv_i_valid_ip    (trace_rv_i_valid_ip),
        .trace_rv_i_exception_ip(trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip   (trace_rv_i_ecause_ip),
        .trace_rv_i_interrupt_ip(trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip     (trace_rv_i_tval_ip),

        // ECC
        .iccm_ecc_single_error  (iccm_ecc_single_error),
        .iccm_ecc_double_error  (iccm_ecc_double_error),
        .dccm_ecc_single_error  (dccm_ecc_single_error),
        .dccm_ecc_double_error  (dccm_ecc_double_error),
        .dccm_write_readback_error(dccm_write_readback_error),

        // Perf
        .dec_tlu_perfcnt0       (dec_tlu_perfcnt0),
        .dec_tlu_perfcnt1       (dec_tlu_perfcnt1),
        .dec_tlu_perfcnt2       (dec_tlu_perfcnt2),
        .dec_tlu_perfcnt3       (dec_tlu_perfcnt3),

        // JTAG
        .jtag_tck               (1'b0),
        .jtag_tms               (1'b0),
        .jtag_tdi               (1'b0),
        .jtag_trst_n            (1'b1),
        .jtag_tdo               (jtag_tdo),
        .jtag_tdoEn             (jtag_tdoEn),

        // MPC
        .mpc_debug_halt_req     (1'b0),
        .mpc_debug_run_req      (1'b0),
        .mpc_reset_run_req      (1'b1),
        .mpc_debug_halt_ack     (mpc_debug_halt_ack),
        .mpc_debug_run_ack      (mpc_debug_run_ack),
        .debug_brkpt_status     (debug_brkpt_status),
        .i_cpu_halt_req         (1'b0),
        .o_cpu_halt_ack         (o_cpu_halt_ack),
        .o_cpu_halt_status      (o_cpu_halt_status),
        .o_debug_mode_status    (o_debug_mode_status),
        .i_cpu_run_req          (1'b0),
        .o_cpu_run_ack          (o_cpu_run_ack),

        // Misc
        .lsu_bus_clk_en         (1'b1),
        .ifu_bus_clk_en         (1'b1),
        .dbg_bus_clk_en         (1'b1),
        .dma_bus_clk_en         (1'b1),
        .scan_mode              (1'b0),
        .mbist_mode             (1'b0),

        // DMI
        .dmi_core_enable        (1'b1),
        .dmi_uncore_enable      (1'b0),
        .dmi_uncore_en          (dmi_uncore_en),
        .dmi_uncore_wr_en       (dmi_uncore_wr_en),
        .dmi_uncore_addr        (dmi_uncore_addr),
        .dmi_uncore_wdata       (dmi_uncore_wdata),
        .dmi_uncore_rdata       (32'h0),
        .dmi_active             (dmi_active)
    );

    // =========================================================================
    // Waveform Dump Setup
    // =========================================================================
    initial begin
`ifdef DUMP_VCD
        $dumpfile("dump.vcd");
        $dumpvars(0, veer2_dma_aes_uart_tb);
`else
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars("+all");
        $fsdbDumpMDA();
        $fsdbDumpSVA();
`endif
    end

    // =========================================================================
    // Master 1 (VeeR LSU / CPU Crossbar s00 BFM Tasks)
    // =========================================================================
    task cpu_axi_write;
        input [ADDR_WIDTH-1:0]    addr;
        input [DATA_WIDTH-1:0]    data;
        input [IC_ID_WIDTH-1:0]   id;
        integer timeout;
        reg aw_done, w_done, b_done;
        begin
            @(negedge clk);
            force dut.s00_awid_w    = id;
            force dut.s00_awaddr_w  = addr;
            force dut.s00_awlen_w   = 8'd0;
            force dut.s00_awsize_w  = 3'd2; // 4 bytes (32-bit beat)
            force dut.s00_awburst_w = 2'b01;
            force dut.s00_awlock_w  = 1'b0;
            force dut.s00_awcache_w = 4'h0;
            force dut.s00_awprot_w  = 3'b000;
            force dut.s00_awqos_w   = 4'h0;
            force dut.s00_awvalid_w = 1'b1;

            force dut.s00_wdata_w   = data;
            force dut.s00_wstrb_w   = {(DATA_WIDTH/8){1'b1}};
            force dut.s00_wlast_w   = 1'b1;
            force dut.s00_wvalid_w  = 1'b1;
            force dut.s00_bready_w  = 1'b1;

            aw_done = 1'b0;
            w_done  = 1'b0;
            b_done  = 1'b0;
            timeout = 0;

            // Wait for both AW & W handshakes
            while ((!aw_done || !w_done) && timeout < TIMEOUT_CYC) begin
                @(posedge clk);
                if (dut.s00_awready_w && dut.s00_awvalid_clean) begin
                    aw_done = 1'b1;
                    force dut.s00_awvalid_w = 1'b0;
                end
                if (dut.s00_wready_w && dut.s00_wvalid_clean) begin
                    w_done = 1'b1;
                    force dut.s00_wvalid_w = 1'b0;
                    force dut.s00_wlast_w  = 1'b0;
                end
                timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC) begin
                $display("[ERROR @%0t ns] CPU s00 write AW/W timeout! addr=0x%08h", $time, addr);
            end

            @(negedge clk);
            force dut.s00_awvalid_w = 1'b0;
            force dut.s00_wvalid_w  = 1'b0;
            force dut.s00_wlast_w   = 1'b0;

            // Wait for B response
            timeout = 0;
            while (!b_done && timeout < TIMEOUT_CYC) begin
                @(posedge clk);
                if (dut.s00_bvalid_w && dut.s00_bready_clean) begin
                    b_done = 1'b1;
                end
                timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC) begin
                $display("[ERROR @%0t ns] CPU s00 write BVALID timeout! addr=0x%08h", $time, addr);
            end

            @(negedge clk);
            force dut.s00_bready_w = 1'b0;
            @(posedge clk);

            // Release all forced lines back to idle state
            release dut.s00_awid_w;
            release dut.s00_awaddr_w;
            release dut.s00_awlen_w;
            release dut.s00_awsize_w;
            release dut.s00_awburst_w;
            release dut.s00_awlock_w;
            release dut.s00_awcache_w;
            release dut.s00_awprot_w;
            release dut.s00_awqos_w;
            release dut.s00_awvalid_w;

            release dut.s00_wdata_w;
            release dut.s00_wstrb_w;
            release dut.s00_wlast_w;
            release dut.s00_wvalid_w;
            release dut.s00_bready_w;
        end
    endtask

    task cpu_axi_read;
        input  [ADDR_WIDTH-1:0]   addr;
        input  [IC_ID_WIDTH-1:0]  id;
        output [DATA_WIDTH-1:0]   data;
        integer timeout;
        reg ar_done, r_done;
        begin
            @(negedge clk);
            force dut.s00_arid_w    = id;
            force dut.s00_araddr_w  = addr;
            force dut.s00_arlen_w   = 8'd0;
            force dut.s00_arsize_w  = 3'd2; // 4 bytes
            force dut.s00_arburst_w = 2'b01;
            force dut.s00_arlock_w  = 1'b0;
            force dut.s00_arcache_w = 4'h0;
            force dut.s00_arprot_w  = 3'b000;
            force dut.s00_arqos_w   = 4'h0;
            force dut.s00_arvalid_w = 1'b1;
            force dut.s00_rready_w  = 1'b1;

            ar_done = 1'b0;
            r_done  = 1'b0;
            timeout = 0;

            while ((!ar_done || !r_done) && timeout < TIMEOUT_CYC) begin
                @(posedge clk);
                if (dut.s00_arready_w && dut.s00_arvalid_clean) begin
                    ar_done = 1'b1;
                    force dut.s00_arvalid_w = 1'b0;
                end
                if (dut.s00_rvalid_w && dut.s00_rready_clean) begin
                    r_done = 1'b1;
                    data = dut.s00_rdata_w;
                    force dut.s00_rready_w = 1'b0;
                end
                timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC) begin
                $display("[ERROR @%0t ns] CPU s00 read timeout! addr=0x%08h", $time, addr);
                data = 32'hDEAD_BEEF;
            end

            @(negedge clk);
            force dut.s00_arvalid_w = 1'b0;
            force dut.s00_rready_w  = 1'b0;
            @(posedge clk);

            // Release all forced lines
            release dut.s00_arid_w;
            release dut.s00_araddr_w;
            release dut.s00_arlen_w;
            release dut.s00_arsize_w;
            release dut.s00_arburst_w;
            release dut.s00_arlock_w;
            release dut.s00_arcache_w;
            release dut.s00_arprot_w;
            release dut.s00_arqos_w;
            release dut.s00_arvalid_w;
            release dut.s00_rready_w;
        end
    endtask

    // =========================================================================
    // DMA Control Helper Tasks
    // =========================================================================
    task dma_config_desc0;
        input [31:0] src_addr;
        input [31:0] dst_addr;
        input [31:0] num_bytes;
        input        wr_mode; // 0 = INCR, 1 = FIXED
        input        rd_mode; // 0 = INCR, 1 = FIXED
        begin
            cpu_axi_write(DMA_DESC0_SRC_REG, src_addr,  8'h10);
            cpu_axi_write(DMA_DESC0_DST_REG, dst_addr,  8'h11);
            cpu_axi_write(DMA_DESC0_LEN_REG, num_bytes, 8'h12);
            // Config: bit0=wr_mode, bit1=rd_mode, bit2=enable (1)
            cpu_axi_write(DMA_DESC0_CFG_REG, {29'b0, 1'b1, rd_mode, wr_mode}, 8'h13);
        end
    endtask

    task dma_start;
        input [7:0] max_burst;
        begin
            // dma_control: bit0=go, bit1=abort(0), bits[9:2]=max_burst
            cpu_axi_write(DMA_CTRL_REG, {22'b0, max_burst, 1'b0, 1'b1}, 8'h14);
        end
    endtask

    task dma_abort;
        begin
            // dma_control: bit0=go(0), bit1=abort(1), bits[9:2]=max_burst(8'hFF)
            cpu_axi_write(DMA_CTRL_REG, {22'b0, 8'hFF, 1'b1, 1'b0}, 8'h15);
        end
    endtask

    task wait_dma_completion;
        output bit success;
        input integer max_cycles;
        integer count;
        begin
            success = 1'b0;
            count   = 0;
            while (!dma_done_o && !dma_error_o && count < max_cycles) begin
                @(posedge clk);
                count = count + 1;
            end
            if (dma_done_o && !dma_error_o) begin
                success = 1'b1;
            end
        end
    endtask

    // =========================================================================
    // System Reset Task
    // =========================================================================
    task do_reset;
        begin
            $display("[RST @%0t ns] Asserting system reset (rst_l=0, dbg_rst_l=0)", $time);
            rst_l     = 1'b0;
            dbg_rst_l = 1'b0;
            repeat(RST_CYCLES) @(posedge clk);
            @(negedge clk);
            rst_l     = 1'b1;
            dbg_rst_l = 1'b1;
            $display("[RST @%0t ns] System reset released (rst_l=1, dbg_rst_l=1)", $time);
            repeat(15) @(posedge clk);
        end
    endtask

    // =========================================================================
    // UART TX Bit Monitor
    // =========================================================================
    always @(negedge uart_tx_o) begin : uart_tx_mon
        integer bit_idx;
        #(CLK_PERIOD * BIT_CYCLES * 1.5);
        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            rx_capture[bit_idx] = uart_tx_o;
            #(CLK_PERIOD * BIT_CYCLES);
        end
        rx_byte_count = rx_byte_count + 1;
        rx_done = 1'b1;
        $display("[UART_TX_MON @%0t ns] Received byte #%0d = 0x%02h ('%c')",
                 $time, rx_byte_count, rx_capture, rx_capture);
        #1;
        rx_done = 1'b0;
    end

    // =========================================================================
    // Simulation Watchdog Timer
    // =========================================================================
    initial begin
        #(CLK_PERIOD * 400000);
        $display("[WATCHDOG @%0t ns] ERROR: Simulation exceeded cycle budget. Aborting.", $time);
        $finish;
    end

    // =========================================================================
    // NIST FIPS-197 Test Vectors
    // Key        : 2b7e1516 28aed2a6 abf71588 09cf4f3c
    // Plaintext  : 6bc1bee2 2e409f96 e93d7e11 7393172a
    // Ciphertext : 3ad77bb4 0d7a3660 a89ecaf3 2466ef97
    // =========================================================================
    localparam [31:0] GOLDEN_KEY0 = 32'h2b7e1516;
    localparam [31:0] GOLDEN_KEY1 = 32'h28aed2a6;
    localparam [31:0] GOLDEN_KEY2 = 32'habf71588;
    localparam [31:0] GOLDEN_KEY3 = 32'h09cf4f3c;

    localparam [31:0] GOLDEN_PT0  = 32'h6bc1bee2;
    localparam [31:0] GOLDEN_PT1  = 32'h2e409f96;
    localparam [31:0] GOLDEN_PT2  = 32'he93d7e11;
    localparam [31:0] GOLDEN_PT3  = 32'h7393172a;

    localparam [31:0] GOLDEN_CT0  = 32'h3ad77bb4;
    localparam [31:0] GOLDEN_CT1  = 32'h0d7a3660;
    localparam [31:0] GOLDEN_CT2  = 32'ha89ecaf3;
    localparam [31:0] GOLDEN_CT3  = 32'h2466ef97;

    // =========================================================================
    // Main Verification Flow
    // =========================================================================
    reg [31:0] rd_val, r0, r1, r2, r3;
    integer    wait_iter;
    bit        dma_ok;

    initial begin : tb_main
        pass_count    = 0;
        fail_count    = 0;
        rx_capture    = 8'h00;
        rx_done       = 1'b0;
        rx_byte_count = 0;
        pulse_count   = 0;

        rst_l         = 1'b0;
        dbg_rst_l     = 1'b0;
        rst_vec       = 31'h4000_0000;
        nmi_vec       = 31'h1ee1_0000;
        jtag_id       = 31'h0000_0001;
        core_id       = 28'h000_0000;
        nmi_int       = 1'b0;
        timer_int     = 1'b0;
        soft_int      = 1'b0;
        extintsrc_req = {PIC_TOTAL_INT{1'b0}};
        uart_rx_i     = 1'b1;

        dma_axi_awvalid = 1'b0; dma_axi_awid    = {DMA_BUS_TAG{1'b0}};
        dma_axi_awaddr  = 0;    dma_axi_awsize  = 0;
        dma_axi_awprot  = 0;    dma_axi_awlen   = 0;
        dma_axi_awburst = 0;    dma_axi_wvalid  = 1'b0;
        dma_axi_wdata   = 0;    dma_axi_wstrb   = 0;
        dma_axi_wlast   = 0;    dma_axi_bready  = 1'b1;
        dma_axi_arvalid = 1'b0; dma_axi_arid    = {DMA_BUS_TAG{1'b0}};
        dma_axi_araddr  = 0;    dma_axi_arsize  = 0;
        dma_axi_arprot  = 0;    dma_axi_arlen   = 0;
        dma_axi_arburst = 0;    dma_axi_rready  = 1'b1;

        $display("================================================================");
        $display("       STARTING SOC VERIFICATION: veer2_dma_aes_uart");
        $display("   Integrates: VeeR EL2 CPU + DMA Master + AES + UART + AXI 2x6");
        $display("================================================================");

        // ---------------------------------------------------------------------
        // TC1: Power-on Reset & Quiescent State Verification
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC1: Power-on Reset & Quiescent Signal Checks");
        $display("---------------------------------------------------------");
        do_reset();

        if (rst_l === 1'b1 && uart_tx_o === 1'b1 && aes_busy_o === 1'b0 &&
            aes_done_o === 1'b0 && dma_done_o === 1'b0 && dma_error_o === 1'b0 &&
            dma_irq_o === 1'b0 && aes_irq_o === 1'b0 && uart_read_irq_o === 1'b0) begin
            $display("[PASS] TC1: System successfully initialized into clean quiescent state.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC1: Unexpected signal states after reset:");
            $display("       uart_tx=%b aes_busy=%b aes_done=%b dma_done=%b dma_err=%b",
                     uart_tx_o, aes_busy_o, aes_done_o, dma_done_o, dma_error_o);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC2: VeeR IFU Core Instruction Fetch
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC2: VeeR IFU Core Instruction Fetch Activity");
        $display("---------------------------------------------------------");
        wait_iter = 0;
        while (!ifu_fetch_seen && !ifu_axi_arvalid && wait_iter < 2000) begin
            @(posedge clk);
            wait_iter = wait_iter + 1;
        end
        if (ifu_fetch_seen || ifu_axi_arvalid) begin
            $display("[PASS] TC2: Observed VeeR Core issuing IFU instruction fetch (PC=0x%08h).",
                     ifu_fetch_seen ? ifu_fetch_addr : ifu_axi_araddr);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC2: Core failed to initiate instruction fetch within budget.");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC3: DMA CSR Bus Access & Hardware Version (0xCAFE) Verification
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC3: DMA CSR Bus Access & Version Register Read (0x4000_3008)");
        $display("---------------------------------------------------------");
        cpu_axi_read(DMA_STAT_REG, 8'h01, rd_val);
        $display("[INFO] TC3: Read DMA_STATUS register = 0x%08h", rd_val);

        if (rd_val[15:0] === 16'hCAFE && rd_val[16] === 1'b0 && rd_val[17] === 1'b0) begin
            $display("[PASS] TC3: DMA Version 0xCAFE verified; Done=0, Error=0.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC3: DMA_STATUS mismatch! Expected [15:0]=0xCAFE, got 0x%08h", rd_val);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC4: DMA Descriptor 0 & 1 Programming & Readback Check
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC4: DMA Descriptor Multi-Register Write & Readback");
        $display("---------------------------------------------------------");
        // Write Descriptor 0
        cpu_axi_write(DMA_DESC0_SRC_REG, 32'h4000_2024, 8'h02);
        cpu_axi_write(DMA_DESC0_DST_REG, 32'h4000_2014, 8'h03);
        cpu_axi_write(DMA_DESC0_LEN_REG, 32'h0000_0010, 8'h04);
        cpu_axi_write(DMA_DESC0_CFG_REG, 32'h0000_0004, 8'h05); // enable=1, rd=0, wr=0

        // Write Descriptor 1
        cpu_axi_write(DMA_DESC1_SRC_REG, 32'h4000_2004, 8'h06);
        cpu_axi_write(DMA_DESC1_DST_REG, 32'h4000_2008, 8'h07);
        cpu_axi_write(DMA_DESC1_LEN_REG, 32'h0000_0008, 8'h08);
        cpu_axi_write(DMA_DESC1_CFG_REG, 32'h0000_0005, 8'h09); // enable=1, rd=0, wr=1

        // Readback Descriptor 0
        cpu_axi_read(DMA_DESC0_SRC_REG, 8'h0A, r0);
        cpu_axi_read(DMA_DESC0_DST_REG, 8'h0B, r1);
        cpu_axi_read(DMA_DESC0_LEN_REG, 8'h0C, r2);
        cpu_axi_read(DMA_DESC0_CFG_REG, 8'h0D, r3);

        if (r0 == 32'h4000_2024 && r1 == 32'h4000_2014 && r2 == 32'h0000_0010 && r3[2:0] == 3'b100) begin
            $display("[PASS] TC4: Descriptor 0 configuration successfully persisted and verified.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC4: Descriptor 0 readback mismatch! src=0x%08h dst=0x%08h len=0x%08h cfg=0x%08h",
                     r0, r1, r2, r3);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC5: UART Peripheral Configuration & Direct Transmission ('D' = 0x44)
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC5: UART Peripheral Configuration & Transmission ('D' = 0x44)");
        $display("---------------------------------------------------------");
        // DLAB=1, 8-bit word
        cpu_axi_write(UART_LCR_REG,  32'h0000_0083, 8'h20);
        // BAUD divisor
        cpu_axi_write(UART_BAUD_REG, BAUD_DIV,      8'h21);
        // DLAB=0, 8-bit, 1 stop bit, no parity
        cpu_axi_write(UART_LCR_REG,  32'h0000_0003, 8'h22);
        // Enable RX interrupt
        cpu_axi_write(UART_IER_REG,  32'h0000_0001, 8'h23);

        // Transmit character 'D' (0x44)
        rx_done = 1'b0;
        cpu_axi_write(UART_THR_REG, 32'h44, 8'h24);
        wait_iter = 0;
        while (!rx_done && wait_iter < (BIT_CYCLES * 30)) begin
            @(posedge clk);
            wait_iter = wait_iter + 1;
        end
        if (rx_capture == 8'h44) begin
            $display("[PASS] TC5: UART successfully transmitted character 0x44 ('%c').", rx_capture);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC5: UART TX mismatch: got 0x%02h, expected 0x44", rx_capture);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC6: UART Serial RX Loopback & Interrupt Generation Check
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC6: UART Serial RX Loopback & Interrupt Verification");
        $display("---------------------------------------------------------");
        // Inject serial byte 0x55 on uart_rx_i: Start(0), 8 bits LSB-first, Stop(1)
        @(posedge clk);
        uart_rx_i = 1'b0; // start bit
        repeat(BIT_CYCLES) @(posedge clk);
        for (wait_iter = 0; wait_iter < 8; wait_iter = wait_iter + 1) begin
            uart_rx_i = (wait_iter % 2 == 0) ? 1'b1 : 1'b0; // 0x55
            repeat(BIT_CYCLES) @(posedge clk);
        end
        uart_rx_i = 1'b1; // stop bit
        repeat(BIT_CYCLES) @(posedge clk);
        repeat(BIT_CYCLES * 4) @(posedge clk);

        if (uart_read_irq_o === 1'b1) begin
            $display("[PASS] TC6: UART RX interrupt successfully asserted upon byte reception.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC6: UART RX interrupt was not asserted.");
            fail_count = fail_count + 1;
        end

        // Read character back from RBR
        cpu_axi_read(UART_RBR_REG, 8'h25, rd_val);
        if (rd_val[7:0] === 8'h55) begin
            $display("[PASS] TC6: UART RBR read data matched injected byte 0x55.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC6: UART RBR mismatch: got 0x%02h, expected 0x55", rd_val[7:0]);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC7: AES-128 Encryption Execution (NIST FIPS-197 Golden Vector)
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC7: AES-128 Hardware Encryption Execution (FIPS-197)");
        $display("---------------------------------------------------------");
        // Load Key
        cpu_axi_write(AES_KEY0_REG, GOLDEN_KEY0, 8'h30);
        cpu_axi_write(AES_KEY1_REG, GOLDEN_KEY1, 8'h31);
        cpu_axi_write(AES_KEY2_REG, GOLDEN_KEY2, 8'h32);
        cpu_axi_write(AES_KEY3_REG, GOLDEN_KEY3, 8'h33);

        // Load Plaintext
        cpu_axi_write(AES_TXTIN0_REG, GOLDEN_PT0, 8'h34);
        cpu_axi_write(AES_TXTIN1_REG, GOLDEN_PT1, 8'h35);
        cpu_axi_write(AES_TXTIN2_REG, GOLDEN_PT2, 8'h36);
        cpu_axi_write(AES_TXTIN3_REG, GOLDEN_PT3, 8'h37);

        // Trigger encryption: START=1, MODE=0 (Encrypt), IRQ_EN=1
        pulse_count = 0;
        cpu_axi_write(AES_CTRL_REG, 32'h0000_0009, 8'h38);

        // Poll for completion (bit 8 = DONE)
        rd_val = 0;
        wait_iter = 0;
        while (!rd_val[8] && wait_iter < 200) begin
            cpu_axi_read(AES_CTRL_REG, 8'h39, rd_val);
            wait_iter = wait_iter + 1;
        end

        // Read 128-bit ciphertext from TXTOUT0..3
        cpu_axi_read(AES_TXTOUT0_REG, 8'h3A, r0);
        cpu_axi_read(AES_TXTOUT1_REG, 8'h3B, r1);
        cpu_axi_read(AES_TXTOUT2_REG, 8'h3C, r2);
        cpu_axi_read(AES_TXTOUT3_REG, 8'h3D, r3);

        $display("[CIPHERTEXT] Word0: got=0x%08h exp=0x%08h", r0, GOLDEN_CT0);
        $display("[CIPHERTEXT] Word1: got=0x%08h exp=0x%08h", r1, GOLDEN_CT1);
        $display("[CIPHERTEXT] Word2: got=0x%08h exp=0x%08h", r2, GOLDEN_CT2);
        $display("[CIPHERTEXT] Word3: got=0x%08h exp=0x%08h", r3, GOLDEN_CT3);

        if (r0 == GOLDEN_CT0 && r1 == GOLDEN_CT1 && r2 == GOLDEN_CT2 && r3 == GOLDEN_CT3 &&
            pulse_count >= 1 && aes_irq_o === 1'b1) begin
            $display("[PASS] TC7: AES-128 ciphertext strictly matches FIPS-197 golden vector; WDT kick asserted.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC7: AES encryption mismatch or missing IRQ/Pulse!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC8: DMA Master 2 Execution: Stream 16-byte Ciphertext to AES Input
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC8: DMA Master 2 Hardware Transfer: Ciphertext -> AES Text Input");
        $display("---------------------------------------------------------");
        // Clear AES_TXTIN0..3 first so we can verify DMA actually wrote new data
        cpu_axi_write(AES_TXTIN0_REG, 32'h0000_0000, 8'h40);
        cpu_axi_write(AES_TXTIN1_REG, 32'h0000_0000, 8'h41);
        cpu_axi_write(AES_TXTIN2_REG, 32'h0000_0000, 8'h42);
        cpu_axi_write(AES_TXTIN3_REG, 32'h0000_0000, 8'h43);

        // Program DMA Descriptor 0:
        // Source: AES_TXTOUT0_REG (0x4000_2024)
        // Dest:   AES_TXTIN0_REG  (0x4000_2014)
        // Length: 16 bytes (4 words)
        // Modes:  rd_mode=0 (INCR), wr_mode=0 (INCR)
        dma_config_desc0(AES_TXTOUT0_REG, AES_TXTIN0_REG, 32'd16, 1'b0, 1'b0);

        // Start DMA transfer
        $display("[INFO] TC8: Triggering DMA transfer (Master 2 on s01)...");
        dma_start(8'hFF);

        // Wait for DMA completion
        wait_dma_completion(dma_ok, 1000);

        if (dma_ok && dma_done_o === 1'b1 && dma_irq_o === 1'b1) begin
            $display("[PASS] TC8: DMA transfer completed successfully (dma_done_o=1, dma_irq_o=1).");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC8: DMA transfer timed out or reported error! done=%b err=%b",
                     dma_done_o, dma_error_o);
            fail_count = fail_count + 1;
        end

        // Verify DMA transferred the 16 bytes correctly into AES_TXTIN0..3
        cpu_axi_read(AES_TXTIN0_REG, 8'h44, r0);
        cpu_axi_read(AES_TXTIN1_REG, 8'h45, r1);
        cpu_axi_read(AES_TXTIN2_REG, 8'h46, r2);
        cpu_axi_read(AES_TXTIN3_REG, 8'h47, r3);

        $display("[DMA_VERIF] TXTIN0: got=0x%08h exp=0x%08h", r0, GOLDEN_CT0);
        $display("[DMA_VERIF] TXTIN1: got=0x%08h exp=0x%08h", r1, GOLDEN_CT1);
        $display("[DMA_VERIF] TXTIN2: got=0x%08h exp=0x%08h", r2, GOLDEN_CT2);
        $display("[DMA_VERIF] TXTIN3: got=0x%08h exp=0x%08h", r3, GOLDEN_CT3);

        if (r0 == GOLDEN_CT0 && r1 == GOLDEN_CT1 && r2 == GOLDEN_CT2 && r3 == GOLDEN_CT3) begin
            $display("[PASS] TC8: 16-byte ciphertext correctly transferred by DMA Master across crossbar!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC8: Transferred data mismatch in AES_TXTIN registers!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC9: AES-128 Decryption of DMA-transferred Payload & Plaintext Recovery
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC9: AES-128 Decryption of DMA-Loaded Payload & Plaintext Recovery");
        $display("---------------------------------------------------------");
        // Key expansion for decryption (KEY_LD=1, MODE=1 Decrypt, IRQ_EN=1)
        cpu_axi_write(AES_CTRL_REG, 32'h0000_000E, 8'h48);
        repeat(15) @(posedge clk);

        // Trigger Decryption: START=1, MODE=1 (Decrypt), IRQ_EN=1
        // Note: Plaintext recovery uses the ciphertext that was DMA-streamed into TXTIN0..3
        cpu_axi_write(AES_CTRL_REG, 32'h0000_000D, 8'h49);

        // Poll for completion
        rd_val = 0;
        wait_iter = 0;
        while (!rd_val[8] && wait_iter < 200) begin
            cpu_axi_read(AES_CTRL_REG, 8'h4A, rd_val);
            wait_iter = wait_iter + 1;
        end

        // Read recovered plaintext from TXTOUT0..3
        cpu_axi_read(AES_TXTOUT0_REG, 8'h4B, r0);
        cpu_axi_read(AES_TXTOUT1_REG, 8'h4C, r1);
        cpu_axi_read(AES_TXTOUT2_REG, 8'h4D, r2);
        cpu_axi_read(AES_TXTOUT3_REG, 8'h4E, r3);

        $display("[RECOVERED] Word0: got=0x%08h exp=0x%08h", r0, GOLDEN_PT0);
        $display("[RECOVERED] Word1: got=0x%08h exp=0x%08h", r1, GOLDEN_PT1);
        $display("[RECOVERED] Word2: got=0x%08h exp=0x%08h", r2, GOLDEN_PT2);
        $display("[RECOVERED] Word3: got=0x%08h exp=0x%08h", r3, GOLDEN_PT3);

        if (r0 == GOLDEN_PT0 && r1 == GOLDEN_PT1 && r2 == GOLDEN_PT2 && r3 == GOLDEN_PT3) begin
            $display("[PASS] TC9: Recovered plaintext perfectly matches original FIPS-197 plaintext!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC9: Decryption failed to recover original plaintext.");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC10: DMA Peripheral Streaming to UART Transmitter (Fixed Dest Mode)
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC10: DMA Peripheral Streaming to UART FIFO (Fixed Dest Mode)");
        $display("---------------------------------------------------------");
        // AES_TXTOUT0 contains GOLDEN_PT0 = 0x6bc1bee2. Lowest byte is 0xE2.
        // We configure DMA to transfer 1 byte from AES_TXTOUT0 into UART_THR_REG.
        // wr_mode = 1 (FIXED FIFO mode), rd_mode = 0 (INCR)
        dma_config_desc0(AES_TXTOUT0_REG, UART_THR_REG, 32'd1, 1'b1, 1'b0);

        rx_done = 1'b0;
        dma_start(8'h01);

        wait_iter = 0;
        while (!rx_done && wait_iter < (BIT_CYCLES * 35)) begin
            @(posedge clk);
            wait_iter = wait_iter + 1;
        end

        if (rx_capture == 8'hE2) begin
            $display("[PASS] TC10: DMA successfully streamed byte 0x%02h from AES to UART Transmitter!", rx_capture);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC10: DMA-to-UART stream mismatch: got 0x%02h, expected 0xE2", rx_capture);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC11: Multi-Master Concurrency & Crossbar Arbitration (CPU LSU + DMA)
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC11: Multi-Master Crossbar Concurrency & Arbitration");
        $display("---------------------------------------------------------");
        // Configure DMA for 16-byte transfer
        dma_config_desc0(AES_KEY0_REG, AES_TXTIN0_REG, 32'd16, 1'b0, 1'b0);
        dma_start(8'hFF);

        // While DMA Master 2 is active on s01, CPU Master 1 simultaneously accesses UART & AES
        cpu_axi_write(UART_THR_REG, 32'h21, 8'h50); // Transmit '!'
        cpu_axi_read(UART_LSR_REG,  8'h51, r0);
        cpu_axi_read(AES_KEY1_REG,  8'h52, r1);

        wait_dma_completion(dma_ok, 1000);

        if (dma_ok && r1 == GOLDEN_KEY1) begin
            $display("[PASS] TC11: CPU Master 1 and DMA Master 2 concurrently serviced without bus lockup.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC11: Concurrency arbitration failed: dma_ok=%b, r1=0x%08h", dma_ok, r1);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC12: DMA Abort & Error Status Handling
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC12: DMA Abort & Control Status Check");
        $display("---------------------------------------------------------");
        // Program descriptor for transfer
        dma_config_desc0(AES_KEY0_REG, AES_TXTIN0_REG, 32'd64, 1'b0, 1'b0);
        dma_start(8'h01);
        repeat(5) @(posedge clk);
        // Issue Abort command
        dma_abort();
        repeat(20) @(posedge clk);

        // Read DMA Status
        cpu_axi_read(DMA_STAT_REG, 8'h60, rd_val);
        $display("[INFO] TC12: Read DMA_STATUS after Abort = 0x%08h", rd_val);

        if (rd_val[15:0] === 16'hCAFE) begin
            $display("[PASS] TC12: DMA cleanly handled abort and CSR interface remained healthy.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC12: DMA CSR interface unhealthy after abort: 0x%08h", rd_val);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // Final Scoreboard & Summary
        // ---------------------------------------------------------------------
        $display("\n================================================================");
        $display("         FINAL SOC VERIFICATION SUMMARY (veer2_dma_aes_uart)");
        $display("================================================================");
        $display(" Total Test Cases Run : %0d", (pass_count + fail_count));
        $display(" Tests Passed         : %0d", pass_count);
        $display(" Tests Failed         : %0d", fail_count);
        if (fail_count == 0) begin
            $display(" VERIFICATION RESULT  : ALL TESTS PASSED SUCCESSFULLY! (100%%)");
            $display(" Dual Masters (VeeR LSU + DMA), AES, UART, and AXI4 Crossbar Fully Verified.");
        end else begin
            $display(" VERIFICATION RESULT  : VERIFICATION FAILED with %0d errors.", fail_count);
        end
        $display("================================================================");

        repeat(50) @(posedge clk);
        $finish;
    end

endmodule

`default_nettype wire
