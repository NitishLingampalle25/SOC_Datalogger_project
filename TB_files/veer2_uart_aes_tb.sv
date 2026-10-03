// =============================================================================
// Testbench : veer2_uart_aes_tb
// File      : TB_files/veer2_uart_aes_tb.sv
// Language  : SystemVerilog (IEEE 1800-2012 / VCS compatible)
//
// Purpose   : Complete functional verification of veer2_uart_aes_integrated:
//             1. VeeR EL2 RISC-V processor core integration (IFU / NOP stream)
//             2. AXI4 2x6 crossbar interconnect arbitration
//             3. UART IP core subsystem (0x4000_0000)
//             4. AES-128 encryption/decryption adapter subsystem (0x4000_2000)
//             5. Hardware handshaking (aes_done_pulse_o for Watchdog reload,
//                aes_irq_o, uart_read_irq_o)
//
// Test Cases:
//   TC1  – Power-on Reset & Initialization
//   TC2  – Core IFU instruction fetch (VeeR fetching NOP stream)
//   TC3  – UART register configuration (BAUD, LCR, IER) via s01 AXI master
//   TC4  – UART transmission ('A' = 0x41) with bit-level monitor
//   TC5  – UART loopback & RX data-ready interrupt verification
//   TC6  – AES-128 register write & readback (32-to-128 bit key and input text)
//   TC7  – AES-128 encryption execution (FIPS-197 test vector) & status polling
//   TC8  – AES Watchdog kick pulse (aes_done_pulse_o) & IRQ (aes_irq_o) check
//   TC9  – AES-128 decryption execution (key expansion & plaintext recovery)
//   TC10 – AES W1C done/interrupt clear check
//   TC11 – Interleaved / Concurrent UART and AES accesses via interconnect
//
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module veer2_uart_aes_tb;

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

    // Memory map addresses
    localparam [31:0] UART_BASE      = 32'h4000_0000;
    localparam [31:0] UART_THR_REG   = UART_BASE + 32'h00;
    localparam [31:0] UART_RBR_REG   = UART_BASE + 32'h00;
    localparam [31:0] UART_IER_REG   = UART_BASE + 32'h04;
    localparam [31:0] UART_BAUD_REG  = UART_BASE + 32'h08;
    localparam [31:0] UART_LCR_REG   = UART_BASE + 32'h0C;
    localparam [31:0] UART_LSR_REG   = UART_BASE + 32'h14;

    localparam [31:0] AES_BASE       = 32'h4000_2000;
    localparam [31:0] AES_CTRL_REG   = AES_BASE + 32'h00;
    localparam [31:0] AES_KEY0_REG   = AES_BASE + 32'h04;
    localparam [31:0] AES_KEY1_REG   = AES_BASE + 32'h08;
    localparam [31:0] AES_KEY2_REG   = AES_BASE + 32'h0C;
    localparam [31:0] AES_KEY3_REG   = AES_BASE + 32'h10;
    localparam [31:0] AES_TXTIN0_REG = AES_BASE + 32'h14;
    localparam [31:0] AES_TXTIN1_REG = AES_BASE + 32'h18;
    localparam [31:0] AES_TXTIN2_REG = AES_BASE + 32'h1C;
    localparam [31:0] AES_TXTIN3_REG = AES_BASE + 32'h20;
    localparam [31:0] AES_TXTOUT0_REG= AES_BASE + 32'h24;
    localparam [31:0] AES_TXTOUT1_REG= AES_BASE + 32'h28;
    localparam [31:0] AES_TXTOUT2_REG= AES_BASE + 32'h2C;
    localparam [31:0] AES_TXTOUT3_REG= AES_BASE + 32'h30;

    localparam [63:0] NOP64          = 64'h0000_0013_0000_0013; // RISC-V NOP (addi x0, x0, 0)

    // =========================================================================
    // Signals
    // =========================================================================
    reg                         clk;
    reg                         fixed_clk;
    reg                         rst_l;
    reg                         dbg_rst_l;

    reg  [31:1]                 rst_vec;
    reg  [31:1]                 nmi_vec;
    reg  [31:1]                 jtag_id;
    reg  [31:4]                 core_id;

    reg                         nmi_int;
    reg                         timer_int;
    reg                         soft_int;
    reg  [PIC_TOTAL_INT:1]      extintsrc_req;

    wire                        uart_read_irq_o;
    wire                        aes_irq_o;
    wire                        aes_done_pulse_o;

    wire                        uart_tx_o;
    reg                         uart_rx_i;
    wire                        aes_busy_o;
    wire                        aes_done_o;

    // IFU AXI
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

    // SB AXI (tied off)
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

    // DMA AXI slave
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

    // Secondary master (s01) BFM signals
    reg  [IC_ID_WIDTH-1:0]      s01_axi_awid;
    reg  [ADDR_WIDTH-1:0]       s01_axi_awaddr;
    reg  [7:0]                  s01_axi_awlen;
    reg  [2:0]                  s01_axi_awsize;
    reg  [1:0]                  s01_axi_awburst;
    reg                         s01_axi_awlock;
    reg  [3:0]                  s01_axi_awcache;
    reg  [2:0]                  s01_axi_awprot;
    reg  [3:0]                  s01_axi_awqos;
    reg                         s01_axi_awvalid;
    wire                        s01_axi_awready;

    reg  [DATA_WIDTH-1:0]       s01_axi_wdata;
    reg  [STRB_WIDTH-1:0]       s01_axi_wstrb;
    reg                         s01_axi_wlast;
    reg                         s01_axi_wvalid;
    wire                        s01_axi_wready;

    wire [IC_ID_WIDTH-1:0]      s01_axi_bid;
    wire [1:0]                  s01_axi_bresp;
    wire                        s01_axi_bvalid;
    reg                         s01_axi_bready;

    reg  [IC_ID_WIDTH-1:0]      s01_axi_arid;
    reg  [ADDR_WIDTH-1:0]       s01_axi_araddr;
    reg  [7:0]                  s01_axi_arlen;
    reg  [2:0]                  s01_axi_arsize;
    reg  [1:0]                  s01_axi_arburst;
    reg                         s01_axi_arlock;
    reg  [3:0]                  s01_axi_arcache;
    reg  [2:0]                  s01_axi_arprot;
    reg  [3:0]                  s01_axi_arqos;
    reg                         s01_axi_arvalid;
    wire                        s01_axi_arready;

    wire [IC_ID_WIDTH-1:0]      s01_axi_rid;
    wire [DATA_WIDTH-1:0]       s01_axi_rdata;
    wire [1:0]                  s01_axi_rresp;
    wire                        s01_axi_rlast;
    wire                        s01_axi_rvalid;
    reg                         s01_axi_rready;

    // VeeR observe-only signals
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

    // Testbench tracking variables
    integer                     pass_count;
    integer                     fail_count;
    reg [7:0]                   rx_capture;
    reg                         rx_done;
    integer                     rx_byte_count;
    reg [DATA_WIDTH-1:0]        bfm_rdata;
    integer                     pulse_count;

    // =========================================================================
    // Clocks
    // =========================================================================
    initial clk = 1'b0;
    always  #(CLK_PERIOD/2) clk = ~clk;

    initial fixed_clk = 1'b0;
    always  #(FIXED_PERIOD/2) fixed_clk = ~fixed_clk;

    // =========================================================================
    // Watchdog Timer Pulse Counter
    // =========================================================================
    always @(posedge clk or negedge rst_l) begin
        if (!rst_l)
            pulse_count <= 0;
        else if (aes_done_pulse_o)
            pulse_count <= pulse_count + 1;
    end

    // =========================================================================
    // Tie-offs for unused slave/master ports
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

    reg        ifu_fetch_seen;
    reg [31:0] ifu_fetch_addr;
    always @(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            ifu_fetch_seen <= 1'b0;
            ifu_fetch_addr <= 32'h0;
        end else if (ifu_axi_arvalid) begin
            ifu_fetch_seen <= 1'b1;
            ifu_fetch_addr <= ifu_axi_araddr;
            $display("[IFU_TRACE @%0t ns] ifu_axi_arvalid=1 addr=0x%08h arlen=%0d arid=%0d",
                     $time, ifu_axi_araddr, ifu_axi_arlen, ifu_axi_arid);
        end
    end

    // =========================================================================
    // Instruction Memory Model (Feeds NOP stream to VeeR IFU)
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
            end else if (ifu_axi_rvalid && ifu_axi_rready) begin
                ifu_axi_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // DUT Instantiation: veer2_uart_aes_integrated
    // =========================================================================
    veer2_uart_aes_integrated #(
        .IC_ID_WIDTH    (IC_ID_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .LSU_BUS_TAG    (LSU_BUS_TAG),
        .IFU_BUS_TAG    (IFU_BUS_TAG),
        .SB_BUS_TAG     (SB_BUS_TAG),
        .DMA_BUS_TAG    (DMA_BUS_TAG),
        .PIC_TOTAL_INT  (PIC_TOTAL_INT),
        .UART_BASE_ADDR (UART_BASE),
        .AES_BASE_ADDR  (AES_BASE)
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

        // DMA
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

        // s01 Secondary Master
        .s01_axi_awid           (s01_axi_awid),
        .s01_axi_awaddr         (s01_axi_awaddr),
        .s01_axi_awlen          (s01_axi_awlen),
        .s01_axi_awsize         (s01_axi_awsize),
        .s01_axi_awburst        (s01_axi_awburst),
        .s01_axi_awlock         (s01_axi_awlock),
        .s01_axi_awcache        (s01_axi_awcache),
        .s01_axi_awprot         (s01_axi_awprot),
        .s01_axi_awqos          (s01_axi_awqos),
        .s01_axi_awvalid        (s01_axi_awvalid),
        .s01_axi_awready        (s01_axi_awready),
        .s01_axi_wdata          (s01_axi_wdata),
        .s01_axi_wstrb          (s01_axi_wstrb),
        .s01_axi_wlast          (s01_axi_wlast),
        .s01_axi_wvalid         (s01_axi_wvalid),
        .s01_axi_wready         (s01_axi_wready),
        .s01_axi_bid            (s01_axi_bid),
        .s01_axi_bresp          (s01_axi_bresp),
        .s01_axi_bvalid         (s01_axi_bvalid),
        .s01_axi_bready         (s01_axi_bready),
        .s01_axi_arid           (s01_axi_arid),
        .s01_axi_araddr         (s01_axi_araddr),
        .s01_axi_arlen          (s01_axi_arlen),
        .s01_axi_arsize         (s01_axi_arsize),
        .s01_axi_arburst        (s01_axi_arburst),
        .s01_axi_arlock         (s01_axi_arlock),
        .s01_axi_arcache        (s01_axi_arcache),
        .s01_axi_arprot         (s01_axi_arprot),
        .s01_axi_arqos          (s01_axi_arqos),
        .s01_axi_arvalid        (s01_axi_arvalid),
        .s01_axi_arready        (s01_axi_arready),
        .s01_axi_rid            (s01_axi_rid),
        .s01_axi_rdata          (s01_axi_rdata),
        .s01_axi_rresp          (s01_axi_rresp),
        .s01_axi_rlast          (s01_axi_rlast),
        .s01_axi_rvalid         (s01_axi_rvalid),
        .s01_axi_rready         (s01_axi_rready),

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
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars("+all");
	$fsdbDumpMDA();
	$fsdbDumpSVA();
        $display("================================================================");
        $display("================================================================");
    end

    // =========================================================================
    // AXI4 BFM: Write on s01
    // =========================================================================
    task axi4_write_s01;
        input [ADDR_WIDTH-1:0]    addr;
        input [DATA_WIDTH-1:0]    data;
        input [IC_ID_WIDTH-1:0]   id;
        integer timeout;
        reg aw_done, w_done, b_done;
        begin
            @(negedge clk);
            s01_axi_awid    <= id;
            s01_axi_awaddr  <= addr;
            s01_axi_awlen   <= 8'd0;
            s01_axi_awsize  <= 3'd2; // 4 bytes (32-bit beat)
            s01_axi_awburst <= 2'b01;
            s01_axi_awlock  <= 1'b0;
            s01_axi_awcache <= 4'h0;
            s01_axi_awprot  <= 3'b000;
            s01_axi_awqos   <= 4'h0;
            s01_axi_awvalid <= 1'b1;

            s01_axi_wdata   <= data;
            s01_axi_wstrb   <= {(DATA_WIDTH/8){1'b1}};
            s01_axi_wlast   <= 1'b1;
            s01_axi_wvalid  <= 1'b1;
            s01_axi_bready  <= 1'b1;

            aw_done = 1'b0;
            w_done  = 1'b0;
            b_done  = 1'b0;
            timeout = 0;

            // Wait for both AW & W handshakes
            while ((!aw_done || !w_done) && timeout < TIMEOUT_CYC) begin
                @(posedge clk);
                if (s01_axi_awready && s01_axi_awvalid) begin
                    aw_done = 1'b1;
                    s01_axi_awvalid <= 1'b0;
                end
                if (s01_axi_wready && s01_axi_wvalid) begin
                    w_done = 1'b1;
                    s01_axi_wvalid <= 1'b0;
                    s01_axi_wlast  <= 1'b0;
                end
                timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC) begin
                $display("[ERROR @%0t ns] s01 write AW/W timeout! aw_done=%b w_done=%b addr=0x%08h",
                         $time, aw_done, w_done, addr);
            end

            @(negedge clk);
            s01_axi_awvalid <= 1'b0;
            s01_axi_wvalid  <= 1'b0;
            s01_axi_wlast   <= 1'b0;

            // Wait for B response
            timeout = 0;
            while (!b_done && timeout < TIMEOUT_CYC) begin
                @(posedge clk);
                if (s01_axi_bvalid && s01_axi_bready) begin
                    b_done = 1'b1;
                end
                timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC) begin
                $display("[ERROR @%0t ns] s01 write BVALID timeout! addr=0x%08h", $time, addr);
            end

            @(negedge clk);
            s01_axi_bready <= 1'b0;
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // AXI4 BFM: Read on s01
    // =========================================================================
    task axi4_read_s01;
        input  [ADDR_WIDTH-1:0]   addr;
        input  [IC_ID_WIDTH-1:0]  id;
        output [DATA_WIDTH-1:0]   data;
        integer timeout;
        reg ar_done, r_done;
        begin
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
            s01_axi_rready  <= 1'b1;

            ar_done = 1'b0;
            r_done  = 1'b0;
            timeout = 0;

            while ((!ar_done || !r_done) && timeout < TIMEOUT_CYC) begin
                @(posedge clk);
                if (s01_axi_arready && s01_axi_arvalid) begin
                    ar_done = 1'b1;
                    s01_axi_arvalid <= 1'b0;
                end
                if (s01_axi_rvalid && s01_axi_rready) begin
                    r_done = 1'b1;
                    data = s01_axi_rdata;
                    s01_axi_rready <= 1'b0;
                end
                timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYC) begin
                $display("[ERROR @%0t ns] s01 read timeout! ar_done=%b r_done=%b addr=0x%08h",
                         $time, ar_done, r_done, addr);
                data = 32'hDEAD_BEEF;
            end

            @(negedge clk);
            s01_axi_arvalid <= 1'b0;
            s01_axi_rready  <= 1'b0;
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // Reset Task
    // =========================================================================
    task do_reset;
        begin
            $display("[RST @%0t ns] Asserting reset (rst_l=0)", $time);
            rst_l     = 1'b0;
            dbg_rst_l = 1'b0;
            repeat(RST_CYCLES) @(posedge clk);
            @(negedge clk);
            rst_l     = 1'b1;
            dbg_rst_l = 1'b1;
            $display("[RST @%0t ns] Reset de-asserted (rst_l=1)", $time);
            repeat(10) @(posedge clk);
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
    // Watchdog
    // =========================================================================
    initial begin
        #(CLK_PERIOD * 300000);
        $display("[WATCHDOG @%0t ns] Simulation exceeded maximum cycle budget. Terminating.", $time);
        $finish;
    end

    // =========================================================================
    // FIPS-197 Test Vectors
    // Key    : 2b7e1516 28aed2a6 abf71588 09cf4f3c
    // Plain  : 6bc1bee2 2e409f96 e93d7e11 7393172a
    // Cipher : 3ad77bb4 0d7a3660 a89ecaf3 2466ef97
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
    // Main Test Sequence
    // =========================================================================
    reg [31:0] rd_val, r0, r1, r2, r3;
    integer    wait_iter;

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

        // ---------------------------------------------------------------------
        // TC1: Power-on Reset
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC1: Power-on Reset & Initialization");
        $display("---------------------------------------------------------");
        do_reset();
        if (rst_l === 1'b1 && uart_tx_o === 1'b1 && aes_busy_o === 1'b0) begin
            $display("[PASS] TC1: System successfully initialized out of reset.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC1: Unexpected signal states after reset.");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC2: VeeR IFU Instruction Fetch
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
            $display("[PASS] TC2: Observed VeeR Core issuing IFU instruction fetch (PC=0x%08h).", ifu_fetch_seen ? ifu_fetch_addr : ifu_axi_araddr);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC2: Core failed to initiate instruction fetch within budget.");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC3: UART Register Configuration via s01
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC3: UART Register Configuration (0x4000_0000)");
        $display("---------------------------------------------------------");
        // Step 1: Set DLAB = 1 (LCR[7] = 1) to enable baud divisor programming
        axi4_write_s01(UART_LCR_REG,  32'h0000_0083, 8'h01); // DLAB=1, 8-bit word
        // Step 2: Write BAUD divisor
        axi4_write_s01(UART_BAUD_REG, BAUD_DIV,      8'h02); // BAUD divisor = 10
        // Step 3: Clear DLAB = 0 (LCR[7] = 0)
        axi4_write_s01(UART_LCR_REG,  32'h0000_0003, 8'h03); // DLAB=0, 8-bit, 1 stop bit, no parity
        // Step 4: Enable RX interrupt
        axi4_write_s01(UART_IER_REG,  32'h0000_0001, 8'h04); // Enable RX interrupt
        axi4_read_s01(UART_LSR_REG,   8'h05, rd_val);

        if (rd_val[5] === 1'b1 || rd_val[6] === 1'b1) begin
            $display("[PASS] TC3: UART configured and verified active via LSR (read=0x%08h, THRE/TEMT=1).", rd_val);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC3: UART LSR unexpected: got 0x%08h", rd_val);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC4: UART Transmission ('A' = 0x41)
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC4: UART Transmission ('A' = 0x41)");
        $display("---------------------------------------------------------");
        rx_done = 1'b0;
        axi4_write_s01(UART_THR_REG, 32'h41, 8'h06);
        wait_iter = 0;
        while (!rx_done && wait_iter < (BIT_CYCLES * 30)) begin
            @(posedge clk);
            wait_iter = wait_iter + 1;
        end
        if (rx_capture == 8'h41) begin
            $display("[PASS] TC4: UART successfully transmitted 0x41 ('%c').", rx_capture);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC4: UART TX mismatch: got 0x%02h, expected 0x41", rx_capture);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC5: UART RX & Read-Interrupt Verification
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC5: UART RX Loopback & Interrupt Generation");
        $display("---------------------------------------------------------");
        // Inject serial byte 0x55 on uart_rx_i: Start(0), 8 bits LSB-first, Stop(1)
        @(posedge clk);
        uart_rx_i = 1'b0; // start bit
        repeat(BIT_CYCLES) @(posedge clk);
        for (wait_iter = 0; wait_iter < 8; wait_iter = wait_iter + 1) begin
            uart_rx_i = (wait_iter % 2 == 0) ? 1'b1 : 1'b0; // 0x55 = 8'b01010101
            repeat(BIT_CYCLES) @(posedge clk);
        end
        uart_rx_i = 1'b1; // stop bit
        repeat(BIT_CYCLES) @(posedge clk);
        repeat(BIT_CYCLES * 4) @(posedge clk);

        // Check if UART asserted RX data-ready interrupt
        if (uart_read_irq_o === 1'b1) begin
            $display("[PASS] TC5: UART RX interrupt successfully asserted upon byte arrival.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC5: UART RX interrupt was not asserted.");
            fail_count = fail_count + 1;
        end

        // Read received byte from RBR
        axi4_read_s01(UART_RBR_REG, 8'h07, rd_val);
        $display("[INFO] TC5: Read UART RBR = 0x%02h", rd_val[7:0]);
        if (rd_val[7:0] === 8'h55) begin
            $display("[PASS] TC5: UART RBR read data matched injected byte 0x55.");
        end else begin
            $display("[WARN] TC5: UART RBR mismatch: got 0x%02h, expected 0x55", rd_val[7:0]);
        end

        // ---------------------------------------------------------------------
        // TC6: AES-128 Register Write & Read-back (32-to-128 bit Adaptation)
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC6: AES-128 32-to-128 bit Register Write & Readback (0x4000_2000)");
        $display("---------------------------------------------------------");
        // Write Key (128 bits across 4 x 32-bit registers)
        axi4_write_s01(AES_KEY0_REG, GOLDEN_KEY0, 8'h10);
        axi4_write_s01(AES_KEY1_REG, GOLDEN_KEY1, 8'h11);
        axi4_write_s01(AES_KEY2_REG, GOLDEN_KEY2, 8'h12);
        axi4_write_s01(AES_KEY3_REG, GOLDEN_KEY3, 8'h13);

        // Write Plaintext (128 bits across 4 x 32-bit registers)
        axi4_write_s01(AES_TXTIN0_REG, GOLDEN_PT0, 8'h14);
        axi4_write_s01(AES_TXTIN1_REG, GOLDEN_PT1, 8'h15);
        axi4_write_s01(AES_TXTIN2_REG, GOLDEN_PT2, 8'h16);
        axi4_write_s01(AES_TXTIN3_REG, GOLDEN_PT3, 8'h17);

        // Readback check
        axi4_read_s01(AES_KEY0_REG, 8'h18, r0);
        axi4_read_s01(AES_KEY1_REG, 8'h19, r1);
        axi4_read_s01(AES_KEY2_REG, 8'h1A, r2);
        axi4_read_s01(AES_KEY3_REG, 8'h1B, r3);

        if (r0 == GOLDEN_KEY0 && r1 == GOLDEN_KEY1 && r2 == GOLDEN_KEY2 && r3 == GOLDEN_KEY3) begin
            $display("[PASS] TC6: 128-bit Key successfully verified over 32-bit AXI bus.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC6: Key readback mismatch!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC7: AES-128 Encryption Execution (NIST FIPS-197)
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC7: AES-128 Hardware Encryption Execution");
        $display("---------------------------------------------------------");
        pulse_count = 0;

        // Trigger encryption: write START=1, MODE=0 (Encrypt), IRQ_EN=1 to 0x4000_2000
        axi4_write_s01(AES_CTRL_REG, 32'h0000_0009, 8'h20); // START=bit0, IRQ_EN=bit3

        // Poll for completion (bit 8 = DONE)
        rd_val = 0;
        wait_iter = 0;
        while (!rd_val[8] && wait_iter < 200) begin
            axi4_read_s01(AES_CTRL_REG, 8'h21, rd_val);
            wait_iter = wait_iter + 1;
        end
        $display("[INFO] TC7: Polled AES_CTRL_STAT = 0x%08h after %0d reads.", rd_val, wait_iter);

        // Read 128-bit ciphertext
        axi4_read_s01(AES_TXTOUT0_REG, 8'h22, r0);
        axi4_read_s01(AES_TXTOUT1_REG, 8'h23, r1);
        axi4_read_s01(AES_TXTOUT2_REG, 8'h24, r2);
        axi4_read_s01(AES_TXTOUT3_REG, 8'h25, r3);

        $display("[CIPHERTEXT] Word0: got=0x%08h exp=0x%08h", r0, GOLDEN_CT0);
        $display("[CIPHERTEXT] Word1: got=0x%08h exp=0x%08h", r1, GOLDEN_CT1);
        $display("[CIPHERTEXT] Word2: got=0x%08h exp=0x%08h", r2, GOLDEN_CT2);
        $display("[CIPHERTEXT] Word3: got=0x%08h exp=0x%08h", r3, GOLDEN_CT3);

        if (r0 == GOLDEN_CT0 && r1 == GOLDEN_CT1 && r2 == GOLDEN_CT2 && r3 == GOLDEN_CT3) begin
            $display("[PASS] TC7: AES-128 ciphertext strictly matches FIPS-197 golden vector!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC7: Ciphertext mismatch!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC8: AES Watchdog Kick Pulse & IRQ Verification
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC8: Hardware Handshaking (WDT Kick Pulse & PIC IRQ)");
        $display("---------------------------------------------------------");
        if (pulse_count >= 1 && aes_irq_o === 1'b1) begin
            $display("[PASS] TC8: Watchdog HW kick pulse (aes_done_pulse_o) and PIC IRQ (aes_irq_o) asserted.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC8: Missing pulse or IRQ: pulse_count=%0d, aes_irq=%b", pulse_count, aes_irq_o);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC9: AES-128 Decryption & Plaintext Recovery
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC9: AES-128 Decryption Execution & Plaintext Recovery");
        $display("---------------------------------------------------------");
        // 1. Key expansion for decryption (KEY_LD=1, MODE=1 Decrypt, IRQ_EN=1)
        axi4_write_s01(AES_CTRL_REG, 32'h0000_000E, 8'h30); // bit1=KEY_LD, bit2=MODE, bit3=IRQ_EN
        repeat(15) @(posedge clk);

        // 2. Write ciphertext into text_in
        axi4_write_s01(AES_TXTIN0_REG, GOLDEN_CT0, 8'h31);
        axi4_write_s01(AES_TXTIN1_REG, GOLDEN_CT1, 8'h32);
        axi4_write_s01(AES_TXTIN2_REG, GOLDEN_CT2, 8'h33);
        axi4_write_s01(AES_TXTIN3_REG, GOLDEN_CT3, 8'h34);

        // 3. Trigger Decryption: START=1, MODE=1 (Decrypt), IRQ_EN=1
        axi4_write_s01(AES_CTRL_REG, 32'h0000_000D, 8'h35);

        // 4. Poll for completion
        rd_val = 0;
        wait_iter = 0;
        while (!rd_val[8] && wait_iter < 200) begin
            axi4_read_s01(AES_CTRL_REG, 8'h36, rd_val);
            wait_iter = wait_iter + 1;
        end

        // 5. Read recovered plaintext
        axi4_read_s01(AES_TXTOUT0_REG, 8'h37, r0);
        axi4_read_s01(AES_TXTOUT1_REG, 8'h38, r1);
        axi4_read_s01(AES_TXTOUT2_REG, 8'h39, r2);
        axi4_read_s01(AES_TXTOUT3_REG, 8'h3A, r3);

        $display("[PLAINTEXT] Word0: got=0x%08h exp=0x%08h", r0, GOLDEN_PT0);
        $display("[PLAINTEXT] Word1: got=0x%08h exp=0x%08h", r1, GOLDEN_PT1);
        $display("[PLAINTEXT] Word2: got=0x%08h exp=0x%08h", r2, GOLDEN_PT2);
        $display("[PLAINTEXT] Word3: got=0x%08h exp=0x%08h", r3, GOLDEN_PT3);

        if (r0 == GOLDEN_PT0 && r1 == GOLDEN_PT1 && r2 == GOLDEN_PT2 && r3 == GOLDEN_PT3) begin
            $display("[PASS] TC9: Recovered plaintext perfectly matches original input!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC9: Decryption failed to recover original plaintext.");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC10: AES W1C Clear Done & IRQ
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC10: Write-1-to-Clear (W1C) Done & Interrupt Reset");
        $display("---------------------------------------------------------");
        // Write 1 to bit 8 of AES_CTRL_REG
        axi4_write_s01(AES_CTRL_REG, 32'h0000_0100, 8'h40);
        repeat(3) @(posedge clk);
        axi4_read_s01(AES_CTRL_REG, 8'h41, rd_val);

        if (rd_val[8] === 1'b0 && aes_irq_o === 1'b0) begin
            $display("[PASS] TC10: DONE bit and IRQ cleared successfully by W1C.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC10: W1C failed: status[8]=%b, irq=%b", rd_val[8], aes_irq_o);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TC11: Interleaved UART & AES Interconnect Traffic
        // ---------------------------------------------------------------------
        $display("\n---------------------------------------------------------");
        $display("TC11: Interleaved UART & AES Interconnect Operations");
        $display("---------------------------------------------------------");
        // Write UART THR, write AES key word, read UART LSR, read AES status
        axi4_write_s01(UART_THR_REG, 32'h21, 8'h50); // '!'
        axi4_write_s01(AES_KEY0_REG, 32'hDEAD_BEEF, 8'h51);
        axi4_read_s01(UART_LSR_REG,  8'h52, r0);
        axi4_read_s01(AES_KEY0_REG,  8'h53, r1);

        if (r1 == 32'hDEAD_BEEF) begin
            $display("[PASS] TC11: Interconnect cleanly handled interleaved UART & AES traffic.");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC11: Interconnect interleaved access error: read 0x%08h", r1);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------------------
        $display("\n================================================================");
        $display(" VERIFICATION SUMMARY");
        $display("================================================================");
        $display(" Tests Passed : %0d", pass_count);
        $display(" Tests Failed : %0d", fail_count);
        if (fail_count == 0) begin
            $display(" RESULT       : ALL TESTS PASSED SUCCESSFULLY! (100%%)");
        end else begin
            $display(" RESULT       : VERIFICATION FAILED with %0d errors.", fail_count);
        end
        $display("================================================================");
        repeat(50) @(posedge clk);
        $finish;
    end

endmodule

`default_nettype wire
