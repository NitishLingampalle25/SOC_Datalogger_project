// =============================================================================
// Testbench : veer_wrapper_uart_integrated_tb
// File      : TB_files/veer_wrapper_uart_integrated_tb.sv
// Language  : SystemVerilog (VCS compatible)
//
// Purpose   : Functional verification of veer_wrapper_uart_integrated
//             Tests:
//               TC1  – Reset de-assertion / power-on sequence
//               TC2  – UART register init (BAUD, LCR, IER) via s01 BFM
//               TC3  – UART TX 'A' – write THR, observe uart_tx_o bits
//               TC4  – UART RX loopback (uart_tx_o -> uart_rx_i)
//               TC5  – RX interrupt assertion & clear
//               TC6  – s01 secondary-master write + read-back
//               TC7  – DMA AXI slave port idle handshake check
//               TC8  – IFU AXI arvalid observed (VeeR fetching instructions)
//               TC9  – Concurrent s01 + IFU traffic (arbitration)
//               TC10 – UART TX burst 'H','i','!'
//
// Compile:
//   vcs -full64 -sverilog +define+RV_BUILD_AXI4 -f <filelist> \
//       TB_files/veer_wrapper_uart_integrated_tb.sv -o simv    \
//       && ./simv
// =============================================================================

`timescale 1ns/1ps

module veer_wrapper_uart_integrated_tb;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam CLK_PERIOD    = 10;
    localparam FIXED_PERIOD  = 10;
    localparam RST_CYCLES    = 10;
    localparam TIMEOUT_CYC   = 5000;
    localparam BAUD_DIV      = 4;

    localparam IC_ID_WIDTH   = 8;
    localparam DATA_WIDTH    = 32;
    localparam ADDR_WIDTH    = 32;
    localparam LSU_BUS_TAG   = 4;
    localparam IFU_BUS_TAG   = 3;
    localparam SB_BUS_TAG    = 2;
    localparam DMA_BUS_TAG   = 1;
    localparam PIC_TOTAL_INT = 255;

    localparam [31:0] UART_BASE     = 32'h4000_0000;
    localparam [31:0] UART_THR_REG  = UART_BASE + 0;
    localparam [31:0] UART_RBR_REG  = UART_BASE + 0;
    localparam [31:0] UART_IER_REG  = UART_BASE + 4;
    localparam [31:0] UART_BAUD_REG = UART_BASE + 8;
    localparam [31:0] UART_LCR_REG  = UART_BASE + 12;
    localparam [31:0] UART_LSR_REG  = UART_BASE + 16;

    localparam [63:0] NOP64 = 64'h0000_0013_0000_0013;

    // =========================================================================
    // Signal declarations  (reg for driven, wire for observed)
    // =========================================================================

    // Clocks / Resets
    reg  clk;
    reg  fixed_clk;
    reg  rst_l;
    reg  dbg_rst_l;

    // VeeR boot / id
    reg  [31:1]  rst_vec;
    reg  [31:1]  nmi_vec;
    reg  [31:1]  jtag_id;
    reg  [31:4]  core_id;

    // VeeR interrupts
    reg          nmi_int;
    reg          timer_int;
    reg          soft_int;
    reg  [PIC_TOTAL_INT:1] extintsrc_req;

    // UART physical
    wire         uart_tx_o;
    reg          uart_rx_i;
    wire         uart_read_irq_o;

    // IFU AXI master outputs (from DUT)
    wire                      ifu_axi_arvalid;
    reg                       ifu_axi_arready;
    wire [IFU_BUS_TAG-1:0]    ifu_axi_arid;
    wire [31:0]               ifu_axi_araddr;
    wire [3:0]                ifu_axi_arregion;
    wire [7:0]                ifu_axi_arlen;
    wire [2:0]                ifu_axi_arsize;
    wire [1:0]                ifu_axi_arburst;
    wire                      ifu_axi_arlock;
    wire [3:0]                ifu_axi_arcache;
    wire [2:0]                ifu_axi_arprot;
    wire [3:0]                ifu_axi_arqos;

    reg                       ifu_axi_rvalid;
    wire                      ifu_axi_rready;
    reg  [IFU_BUS_TAG-1:0]    ifu_axi_rid;
    reg  [63:0]               ifu_axi_rdata;
    reg  [1:0]                ifu_axi_rresp;
    reg                       ifu_axi_rlast;

    // IFU write channel (core never writes – tied off)
    wire                      ifu_axi_awvalid;
    wire                      ifu_axi_awready;
    wire [IFU_BUS_TAG-1:0]    ifu_axi_awid;
    wire [31:0]               ifu_axi_awaddr;
    wire [3:0]                ifu_axi_awregion;
    wire [7:0]                ifu_axi_awlen;
    wire [2:0]                ifu_axi_awsize;
    wire [1:0]                ifu_axi_awburst;
    wire                      ifu_axi_awlock;
    wire [3:0]                ifu_axi_awcache;
    wire [2:0]                ifu_axi_awprot;
    wire [3:0]                ifu_axi_awqos;
    wire                      ifu_axi_wvalid;
    wire                      ifu_axi_wready;
    wire [63:0]               ifu_axi_wdata;
    wire [7:0]                ifu_axi_wstrb;
    wire                      ifu_axi_wlast;
    wire                      ifu_axi_bvalid;
    wire                      ifu_axi_bready;
    wire [1:0]                ifu_axi_bresp;
    wire [IFU_BUS_TAG-1:0]    ifu_axi_bid;

    // SB AXI master (tied off)
    wire                      sb_axi_awvalid;
    wire                      sb_axi_awready;
    wire [SB_BUS_TAG-1:0]     sb_axi_awid;
    wire [31:0]               sb_axi_awaddr;
    wire [3:0]                sb_axi_awregion;
    wire [7:0]                sb_axi_awlen;
    wire [2:0]                sb_axi_awsize;
    wire [1:0]                sb_axi_awburst;
    wire                      sb_axi_awlock;
    wire [3:0]                sb_axi_awcache;
    wire [2:0]                sb_axi_awprot;
    wire [3:0]                sb_axi_awqos;
    wire                      sb_axi_wvalid;
    wire                      sb_axi_wready;
    wire [63:0]               sb_axi_wdata;
    wire [7:0]                sb_axi_wstrb;
    wire                      sb_axi_wlast;
    wire                      sb_axi_bvalid;
    wire                      sb_axi_bready;
    wire [1:0]                sb_axi_bresp;
    wire [SB_BUS_TAG-1:0]     sb_axi_bid;
    wire                      sb_axi_arvalid;
    wire                      sb_axi_arready;
    wire [SB_BUS_TAG-1:0]     sb_axi_arid;
    wire [31:0]               sb_axi_araddr;
    wire [3:0]                sb_axi_arregion;
    wire [7:0]                sb_axi_arlen;
    wire [2:0]                sb_axi_arsize;
    wire [1:0]                sb_axi_arburst;
    wire                      sb_axi_arlock;
    wire [3:0]                sb_axi_arcache;
    wire [2:0]                sb_axi_arprot;
    wire [3:0]                sb_axi_arqos;
    wire                      sb_axi_rvalid;
    wire                      sb_axi_rready;
    wire [SB_BUS_TAG-1:0]     sb_axi_rid;
    wire [63:0]               sb_axi_rdata;
    wire [1:0]                sb_axi_rresp;
    wire                      sb_axi_rlast;

    // DMA AXI slave
    reg                       dma_axi_awvalid;
    wire                      dma_axi_awready;
    reg  [DMA_BUS_TAG-1:0]    dma_axi_awid;
    reg  [31:0]               dma_axi_awaddr;
    reg  [2:0]                dma_axi_awsize;
    reg  [2:0]                dma_axi_awprot;
    reg  [7:0]                dma_axi_awlen;
    reg  [1:0]                dma_axi_awburst;
    reg                       dma_axi_wvalid;
    wire                      dma_axi_wready;
    reg  [63:0]               dma_axi_wdata;
    reg  [7:0]                dma_axi_wstrb;
    reg                       dma_axi_wlast;
    wire                      dma_axi_bvalid;
    reg                       dma_axi_bready;
    wire [1:0]                dma_axi_bresp;
    wire [DMA_BUS_TAG-1:0]    dma_axi_bid;
    reg                       dma_axi_arvalid;
    wire                      dma_axi_arready;
    reg  [DMA_BUS_TAG-1:0]    dma_axi_arid;
    reg  [31:0]               dma_axi_araddr;
    reg  [2:0]                dma_axi_arsize;
    reg  [2:0]                dma_axi_arprot;
    reg  [7:0]                dma_axi_arlen;
    reg  [1:0]                dma_axi_arburst;
    wire                      dma_axi_rvalid;
    reg                       dma_axi_rready;
    wire [DMA_BUS_TAG-1:0]    dma_axi_rid;
    wire [63:0]               dma_axi_rdata;
    wire [1:0]                dma_axi_rresp;
    wire                      dma_axi_rlast;

    // s01 AXI4 BFM
    reg  [IC_ID_WIDTH-1:0]    s01_axi_awid;
    reg  [ADDR_WIDTH-1:0]     s01_axi_awaddr;
    reg  [7:0]                s01_axi_awlen;
    reg  [2:0]                s01_axi_awsize;
    reg  [1:0]                s01_axi_awburst;
    reg                       s01_axi_awlock;
    reg  [3:0]                s01_axi_awcache;
    reg  [2:0]                s01_axi_awprot;
    reg  [3:0]                s01_axi_awqos;
    reg                       s01_axi_awvalid;
    wire                      s01_axi_awready;
    reg  [DATA_WIDTH-1:0]     s01_axi_wdata;
    reg  [DATA_WIDTH/8-1:0]   s01_axi_wstrb;
    reg                       s01_axi_wlast;
    reg                       s01_axi_wvalid;
    wire                      s01_axi_wready;
    wire [IC_ID_WIDTH-1:0]    s01_axi_bid;
    wire [1:0]                s01_axi_bresp;
    wire                      s01_axi_bvalid;
    reg                       s01_axi_bready;
    reg  [IC_ID_WIDTH-1:0]    s01_axi_arid;
    reg  [ADDR_WIDTH-1:0]     s01_axi_araddr;
    reg  [7:0]                s01_axi_arlen;
    reg  [2:0]                s01_axi_arsize;
    reg  [1:0]                s01_axi_arburst;
    reg                       s01_axi_arlock;
    reg  [3:0]                s01_axi_arcache;
    reg  [2:0]                s01_axi_arprot;
    reg  [3:0]                s01_axi_arqos;
    reg                       s01_axi_arvalid;
    wire                      s01_axi_arready;
    wire [IC_ID_WIDTH-1:0]    s01_axi_rid;
    wire [DATA_WIDTH-1:0]     s01_axi_rdata;
    wire [1:0]                s01_axi_rresp;
    wire                      s01_axi_rlast;
    wire                      s01_axi_rvalid;
    reg                       s01_axi_rready;

    // VeeR observe-only outputs
    wire [31:0]  trace_rv_i_insn_ip;
    wire [31:0]  trace_rv_i_address_ip;
    wire         trace_rv_i_valid_ip;
    wire         trace_rv_i_exception_ip;
    wire [4:0]   trace_rv_i_ecause_ip;
    wire         trace_rv_i_interrupt_ip;
    wire [31:0]  trace_rv_i_tval_ip;
    wire         iccm_ecc_single_error, iccm_ecc_double_error;
    wire         dccm_ecc_single_error, dccm_ecc_double_error;
    wire         dccm_write_readback_error;
    wire         dec_tlu_perfcnt0, dec_tlu_perfcnt1;
    wire         dec_tlu_perfcnt2, dec_tlu_perfcnt3;
    wire         jtag_tdo, jtag_tdoEn;
    wire         mpc_debug_halt_ack, mpc_debug_run_ack;
    wire         debug_brkpt_status;
    wire         o_cpu_halt_ack, o_cpu_halt_status;
    wire         o_debug_mode_status, o_cpu_run_ack;
    wire         dmi_uncore_en, dmi_uncore_wr_en;
    wire [6:0]   dmi_uncore_addr;
    wire [31:0]  dmi_uncore_wdata;
    wire         dmi_active;

    // Scoreboard
    integer pass_count;
    integer fail_count;

    // UART TX monitor shared state
    reg [7:0]   rx_capture;
    reg         rx_done;
    integer     rx_byte_count;

    // Shared read-data for BFM tasks
    reg [DATA_WIDTH-1:0] bfm_rdata;

    // =========================================================================
    // IFU write channel tie-off (assign – no driver needed)
    // =========================================================================
    assign ifu_axi_awready = 1'b1;
    assign ifu_axi_wready  = 1'b1;
    assign ifu_axi_bvalid  = 1'b0;
    assign ifu_axi_bresp   = 2'b00;
    assign ifu_axi_bid     = {IFU_BUS_TAG{1'b0}};

    // SB AXI tie-off
    assign sb_axi_awready = 1'b1;
    assign sb_axi_wready  = 1'b1;
    assign sb_axi_bvalid  = 1'b0;
    assign sb_axi_bresp   = 2'b00;
    assign sb_axi_bid     = {SB_BUS_TAG{1'b0}};
    assign sb_axi_arready = 1'b1;
    assign sb_axi_rvalid  = 1'b0;
    assign sb_axi_rdata   = 64'h0;
    assign sb_axi_rresp   = 2'b00;
    assign sb_axi_rlast   = 1'b1;
    assign sb_axi_rid     = {SB_BUS_TAG{1'b0}};

    // =========================================================================
    // Clock generation
    // =========================================================================
    initial clk       = 1'b0;
    always  #(CLK_PERIOD/2)   clk       = ~clk;

    initial fixed_clk = 1'b0;
    always  #(FIXED_PERIOD/2) fixed_clk = ~fixed_clk;

    // =========================================================================
    // IFU instruction-memory model (returns NOP stream to keep core alive)
    // =========================================================================
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
                $display("[IMEM  @%0t ns] IFU AR: addr=0x%08h  id=%0d",
                          $time, ifu_axi_araddr, ifu_axi_arid);
            end else if (ifu_axi_rvalid && ifu_axi_rready) begin
                ifu_axi_rvalid <= 1'b0;
                $display("[IMEM  @%0t ns] IFU R : data=0x%016h  resp=%b",
                          $time, ifu_axi_rdata, ifu_axi_rresp);
            end
        end
    end

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    veer_wrapper_uart_integrated #(
        .IC_ID_WIDTH    (IC_ID_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .LSU_BUS_TAG    (LSU_BUS_TAG),
        .IFU_BUS_TAG    (IFU_BUS_TAG),
        .SB_BUS_TAG     (SB_BUS_TAG),
        .DMA_BUS_TAG    (DMA_BUS_TAG),
        .PIC_TOTAL_INT  (PIC_TOTAL_INT),
        .UART_BASE_ADDR (32'h4000_0000)
    ) dut (
        .clk                      (clk),
        .rst_l                    (rst_l),
        .dbg_rst_l                (dbg_rst_l),
        .fixed_clk                (fixed_clk),
        .rst_vec                  (rst_vec),
        .nmi_vec                  (nmi_vec),
        .jtag_id                  (jtag_id),
        .core_id                  (core_id),
        .nmi_int                  (nmi_int),
        .timer_int                (timer_int),
        .soft_int                 (soft_int),
        .extintsrc_req            (extintsrc_req),
        .uart_read_irq_o          (uart_read_irq_o),
        .uart_tx_o                (uart_tx_o),
        .uart_rx_i                (uart_rx_i),
        // IFU
        .ifu_axi_arvalid          (ifu_axi_arvalid),
        .ifu_axi_arready          (ifu_axi_arready),
        .ifu_axi_arid             (ifu_axi_arid),
        .ifu_axi_araddr           (ifu_axi_araddr),
        .ifu_axi_arregion         (ifu_axi_arregion),
        .ifu_axi_arlen            (ifu_axi_arlen),
        .ifu_axi_arsize           (ifu_axi_arsize),
        .ifu_axi_arburst          (ifu_axi_arburst),
        .ifu_axi_arlock           (ifu_axi_arlock),
        .ifu_axi_arcache          (ifu_axi_arcache),
        .ifu_axi_arprot           (ifu_axi_arprot),
        .ifu_axi_arqos            (ifu_axi_arqos),
        .ifu_axi_rvalid           (ifu_axi_rvalid),
        .ifu_axi_rready           (ifu_axi_rready),
        .ifu_axi_rid              (ifu_axi_rid),
        .ifu_axi_rdata            (ifu_axi_rdata),
        .ifu_axi_rresp            (ifu_axi_rresp),
        .ifu_axi_rlast            (ifu_axi_rlast),
        .ifu_axi_awvalid          (ifu_axi_awvalid),
        .ifu_axi_awready          (ifu_axi_awready),
        .ifu_axi_awid             (ifu_axi_awid),
        .ifu_axi_awaddr           (ifu_axi_awaddr),
        .ifu_axi_awregion         (ifu_axi_awregion),
        .ifu_axi_awlen            (ifu_axi_awlen),
        .ifu_axi_awsize           (ifu_axi_awsize),
        .ifu_axi_awburst          (ifu_axi_awburst),
        .ifu_axi_awlock           (ifu_axi_awlock),
        .ifu_axi_awcache          (ifu_axi_awcache),
        .ifu_axi_awprot           (ifu_axi_awprot),
        .ifu_axi_awqos            (ifu_axi_awqos),
        .ifu_axi_wvalid           (ifu_axi_wvalid),
        .ifu_axi_wready           (ifu_axi_wready),
        .ifu_axi_wdata            (ifu_axi_wdata),
        .ifu_axi_wstrb            (ifu_axi_wstrb),
        .ifu_axi_wlast            (ifu_axi_wlast),
        .ifu_axi_bvalid           (ifu_axi_bvalid),
        .ifu_axi_bready           (ifu_axi_bready),
        .ifu_axi_bresp            (ifu_axi_bresp),
        .ifu_axi_bid              (ifu_axi_bid),
        // SB
        .sb_axi_awvalid           (sb_axi_awvalid),
        .sb_axi_awready           (sb_axi_awready),
        .sb_axi_awid              (sb_axi_awid),
        .sb_axi_awaddr            (sb_axi_awaddr),
        .sb_axi_awregion          (sb_axi_awregion),
        .sb_axi_awlen             (sb_axi_awlen),
        .sb_axi_awsize            (sb_axi_awsize),
        .sb_axi_awburst           (sb_axi_awburst),
        .sb_axi_awlock            (sb_axi_awlock),
        .sb_axi_awcache           (sb_axi_awcache),
        .sb_axi_awprot            (sb_axi_awprot),
        .sb_axi_awqos             (sb_axi_awqos),
        .sb_axi_wvalid            (sb_axi_wvalid),
        .sb_axi_wready            (sb_axi_wready),
        .sb_axi_wdata             (sb_axi_wdata),
        .sb_axi_wstrb             (sb_axi_wstrb),
        .sb_axi_wlast             (sb_axi_wlast),
        .sb_axi_bvalid            (sb_axi_bvalid),
        .sb_axi_bready            (sb_axi_bready),
        .sb_axi_bresp             (sb_axi_bresp),
        .sb_axi_bid               (sb_axi_bid),
        .sb_axi_arvalid           (sb_axi_arvalid),
        .sb_axi_arready           (sb_axi_arready),
        .sb_axi_arid              (sb_axi_arid),
        .sb_axi_araddr            (sb_axi_araddr),
        .sb_axi_arregion          (sb_axi_arregion),
        .sb_axi_arlen             (sb_axi_arlen),
        .sb_axi_arsize            (sb_axi_arsize),
        .sb_axi_arburst           (sb_axi_arburst),
        .sb_axi_arlock            (sb_axi_arlock),
        .sb_axi_arcache           (sb_axi_arcache),
        .sb_axi_arprot            (sb_axi_arprot),
        .sb_axi_arqos             (sb_axi_arqos),
        .sb_axi_rvalid            (sb_axi_rvalid),
        .sb_axi_rready            (sb_axi_rready),
        .sb_axi_rid               (sb_axi_rid),
        .sb_axi_rdata             (sb_axi_rdata),
        .sb_axi_rresp             (sb_axi_rresp),
        .sb_axi_rlast             (sb_axi_rlast),
        // DMA
        .dma_axi_awvalid          (dma_axi_awvalid),
        .dma_axi_awready          (dma_axi_awready),
        .dma_axi_awid             (dma_axi_awid),
        .dma_axi_awaddr           (dma_axi_awaddr),
        .dma_axi_awsize           (dma_axi_awsize),
        .dma_axi_awprot           (dma_axi_awprot),
        .dma_axi_awlen            (dma_axi_awlen),
        .dma_axi_awburst          (dma_axi_awburst),
        .dma_axi_wvalid           (dma_axi_wvalid),
        .dma_axi_wready           (dma_axi_wready),
        .dma_axi_wdata            (dma_axi_wdata),
        .dma_axi_wstrb            (dma_axi_wstrb),
        .dma_axi_wlast            (dma_axi_wlast),
        .dma_axi_bvalid           (dma_axi_bvalid),
        .dma_axi_bready           (dma_axi_bready),
        .dma_axi_bresp            (dma_axi_bresp),
        .dma_axi_bid              (dma_axi_bid),
        .dma_axi_arvalid          (dma_axi_arvalid),
        .dma_axi_arready          (dma_axi_arready),
        .dma_axi_arid             (dma_axi_arid),
        .dma_axi_araddr           (dma_axi_araddr),
        .dma_axi_arsize           (dma_axi_arsize),
        .dma_axi_arprot           (dma_axi_arprot),
        .dma_axi_arlen            (dma_axi_arlen),
        .dma_axi_arburst          (dma_axi_arburst),
        .dma_axi_rvalid           (dma_axi_rvalid),
        .dma_axi_rready           (dma_axi_rready),
        .dma_axi_rid              (dma_axi_rid),
        .dma_axi_rdata            (dma_axi_rdata),
        .dma_axi_rresp            (dma_axi_rresp),
        .dma_axi_rlast            (dma_axi_rlast),
        // s01
        .s01_axi_awid             (s01_axi_awid),
        .s01_axi_awaddr           (s01_axi_awaddr),
        .s01_axi_awlen            (s01_axi_awlen),
        .s01_axi_awsize           (s01_axi_awsize),
        .s01_axi_awburst          (s01_axi_awburst),
        .s01_axi_awlock           (s01_axi_awlock),
        .s01_axi_awcache          (s01_axi_awcache),
        .s01_axi_awprot           (s01_axi_awprot),
        .s01_axi_awqos            (s01_axi_awqos),
        .s01_axi_awvalid          (s01_axi_awvalid),
        .s01_axi_awready          (s01_axi_awready),
        .s01_axi_wdata            (s01_axi_wdata),
        .s01_axi_wstrb            (s01_axi_wstrb),
        .s01_axi_wlast            (s01_axi_wlast),
        .s01_axi_wvalid           (s01_axi_wvalid),
        .s01_axi_wready           (s01_axi_wready),
        .s01_axi_bid              (s01_axi_bid),
        .s01_axi_bresp            (s01_axi_bresp),
        .s01_axi_bvalid           (s01_axi_bvalid),
        .s01_axi_bready           (s01_axi_bready),
        .s01_axi_arid             (s01_axi_arid),
        .s01_axi_araddr           (s01_axi_araddr),
        .s01_axi_arlen            (s01_axi_arlen),
        .s01_axi_arsize           (s01_axi_arsize),
        .s01_axi_arburst          (s01_axi_arburst),
        .s01_axi_arlock           (s01_axi_arlock),
        .s01_axi_arcache          (s01_axi_arcache),
        .s01_axi_arprot           (s01_axi_arprot),
        .s01_axi_arqos            (s01_axi_arqos),
        .s01_axi_arvalid          (s01_axi_arvalid),
        .s01_axi_arready          (s01_axi_arready),
        .s01_axi_rid              (s01_axi_rid),
        .s01_axi_rdata            (s01_axi_rdata),
        .s01_axi_rresp            (s01_axi_rresp),
        .s01_axi_rlast            (s01_axi_rlast),
        .s01_axi_rvalid           (s01_axi_rvalid),
        .s01_axi_rready           (s01_axi_rready),
        // Trace
        .trace_rv_i_insn_ip       (trace_rv_i_insn_ip),
        .trace_rv_i_address_ip    (trace_rv_i_address_ip),
        .trace_rv_i_valid_ip      (trace_rv_i_valid_ip),
        .trace_rv_i_exception_ip  (trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip     (trace_rv_i_ecause_ip),
        .trace_rv_i_interrupt_ip  (trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip       (trace_rv_i_tval_ip),
        // ECC
        .iccm_ecc_single_error    (iccm_ecc_single_error),
        .iccm_ecc_double_error    (iccm_ecc_double_error),
        .dccm_ecc_single_error    (dccm_ecc_single_error),
        .dccm_ecc_double_error    (dccm_ecc_double_error),
        .dccm_write_readback_error(dccm_write_readback_error),
        // Perf
        .dec_tlu_perfcnt0         (dec_tlu_perfcnt0),
        .dec_tlu_perfcnt1         (dec_tlu_perfcnt1),
        .dec_tlu_perfcnt2         (dec_tlu_perfcnt2),
        .dec_tlu_perfcnt3         (dec_tlu_perfcnt3),
        // JTAG
        .jtag_tck                 (1'b0),
        .jtag_tms                 (1'b0),
        .jtag_tdi                 (1'b0),
        .jtag_trst_n              (1'b1),
        .jtag_tdo                 (jtag_tdo),
        .jtag_tdoEn               (jtag_tdoEn),
        // MPC
        .mpc_debug_halt_req       (1'b0),
        .mpc_debug_run_req        (1'b0),
        .mpc_reset_run_req        (1'b1),
        .mpc_debug_halt_ack       (mpc_debug_halt_ack),
        .mpc_debug_run_ack        (mpc_debug_run_ack),
        .debug_brkpt_status       (debug_brkpt_status),
        .i_cpu_halt_req           (1'b0),
        .o_cpu_halt_ack           (o_cpu_halt_ack),
        .o_cpu_halt_status        (o_cpu_halt_status),
        .o_debug_mode_status      (o_debug_mode_status),
        .i_cpu_run_req            (1'b0),
        .o_cpu_run_ack            (o_cpu_run_ack),
        // Misc
        .lsu_bus_clk_en           (1'b1),
        .ifu_bus_clk_en           (1'b1),
        .dbg_bus_clk_en           (1'b1),
        .dma_bus_clk_en           (1'b1),
        .scan_mode                (1'b0),
        .mbist_mode               (1'b0),
        // DMI
        .dmi_core_enable          (1'b1),
        .dmi_uncore_enable        (1'b0),
        .dmi_uncore_en            (dmi_uncore_en),
        .dmi_uncore_wr_en         (dmi_uncore_wr_en),
        .dmi_uncore_addr          (dmi_uncore_addr),
        .dmi_uncore_wdata         (dmi_uncore_wdata),
        .dmi_uncore_rdata         (32'h0),
        .dmi_active               (dmi_active)
    );

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $fsdbDumpfile("veer_wrapper_uart_integrated_tb.fsdb");
        $fsdbDumpvars(0, veer_wrapper_uart_integrated_tb);
        $fsdbDumpMDA();
        $fsdbDumpSVA();
        $dumpfile("veer_wrapper_uart_integrated_tb.vcd");
        $dumpvars(0, veer_wrapper_uart_integrated_tb);
        $display("================================================================");
        $display(" TESTBENCH : veer_wrapper_uart_integrated_tb");
        $display(" Waveform  : .fsdb (Verdi) / .vcd (GTKWave)");
        $display("================================================================");
    end

    // =========================================================================
    // $monitor – continuous tracking
    // =========================================================================
    initial begin
        $monitor("[MON @%0t ns] rst_l=%b uart_tx=%b uart_rx=%b uart_irq=%b | trace_valid=%b PC=0x%08h insn=0x%08h",
                  $time, rst_l, uart_tx_o, uart_rx_i, uart_read_irq_o,
                  trace_rv_i_valid_ip, trace_rv_i_address_ip, trace_rv_i_insn_ip);
    end

    // =========================================================================
    // AXI4 BFM: single-beat write on s01
    // =========================================================================
    task axi4_write_s01;
        input [ADDR_WIDTH-1:0]    addr;
        input [DATA_WIDTH-1:0]    data;
        input [IC_ID_WIDTH-1:0]   id;
        integer timeout;
        begin
            $display("[BFM_W @%0t ns] s01 WRITE addr=0x%08h data=0x%08h id=%0d",
                      $time, addr, data, id);
            // AW
            @(negedge clk);
            s01_axi_awid    <= id;
            s01_axi_awaddr  <= addr;
            s01_axi_awlen   <= 8'd0;
            s01_axi_awsize  <= 3'd2;
            s01_axi_awburst <= 2'b01;
            s01_axi_awlock  <= 1'b0;
            s01_axi_awcache <= 4'h0;
            s01_axi_awprot  <= 3'b000;
            s01_axi_awqos   <= 4'h0;
            s01_axi_awvalid <= 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!s01_axi_awready && timeout < TIMEOUT_CYC) begin
                @(posedge clk); timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC) $display("[WARN @%0t ns] s01 AW timeout", $time);
            @(negedge clk);
            s01_axi_awvalid <= 1'b0;
            // W
            s01_axi_wdata  <= data;
            s01_axi_wstrb  <= {(DATA_WIDTH/8){1'b1}};
            s01_axi_wlast  <= 1'b1;
            s01_axi_wvalid <= 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!s01_axi_wready && timeout < TIMEOUT_CYC) begin
                @(posedge clk); timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC) $display("[WARN @%0t ns] s01 W  timeout", $time);
            @(negedge clk);
            s01_axi_wvalid <= 1'b0;
            s01_axi_wlast  <= 1'b0;
            // B
            s01_axi_bready <= 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!s01_axi_bvalid && timeout < TIMEOUT_CYC) begin
                @(posedge clk); timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC)
                $display("[WARN @%0t ns] s01 B  timeout", $time);
            else
                $display("[BFM_W @%0t ns] s01 B resp=%b id=%0d",
                          $time, s01_axi_bresp, s01_axi_bid);
            @(negedge clk);
            s01_axi_bready <= 1'b0;
        end
    endtask

    // =========================================================================
    // AXI4 BFM: single-beat read on s01
    // =========================================================================
    task axi4_read_s01;
        input [ADDR_WIDTH-1:0]   addr;
        input [IC_ID_WIDTH-1:0]  id;
        integer timeout;
        begin
            $display("[BFM_R @%0t ns] s01 READ  addr=0x%08h id=%0d", $time, addr, id);
            // AR
            @(negedge clk);
            s01_axi_arid    <= id;
            s01_axi_araddr  <= addr;
            s01_axi_arlen   <= 8'd0;
            s01_axi_arsize  <= 3'd2;
            s01_axi_arburst <= 2'b01;
            s01_axi_arlock  <= 1'b0;
            s01_axi_arcache <= 4'h0;
            s01_axi_arprot  <= 3'b000;
            s01_axi_arqos   <= 4'h0;
            s01_axi_arvalid <= 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!s01_axi_arready && timeout < TIMEOUT_CYC) begin
                @(posedge clk); timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC) $display("[WARN @%0t ns] s01 AR timeout", $time);
            @(negedge clk);
            s01_axi_arvalid <= 1'b0;
            // R
            s01_axi_rready <= 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!s01_axi_rvalid && timeout < TIMEOUT_CYC) begin
                @(posedge clk); timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC) begin
                $display("[WARN @%0t ns] s01 R  timeout", $time);
                bfm_rdata = 32'hDEAD_BEEF;
            end else begin
                bfm_rdata = s01_axi_rdata;
                $display("[BFM_R @%0t ns] s01 R  data=0x%08h resp=%b id=%0d",
                          $time, s01_axi_rdata, s01_axi_rresp, s01_axi_rid);
            end
            @(negedge clk);
            s01_axi_rready <= 1'b0;
        end
    endtask

    // =========================================================================
    // wait_cycles task
    // =========================================================================
    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    // =========================================================================
    // Reset task
    // =========================================================================
    task do_reset;
        begin
            $display("\n[RST @%0t ns] Asserting reset (rst_l=0)", $time);
            rst_l     = 1'b0;
            dbg_rst_l = 1'b0;
            repeat(RST_CYCLES) @(posedge clk);
            @(negedge clk);
            rst_l     = 1'b1;
            dbg_rst_l = 1'b1;
            $display("[RST @%0t ns] Reset de-asserted (rst_l=1)", $time);
            wait_cycles(5);
        end
    endtask

    // =========================================================================
    // UART TX bit-level monitor
    // =========================================================================
    always @(negedge uart_tx_o) begin : uart_tx_mon
        integer bit_idx;
        $display("[UART_TX_MON @%0t ns] Start bit on uart_tx_o", $time);
        #(CLK_PERIOD * BAUD_DIV * 1.5);
        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            rx_capture[bit_idx] = uart_tx_o;
            $display("[UART_TX_MON @%0t ns]   bit[%0d]=%b", $time, bit_idx, uart_tx_o);
            #(CLK_PERIOD * BAUD_DIV);
        end
        rx_byte_count = rx_byte_count + 1;
        rx_done = 1'b1;
        $display("[UART_TX_MON @%0t ns] Byte #%0d = 0x%02h (ASCII=%0d)",
                  $time, rx_byte_count, rx_capture, rx_capture);
        #1;
        rx_done = 1'b0;
    end

    // =========================================================================
    // Continuous monitors
    // =========================================================================
    always @(posedge clk) begin
        if (rst_l) begin
            if (uart_tx_o === 1'bx)
                $display("[ASSERT @%0t ns] ERROR: uart_tx_o is X", $time);
            if (s01_axi_awready === 1'bx)
                $display("[ASSERT @%0t ns] ERROR: s01_axi_awready is X", $time);
            if (s01_axi_arready === 1'bx)
                $display("[ASSERT @%0t ns] ERROR: s01_axi_arready is X", $time);
        end
    end

    always @(posedge clk) begin
        if (rst_l && trace_rv_i_valid_ip)
            $display("[TRACE @%0t ns] PC=0x%08h insn=0x%08h exc=%b int=%b",
                      $time, trace_rv_i_address_ip, trace_rv_i_insn_ip,
                      trace_rv_i_exception_ip, trace_rv_i_interrupt_ip);
    end

    always @(posedge clk) begin
        if (rst_l) begin
            if (iccm_ecc_double_error)
                $display("[ECC @%0t ns] ICCM double-bit error!", $time);
            if (dccm_ecc_double_error)
                $display("[ECC @%0t ns] DCCM double-bit error!", $time);
        end
    end

    // =========================================================================
    // Watchdog
    // =========================================================================
    initial begin
        #(CLK_PERIOD * 200000);
        $display("[WATCHDOG @%0t ns] Max time exceeded. Aborting.", $time);
        $finish;
    end

    // =========================================================================
    // Main test sequence
    // =========================================================================
    integer tc_pass;
    integer cnt;
    integer ci;
    reg [7:0] tx_chars [0:2];

    initial begin : tb_main
        pass_count    = 0;
        fail_count    = 0;
        rx_capture    = 8'h00;
        rx_done       = 1'b0;
        rx_byte_count = 0;

        rst_l         = 1'b0;
        dbg_rst_l     = 1'b0;
        rst_vec       = 31'h0000_0000;
        nmi_vec       = 31'h1ee1_0000;
        jtag_id       = 31'h0000_0001;
        core_id       = 28'h000_0000;
        nmi_int       = 1'b0;
        timer_int     = 1'b0;
        soft_int      = 1'b0;
        extintsrc_req = {PIC_TOTAL_INT{1'b0}};
        uart_rx_i     = 1'b1;

        s01_axi_awvalid = 1'b0; s01_axi_awid    = {IC_ID_WIDTH{1'b0}};
        s01_axi_awaddr  = 0;    s01_axi_awlen   = 0;
        s01_axi_awsize  = 0;    s01_axi_awburst = 0;
        s01_axi_awlock  = 0;    s01_axi_awcache = 0;
        s01_axi_awprot  = 0;    s01_axi_awqos   = 0;
        s01_axi_wvalid  = 1'b0; s01_axi_wdata   = 0;
        s01_axi_wstrb   = 0;    s01_axi_wlast   = 0;
        s01_axi_bready  = 1'b0; s01_axi_arvalid = 1'b0;
        s01_axi_arid    = {IC_ID_WIDTH{1'b0}};
        s01_axi_araddr  = 0;    s01_axi_arlen   = 0;
        s01_axi_arsize  = 0;    s01_axi_arburst = 0;
        s01_axi_arlock  = 0;    s01_axi_arcache = 0;
        s01_axi_arprot  = 0;    s01_axi_arqos   = 0;
        s01_axi_rready  = 1'b0;

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

        tx_chars[0] = 8'h48;   // 'H'
        tx_chars[1] = 8'h69;   // 'i'
        tx_chars[2] = 8'h21;   // '!'

        // ------------------------------------------------------------------
        // TC1 : Reset
        // ------------------------------------------------------------------
        $display("\n========================================================");
        $display(" TC1 : Reset de-assertion / power-on");
        $display("========================================================");
        do_reset;
        wait_cycles(2);
        tc_pass = (s01_axi_awready !== 1'bx) &&
                  (s01_axi_arready !== 1'bx) &&
                  (uart_tx_o      !== 1'bx);
        if (tc_pass) begin
            $display("[PASS] TC1 : Reset de-assertion  @ %0t ns", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC1 : Reset de-assertion  @ %0t ns", $time);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // TC2 : UART register init
        // ------------------------------------------------------------------
        $display("\n========================================================");
        $display(" TC2 : UART register init (BAUD+LCR+IER) via s01");
        $display("========================================================");
        axi4_write_s01(UART_BAUD_REG, 32'd4,         8'h01);
        wait_cycles(2);
        axi4_write_s01(UART_LCR_REG,  32'h0000_0003, 8'h02);
        wait_cycles(2);
        axi4_write_s01(UART_IER_REG,  32'h0000_0001, 8'h03);
        wait_cycles(2);
        axi4_read_s01(UART_LCR_REG, 8'h04);
        tc_pass = (bfm_rdata[1:0] == 2'b11);
        $display("[TC2 @%0t ns] LCR=0x%08h expected[1:0]=11 %s",
                  $time, bfm_rdata, tc_pass ? "PASS" : "FAIL");
        if (tc_pass) begin
            $display("[PASS] TC2 : UART BAUD+LCR+IER init  @ %0t ns", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC2 : UART BAUD+LCR+IER init  @ %0t ns", $time);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // TC3 : UART TX 'A' (0x41)
        // ------------------------------------------------------------------
        $display("\n========================================================");
        $display(" TC3 : UART TX write 0x41 via s01 THR");
        $display("========================================================");
        rx_done = 1'b0;
        axi4_write_s01(UART_THR_REG, 32'h0000_0041, 8'h05);
        cnt = 0;
        while (!rx_done && cnt < TIMEOUT_CYC) begin
            @(posedge clk); cnt = cnt + 1;
        end
        tc_pass = rx_done && (rx_capture == 8'h41);
        $display("[TC3 @%0t ns] captured=0x%02h expected=0x41 %s",
                  $time, rx_capture, tc_pass ? "PASS" : "FAIL");
        if (tc_pass) begin
            $display("[PASS] TC3 : UART TX 0x41  @ %0t ns", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC3 : UART TX 0x41  @ %0t ns", $time);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // TC4 : RX loopback
        // ------------------------------------------------------------------
        $display("\n========================================================");
        $display(" TC4 : UART RX loopback (uart_tx_o -> uart_rx_i)");
        $display("========================================================");
        fork
            begin : lb_drv
                forever @(uart_tx_o) uart_rx_i = uart_tx_o;
            end
        join_none

        rx_done = 1'b0;
        axi4_write_s01(UART_THR_REG, 32'h0000_0042, 8'h06);
        cnt = 0;
        while (!rx_done && cnt < TIMEOUT_CYC) begin
            @(posedge clk); cnt = cnt + 1;
        end
        wait_cycles(10);
        axi4_read_s01(UART_LSR_REG, 8'h07);
        $display("[TC4 @%0t ns] LSR=0x%08h RX_data_ready(bit0)=%b",
                  $time, bfm_rdata, bfm_rdata[0]);
        tc_pass = rx_done && (rx_capture == 8'h42);
        if (tc_pass) begin
            $display("[PASS] TC4 : UART RX loopback  @ %0t ns", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC4 : UART RX loopback  @ %0t ns", $time);
            fail_count = fail_count + 1;
        end
        disable lb_drv;
        uart_rx_i = 1'b1;

        // ------------------------------------------------------------------
        // TC5 : RX interrupt
        // ------------------------------------------------------------------
        $display("\n========================================================");
        $display(" TC5 : UART RX interrupt assertion & clear");
        $display("========================================================");
        fork
            begin : lb_drv2
                forever @(uart_tx_o) uart_rx_i = uart_tx_o;
            end
        join_none

        rx_done = 1'b0;
        axi4_write_s01(UART_THR_REG, 32'h0000_0055, 8'h08);
        cnt = 0;
        while (!rx_done && cnt < TIMEOUT_CYC) begin
            @(posedge clk); cnt = cnt + 1;
        end
        wait_cycles(5);
        $display("[TC5 @%0t ns] uart_read_irq_o=%b (expected 1)", $time, uart_read_irq_o);
        tc_pass = (uart_read_irq_o == 1'b1);
        if (tc_pass) begin
            $display("[PASS] TC5 : RX interrupt assertion  @ %0t ns", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC5 : RX interrupt assertion  @ %0t ns", $time);
            fail_count = fail_count + 1;
        end
        disable lb_drv2;
        uart_rx_i = 1'b1;

        axi4_read_s01(UART_RBR_REG, 8'h09);
        $display("[TC5 @%0t ns] RBR=0x%02h (clears IRQ)", $time, bfm_rdata[7:0]);
        wait_cycles(3);
        $display("[TC5 @%0t ns] uart_read_irq_o after clear=%b (expected 0)",
                  $time, uart_read_irq_o);

        // ------------------------------------------------------------------
        // TC6 : s01 write + read-back
        // ------------------------------------------------------------------
        $display("\n========================================================");
        $display(" TC6 : s01 secondary-master write + read-back");
        $display("========================================================");
        axi4_write_s01(UART_IER_REG, 32'h0000_0001, 8'h0A);
        wait_cycles(2);
        axi4_read_s01(UART_IER_REG, 8'h0B);
        tc_pass = (bfm_rdata[0] == 1'b1);
        $display("[TC6 @%0t ns] IER=0x%08h expected bit0=1 %s",
                  $time, bfm_rdata, tc_pass ? "PASS" : "FAIL");
        if (tc_pass) begin
            $display("[PASS] TC6 : s01 write+read-back  @ %0t ns", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC6 : s01 write+read-back  @ %0t ns", $time);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // TC7 : DMA port idle
        // ------------------------------------------------------------------
        $display("\n========================================================");
        $display(" TC7 : DMA AXI slave idle handshake check");
        $display("========================================================");
        wait_cycles(2);
        tc_pass = (dma_axi_awready !== 1'bx) && (dma_axi_arready !== 1'bx);
        $display("[TC7 @%0t ns] dma_awready=%b dma_arready=%b",
                  $time, dma_axi_awready, dma_axi_arready);
        if (tc_pass) begin
            $display("[PASS] TC7 : DMA port idle  @ %0t ns", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC7 : DMA port idle  @ %0t ns", $time);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // TC8 : IFU arvalid
        // ------------------------------------------------------------------
        $display("\n========================================================");
        $display(" TC8 : IFU AXI arvalid observed (VeeR fetching insns)");
        $display("========================================================");
        cnt = 0;
        while (!ifu_axi_arvalid && cnt < TIMEOUT_CYC) begin
            @(posedge clk); cnt = cnt + 1;
        end
        tc_pass = (cnt < TIMEOUT_CYC);
        $display("[TC8 @%0t ns] ifu_axi_arvalid=%b araddr=0x%08h",
                  $time, ifu_axi_arvalid, ifu_axi_araddr);
        if (tc_pass) begin
            $display("[PASS] TC8 : IFU arvalid seen  @ %0t ns", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC8 : IFU arvalid seen  @ %0t ns", $time);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // TC9 : Concurrent s01 + IFU
        // ------------------------------------------------------------------
        $display("\n========================================================");
        $display(" TC9 : Concurrent s01 + IFU traffic (arbitration)");
        $display("========================================================");
        fork
            begin
                axi4_write_s01(UART_LCR_REG, 32'h0000_0003, 8'h0C);
                $display("[TC9 @%0t ns] s01 concurrent write done", $time);
            end
        join
        wait_cycles(4);
        tc_pass = (s01_axi_awready !== 1'bx);
        if (tc_pass) begin
            $display("[PASS] TC9 : Concurrent access  @ %0t ns", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC9 : Concurrent access  @ %0t ns", $time);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // TC10 : TX burst H / i / !
        // ------------------------------------------------------------------
        $display("\n========================================================");
        $display(" TC10: UART TX burst H(0x48) i(0x69) !(0x21)");
        $display("========================================================");
        tc_pass = 1;
        for (ci = 0; ci < 3; ci = ci + 1) begin
            rx_done = 1'b0;
            $display("[TC10 @%0t ns] Sending 0x%02h to THR", $time, tx_chars[ci]);
            axi4_write_s01(UART_THR_REG, {24'h0, tx_chars[ci]}, 8'h10 + ci[7:0]);
            cnt = 0;
            while (!rx_done && cnt < TIMEOUT_CYC) begin
                @(posedge clk); cnt = cnt + 1;
            end
            if (cnt >= TIMEOUT_CYC) begin
                $display("[TC10 @%0t ns] TX timeout ci=%0d", $time, ci);
                tc_pass = 0;
            end else if (rx_capture !== tx_chars[ci]) begin
                $display("[TC10 @%0t ns] Mismatch got=0x%02h exp=0x%02h",
                          $time, rx_capture, tx_chars[ci]);
                tc_pass = 0;
            end
            // Poll THRE (LSR[5])
            cnt = 0;
            axi4_read_s01(UART_LSR_REG, 8'h13 + ci[7:0]);
            while (!bfm_rdata[5] && cnt < TIMEOUT_CYC) begin
                @(posedge clk); cnt = cnt + 1;
            end
            $display("[TC10 @%0t ns] LSR[5]=THRE=%b for 0x%02h",
                      $time, bfm_rdata[5], tx_chars[ci]);
        end
        if (tc_pass) begin
            $display("[PASS] TC10: UART TX burst H/i/!  @ %0t ns", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC10: UART TX burst H/i/!  @ %0t ns", $time);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("\n================================================================");
        $display(" SIMULATION COMPLETE");
        $display("   PASS : %0d", pass_count);
        $display("   FAIL : %0d", fail_count);
        $display("================================================================");
        if (fail_count == 0)
            $display(">>> ALL TESTS PASSED <<<\n");
        else
            $display(">>> %0d TEST(S) FAILED - inspect waveform <<<\n", fail_count);
        $finish;
    end

endmodule
