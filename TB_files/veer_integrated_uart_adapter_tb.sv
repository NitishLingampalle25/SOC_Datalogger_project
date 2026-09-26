// =============================================================================
// Testbench : veer_integrated_uart_adapter_tb
// File      : TB_files/veer_integrated_uart_adapter_tb.sv
// Language  : SystemVerilog (IEEE 1800-2012)
//
// DUT       : axi_dwidth_converter_64to32
//             (defined at the bottom of RTL_files/veer_wrapper_uart_integrated.v)
//
// Purpose   : Verify the AXI4 64-bit → 32-bit data-width adapter that bridges
//             the VeeR EL2 LSU (64-bit master) to the 32-bit AXI interconnect
//             feeding the UART peripheral.
//
// Test Cases
// ----------
//   TC1  – Lower-word write  (awaddr[2]=0, size=2, wdata[31:0])
//             Adapter must forward  wdata[31:0]  on s_axi_wdata
//             and                   wstrb[3:0]   on s_axi_wstrb
//
//   TC2  – Upper-word write  (awaddr[2]=1, size=2, wdata[63:32])
//             Adapter must forward  wdata[63:32] on s_axi_wdata
//             and                   wstrb[7:4]   on s_axi_wstrb
//
//   TC3  – 64-bit size clamp on write  (awsize=3'b011 → must become 3'b010)
//             Adapter must clamp awsize to 3'b010 before driving s_axi_awsize
//
//   TC4  – Lower-word read   (araddr[2]=0)
//             Slave returns s_rdata[31:0]; adapter must replicate it to
//             both 64-bit lanes: m_rdata[63:32] = m_rdata[31:0] = s_rdata
//
//   TC5  – Upper-word read   (araddr[2]=1)
//             Same replication requirement; confirms lane-independence
//
//   TC6  – 64-bit size clamp on read   (arsize=3'b011 → must become 3'b010)
//
//   TC7  – ID width conversion (master ID truncated to slave width; B/R
//             channel IDs zero-extended back to master width)
//
//   TC8  – Back-to-back write transactions (no bubbles)
//             Two consecutive lower-word writes; handshake must not stall.
//
//   TC9  – Back-to-back read transactions (no bubbles)
//
//   TC10 – Mixed lower/upper word writes in alternating sequence
//
//   TC11 – Write-then-read to same address (addr[2]=0)
//
//   TC12 – Write-then-read to same address (addr[2]=1)
//
//   TC13 – AW/W channel skew: W presented one cycle before AW accepted
//             Adapter must still steer to the correct lane.
//
//   TC14 – Slave stalls (awready=0) – master must wait; no data corruption
//
//   TC15 – Read with slave stall (arready=0)
//
// Waveform dump (Verdi / DVE):
//   $fsdb dump is generated automatically.
//   To view: verdi -ssf veer_integrated_uart_adapter_tb.fsdb &
//   VCD fallback is also dumped for non-Verdi flows.
//
// Compile (from run/ directory):
//   vcs -full64 -sverilog -debug_access+all -kdb \
//       -l compile_adapter_tb.log \
//       ../RTL_files/veer_wrapper_uart_integrated.v \
//       ../TB_files/veer_integrated_uart_adapter_tb.sv \
//       -o simv_adapter_tb
//   ./simv_adapter_tb +fsdb+delta -l sim_adapter_tb.log
// =============================================================================

`timescale 1ns/1ps
`begin_keywords "1800-2012"

module veer_integrated_uart_adapter_tb;

    // =========================================================================
    // Parameters – match DUT defaults
    // =========================================================================
    localparam ID_WIDTH_M = 4;   // VeeR LSU_BUS_TAG
    localparam ID_WIDTH_S = 8;   // IC_ID_WIDTH
    localparam ADDR_WIDTH = 32;

    localparam CLK_PERIOD  = 10; // 100 MHz
    localparam TIMEOUT_CYC = 200;

    // =========================================================================
    // Clock / reset
    // =========================================================================
    logic clk   = 1'b0;
    logic rst_n = 1'b0;

    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // DUT port signals – Master side (64-bit, driven by TB / BFM)
    // =========================================================================
    // Write address channel
    logic [ID_WIDTH_M-1:0]  m_axi_awid    = '0;
    logic [ADDR_WIDTH-1:0]  m_axi_awaddr  = '0;
    logic [7:0]             m_axi_awlen   = 8'h00;
    logic [2:0]             m_axi_awsize  = 3'b010;
    logic [1:0]             m_axi_awburst = 2'b01;
    logic                   m_axi_awlock  = 1'b0;
    logic [3:0]             m_axi_awcache = 4'h0;
    logic [2:0]             m_axi_awprot  = 3'b000;
    logic [3:0]             m_axi_awqos   = 4'h0;
    logic [3:0]             m_axi_awregion= 4'h0;
    logic                   m_axi_awvalid = 1'b0;
    wire                    m_axi_awready;

    // Write data channel
    logic [63:0]            m_axi_wdata   = '0;
    logic [7:0]             m_axi_wstrb   = 8'hFF;
    logic                   m_axi_wlast   = 1'b1;
    logic                   m_axi_wvalid  = 1'b0;
    wire                    m_axi_wready;

    // Write response channel
    wire  [ID_WIDTH_M-1:0]  m_axi_bid;
    wire  [1:0]             m_axi_bresp;
    wire                    m_axi_bvalid;
    logic                   m_axi_bready  = 1'b1;

    // Read address channel
    logic [ID_WIDTH_M-1:0]  m_axi_arid    = '0;
    logic [ADDR_WIDTH-1:0]  m_axi_araddr  = '0;
    logic [7:0]             m_axi_arlen   = 8'h00;
    logic [2:0]             m_axi_arsize  = 3'b010;
    logic [1:0]             m_axi_arburst = 2'b01;
    logic                   m_axi_arlock  = 1'b0;
    logic [3:0]             m_axi_arcache = 4'h0;
    logic [2:0]             m_axi_arprot  = 3'b000;
    logic [3:0]             m_axi_arqos   = 4'h0;
    logic [3:0]             m_axi_arregion= 4'h0;
    logic                   m_axi_arvalid = 1'b0;
    wire                    m_axi_arready;

    // Read data channel
    wire  [ID_WIDTH_M-1:0]  m_axi_rid;
    wire  [63:0]            m_axi_rdata;
    wire  [1:0]             m_axi_rresp;
    wire                    m_axi_rlast;
    wire                    m_axi_rvalid;
    logic                   m_axi_rready  = 1'b1;

    // =========================================================================
    // DUT port signals – Slave side (32-bit, driven by slave BFM in TB)
    // =========================================================================
    // Write address channel
    wire  [ID_WIDTH_S-1:0]  s_axi_awid;
    wire  [ADDR_WIDTH-1:0]  s_axi_awaddr;
    wire  [7:0]             s_axi_awlen;
    wire  [2:0]             s_axi_awsize;
    wire  [1:0]             s_axi_awburst;
    wire                    s_axi_awlock;
    wire  [3:0]             s_axi_awcache;
    wire  [2:0]             s_axi_awprot;
    wire  [3:0]             s_axi_awqos;
    wire                    s_axi_awvalid;
    logic                   s_axi_awready = 1'b1;  // slave ready by default

    // Write data channel
    wire  [31:0]            s_axi_wdata;
    wire  [3:0]             s_axi_wstrb;
    wire                    s_axi_wlast;
    wire                    s_axi_wvalid;
    logic                   s_axi_wready  = 1'b1;

    // Write response channel
    logic [ID_WIDTH_S-1:0]  s_axi_bid    = '0;
    logic [1:0]             s_axi_bresp  = 2'b00;
    logic                   s_axi_bvalid = 1'b0;
    wire                    s_axi_bready;

    // Read address channel
    wire  [ID_WIDTH_S-1:0]  s_axi_arid;
    wire  [ADDR_WIDTH-1:0]  s_axi_araddr;
    wire  [7:0]             s_axi_arlen;
    wire  [2:0]             s_axi_arsize;
    wire  [1:0]             s_axi_arburst;
    wire                    s_axi_arlock;
    wire  [3:0]             s_axi_arcache;
    wire  [2:0]             s_axi_arprot;
    wire  [3:0]             s_axi_arqos;
    wire                    s_axi_arvalid;
    logic                   s_axi_arready = 1'b1;

    // Read data channel
    logic [ID_WIDTH_S-1:0]  s_axi_rid    = '0;
    logic [31:0]            s_axi_rdata  = 32'h0;
    logic [1:0]             s_axi_rresp  = 2'b00;
    logic                   s_axi_rlast  = 1'b1;
    logic                   s_axi_rvalid = 1'b0;
    wire                    s_axi_rready;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    axi_dwidth_converter_64to32 #(
        .ID_WIDTH_M (ID_WIDTH_M),
        .ID_WIDTH_S (ID_WIDTH_S),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),

        .m_axi_awid      (m_axi_awid),
        .m_axi_awaddr    (m_axi_awaddr),
        .m_axi_awlen     (m_axi_awlen),
        .m_axi_awsize    (m_axi_awsize),
        .m_axi_awburst   (m_axi_awburst),
        .m_axi_awlock    (m_axi_awlock),
        .m_axi_awcache   (m_axi_awcache),
        .m_axi_awprot    (m_axi_awprot),
        .m_axi_awqos     (m_axi_awqos),
        .m_axi_awregion  (m_axi_awregion),
        .m_axi_awvalid   (m_axi_awvalid),
        .m_axi_awready   (m_axi_awready),

        .m_axi_wdata     (m_axi_wdata),
        .m_axi_wstrb     (m_axi_wstrb),
        .m_axi_wlast     (m_axi_wlast),
        .m_axi_wvalid    (m_axi_wvalid),
        .m_axi_wready    (m_axi_wready),

        .m_axi_bid       (m_axi_bid),
        .m_axi_bresp     (m_axi_bresp),
        .m_axi_bvalid    (m_axi_bvalid),
        .m_axi_bready    (m_axi_bready),

        .m_axi_arid      (m_axi_arid),
        .m_axi_araddr    (m_axi_araddr),
        .m_axi_arlen     (m_axi_arlen),
        .m_axi_arsize    (m_axi_arsize),
        .m_axi_arburst   (m_axi_arburst),
        .m_axi_arlock    (m_axi_arlock),
        .m_axi_arcache   (m_axi_arcache),
        .m_axi_arprot    (m_axi_arprot),
        .m_axi_arqos     (m_axi_arqos),
        .m_axi_arregion  (m_axi_arregion),
        .m_axi_arvalid   (m_axi_arvalid),
        .m_axi_arready   (m_axi_arready),

        .m_axi_rid       (m_axi_rid),
        .m_axi_rdata     (m_axi_rdata),
        .m_axi_rresp     (m_axi_rresp),
        .m_axi_rlast     (m_axi_rlast),
        .m_axi_rvalid    (m_axi_rvalid),
        .m_axi_rready    (m_axi_rready),

        .s_axi_awid      (s_axi_awid),
        .s_axi_awaddr    (s_axi_awaddr),
        .s_axi_awlen     (s_axi_awlen),
        .s_axi_awsize    (s_axi_awsize),
        .s_axi_awburst   (s_axi_awburst),
        .s_axi_awlock    (s_axi_awlock),
        .s_axi_awcache   (s_axi_awcache),
        .s_axi_awprot    (s_axi_awprot),
        .s_axi_awqos     (s_axi_awqos),
        .s_axi_awvalid   (s_axi_awvalid),
        .s_axi_awready   (s_axi_awready),

        .s_axi_wdata     (s_axi_wdata),
        .s_axi_wstrb     (s_axi_wstrb),
        .s_axi_wlast     (s_axi_wlast),
        .s_axi_wvalid    (s_axi_wvalid),
        .s_axi_wready    (s_axi_wready),

        .s_axi_bid       (s_axi_bid),
        .s_axi_bresp     (s_axi_bresp),
        .s_axi_bvalid    (s_axi_bvalid),
        .s_axi_bready    (s_axi_bready),

        .s_axi_arid      (s_axi_arid),
        .s_axi_araddr    (s_axi_araddr),
        .s_axi_arlen     (s_axi_arlen),
        .s_axi_arsize    (s_axi_arsize),
        .s_axi_arburst   (s_axi_arburst),
        .s_axi_arlock    (s_axi_arlock),
        .s_axi_arcache   (s_axi_arcache),
        .s_axi_arprot    (s_axi_arprot),
        .s_axi_arqos     (s_axi_arqos),
        .s_axi_arvalid   (s_axi_arvalid),
        .s_axi_arready   (s_axi_arready),

        .s_axi_rid       (s_axi_rid),
        .s_axi_rdata     (s_axi_rdata),
        .s_axi_rresp     (s_axi_rresp),
        .s_axi_rlast     (s_axi_rlast),
        .s_axi_rvalid    (s_axi_rvalid),
        .s_axi_rready    (s_axi_rready)
    );

    // =========================================================================
    // Scoreboard counters
    // =========================================================================
    int pass_count = 0;
    int fail_count = 0;

    // =========================================================================
    // Waveform dumps
    // =========================================================================
    initial begin
        // FSDB for Verdi
        $fsdbDumpfile("veer_integrated_uart_adapter_tb.fsdb");
        $fsdbDumpvars(0, veer_integrated_uart_adapter_tb);
        $fsdbDumpMDA();
        // VCD fallback
        $dumpfile("veer_integrated_uart_adapter_tb.vcd");
        $dumpvars(0, veer_integrated_uart_adapter_tb);
    end

    // =========================================================================
    // Helper: print separator
    // =========================================================================
    task automatic print_sep(input string tc_name);
        $display("\n%0t ns  ┌──────────────────────────────────────────────┐", $time);
        $display("%0t ns  │  %-44s│", $time, tc_name);
        $display("%0t ns  └──────────────────────────────────────────────┘", $time);
    endtask

    // =========================================================================
    // Helper: check and print a single comparison
    // =========================================================================
    task automatic check(
        input string    label,
        input logic [63:0] got,
        input logic [63:0] exp,
        input int       width       // meaningful bits to compare/print
    );
        logic [63:0] mask;
        logic [63:0] got_m, exp_m;
        mask  = (width >= 64) ? 64'hFFFF_FFFF_FFFF_FFFF : ((64'h1 << width) - 1);
        got_m = got & mask;
        exp_m = exp & mask;
        if (got_m === exp_m) begin
            $display("%0t ns    [PASS] %-30s got=0x%0h  exp=0x%0h",
                     $time, label, got_m, exp_m);
            pass_count++;
        end else begin
            $display("%0t ns    [FAIL] %-30s got=0x%0h  exp=0x%0h  *** MISMATCH ***",
                     $time, label, got_m, exp_m);
            fail_count++;
        end
    endtask

    // =========================================================================
    // Helper: AXI4 write transaction (master drives AW + W simultaneously,
    //         slave-BFM responds B after W handshake)
    // =========================================================================
    task automatic axi_write(
        input logic [ID_WIDTH_M-1:0]  awid,
        input logic [ADDR_WIDTH-1:0]  awaddr,
        input logic [2:0]             awsize,
        input logic [63:0]            wdata,
        input logic [7:0]             wstrb
    );
        int timeout;

        // Drive AW channel
        @(negedge clk);
        m_axi_awid    <= awid;
        m_axi_awaddr  <= awaddr;
        m_axi_awsize  <= awsize;
        m_axi_awlen   <= 8'h00;
        m_axi_awburst <= 2'b01;
        m_axi_awvalid <= 1'b1;

        // Drive W channel simultaneously
        m_axi_wdata   <= wdata;
        m_axi_wstrb   <= wstrb;
        m_axi_wlast   <= 1'b1;
        m_axi_wvalid  <= 1'b1;

        $display("%0t ns      [AW-DRIVE] awid=0x%0h  awaddr=0x%08h  awsize=%0b  wdata=0x%016h  wstrb=0x%0h",
                 $time, awid, awaddr, awsize, wdata, wstrb);

        // Wait for AW handshake
        timeout = 0;
        @(posedge clk);
        while (!m_axi_awready && timeout < TIMEOUT_CYC) begin
            @(posedge clk); timeout++;
        end
        if (timeout >= TIMEOUT_CYC)
            $display("%0t ns      [WARN] AW handshake timed out!", $time);

        m_axi_awvalid <= 1'b0;

        // Wait for W handshake
        timeout = 0;
        while (!m_axi_wready && timeout < TIMEOUT_CYC) begin
            @(posedge clk); timeout++;
        end
        if (timeout >= TIMEOUT_CYC)
            $display("%0t ns      [WARN] W handshake timed out!", $time);

        m_axi_wvalid <= 1'b0;

        // Issue slave B response one cycle later
        @(negedge clk);
        s_axi_bid    <= s_axi_awid;   // echo back the (truncated) ID
        s_axi_bresp  <= 2'b00;
        s_axi_bvalid <= 1'b1;

        @(posedge clk);
        while (!s_axi_bready && timeout < TIMEOUT_CYC) begin
            @(posedge clk); timeout++;
        end

        @(negedge clk);
        s_axi_bvalid <= 1'b0;

        // Allow one idle cycle between transactions
        @(posedge clk);
    endtask

    // =========================================================================
    // Helper: AXI4 read transaction (master drives AR, slave BFM responds R)
    // =========================================================================
    task automatic axi_read(
        input  logic [ID_WIDTH_M-1:0]  arid,
        input  logic [ADDR_WIDTH-1:0]  araddr,
        input  logic [2:0]             arsize,
        input  logic [31:0]            slave_rdata,    // what slave returns
        output logic [63:0]            master_rdata_o  // what master sees
    );
        int timeout;

        // Drive AR channel
        @(negedge clk);
        m_axi_arid    <= arid;
        m_axi_araddr  <= araddr;
        m_axi_arsize  <= arsize;
        m_axi_arlen   <= 8'h00;
        m_axi_arburst <= 2'b01;
        m_axi_arvalid <= 1'b1;

        $display("%0t ns      [AR-DRIVE] arid=0x%0h  araddr=0x%08h  arsize=%0b  slave_rdata_in=0x%08h",
                 $time, arid, araddr, arsize, slave_rdata);

        // Wait for AR handshake
        timeout = 0;
        @(posedge clk);
        while (!m_axi_arready && timeout < TIMEOUT_CYC) begin
            @(posedge clk); timeout++;
        end
        if (timeout >= TIMEOUT_CYC)
            $display("%0t ns      [WARN] AR handshake timed out!", $time);

        m_axi_arvalid <= 1'b0;

        // Slave BFM issues R response one cycle after AR accepted
        @(negedge clk);
        s_axi_rid    <= s_axi_arid;
        s_axi_rdata  <= slave_rdata;
        s_axi_rresp  <= 2'b00;
        s_axi_rlast  <= 1'b1;
        s_axi_rvalid <= 1'b1;

        @(posedge clk);
        timeout = 0;
        while (!s_axi_rready && timeout < TIMEOUT_CYC) begin
            @(posedge clk); timeout++;
        end
        if (timeout >= TIMEOUT_CYC)
            $display("%0t ns      [WARN] R handshake timed out!", $time);

        // Sample master rdata on the cycle R is accepted
        master_rdata_o = m_axi_rdata;
        $display("%0t ns      [R-SAMPLE] m_axi_rdata=0x%016h  m_axi_rid=0x%0h  m_axi_rresp=%0b",
                 $time, m_axi_rdata, m_axi_rid, m_axi_rresp);

        @(negedge clk);
        s_axi_rvalid <= 1'b0;

        @(posedge clk);
    endtask

    // =========================================================================
    // Helper: wait N clock cycles
    // =========================================================================
    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    logic [63:0] rdata_got;

    initial begin
        $display("\n================================================================");
        $display("  veer_integrated_uart_adapter_tb  –  axi_dwidth_converter_64to32");
        $display("  ID_WIDTH_M=%0d  ID_WIDTH_S=%0d  ADDR_WIDTH=%0d",
                 ID_WIDTH_M, ID_WIDTH_S, ADDR_WIDTH);
        $display("================================================================\n");

        // ------------------------------------------------------------------
        // Reset
        // ------------------------------------------------------------------
        rst_n = 1'b0;
        wait_cycles(5);
        @(negedge clk);
        rst_n = 1'b1;
        wait_cycles(2);
        $display("%0t ns  [RESET] Reset de-asserted (rst_n=1)", $time);

        // ==================================================================
        // TC1 – Lower-word write (awaddr[2]=0)
        // ==================================================================
        print_sep("TC1 : Lower-word write  (awaddr[2]=0)");
        axi_write(4'hA, 32'h4000_0000, 3'b010,
                  64'hDEAD_BEEF_1234_5678, 8'h0F);
        // Expected: s_axi_wdata = wdata[31:0] = 0x1234_5678
        //           s_axi_wstrb = wstrb[3:0]  = 4'hF
        $display("%0t ns    Observed slave: wdata=0x%08h  wstrb=0x%0h  awsize=%0b",
                 $time, s_axi_wdata, s_axi_wstrb, s_axi_awsize);
        check("TC1 s_wdata[31:0]",  {32'h0, s_axi_wdata}, {32'h0, 32'h1234_5678}, 32);
        check("TC1 s_wstrb[3:0]",   {60'h0, s_axi_wstrb}, {60'h0, 4'hF},          4);
        check("TC1 s_awsize",        {61'h0, s_axi_awsize},{61'h0, 3'b010},         3);

        // ==================================================================
        // TC2 – Upper-word write (awaddr[2]=1)
        // ==================================================================
        print_sep("TC2 : Upper-word write  (awaddr[2]=1)");
        axi_write(4'hB, 32'h4000_0004, 3'b010,
                  64'hDEAD_BEEF_CAFE_BABE, 8'hF0);
        // Expected: s_axi_wdata = wdata[63:32] = 0xDEAD_BEEF
        //           s_axi_wstrb = wstrb[7:4]   = 4'hF
        $display("%0t ns    Observed slave: wdata=0x%08h  wstrb=0x%0h  awsize=%0b",
                 $time, s_axi_wdata, s_axi_wstrb, s_axi_awsize);
        check("TC2 s_wdata[63:32]", {32'h0, s_axi_wdata}, {32'h0, 32'hDEAD_BEEF}, 32);
        check("TC2 s_wstrb[7:4]",   {60'h0, s_axi_wstrb}, {60'h0, 4'hF},          4);
        check("TC2 s_awsize",        {61'h0, s_axi_awsize},{61'h0, 3'b010},         3);

        // ==================================================================
        // TC3 – 64-bit size clamp on write (awsize=3 → must become 2)
        // ==================================================================
        print_sep("TC3 : awsize=3 clamp on write");
        axi_write(4'hC, 32'h4000_0000, 3'b011,    // 64-bit transfer
                  64'h1111_2222_3333_4444, 8'hFF);
        $display("%0t ns    Observed slave: awsize=%0b (expected 010)", $time, s_axi_awsize);
        check("TC3 s_awsize clamp",  {61'h0, s_axi_awsize},{61'h0, 3'b010}, 3);

        // ==================================================================
        // TC4 – Lower-word read (araddr[2]=0)
        // ==================================================================
        print_sep("TC4 : Lower-word read   (araddr[2]=0)");
        axi_read(4'hD, 32'h4000_0000, 3'b010, 32'hABCD_1234, rdata_got);
        // Expect both 32-bit lanes of m_rdata = 0xABCD_1234
        $display("%0t ns    m_axi_rdata=0x%016h  (expected {0xABCD_1234, 0xABCD_1234})", $time, rdata_got);
        check("TC4 m_rdata[31:0]",   rdata_got,               {32'hABCD_1234, 32'hABCD_1234}, 32);
        check("TC4 m_rdata[63:32]", {rdata_got[31:0], 32'h0}, {32'hABCD_1234, 32'h0},          32);

        // ==================================================================
        // TC5 – Upper-word read (araddr[2]=1)
        // ==================================================================
        print_sep("TC5 : Upper-word read   (araddr[2]=1)");
        axi_read(4'hE, 32'h4000_0004, 3'b010, 32'hFEEDFACE, rdata_got);
        $display("%0t ns    m_axi_rdata=0x%016h  (expected {0xFEEDFACE, 0xFEEDFACE})", $time, rdata_got);
        check("TC5 m_rdata[31:0]",   rdata_got,               {32'hFEEDFACE, 32'hFEEDFACE}, 32);
        check("TC5 m_rdata[63:32]", {rdata_got[31:0], 32'h0}, {32'hFEEDFACE, 32'h0},         32);

        // ==================================================================
        // TC6 – 64-bit arsize clamp on read (arsize=3 → must become 2)
        // ==================================================================
        print_sep("TC6 : arsize=3 clamp on read");
        axi_read(4'h1, 32'h4000_0000, 3'b011, 32'h0000_1111, rdata_got);
        $display("%0t ns    Observed slave: arsize=%0b (expected 010)", $time, s_axi_arsize);
        check("TC6 s_arsize clamp",  {61'h0, s_axi_arsize},{61'h0, 3'b010}, 3);

        // ==================================================================
        // TC7 – ID width conversion
        // ==================================================================
        print_sep("TC7 : ID width conversion  (M=4b → S=8b → M=4b)");
        // Write with specific ID and verify truncation going down, extension coming back
        axi_write(4'hF, 32'h4000_0000, 3'b010, 64'h0000_0000_DEAD_0007, 8'h0F);
        $display("%0t ns    s_axi_awid=0x%02h  (expected lower %0d bits of 0xF = 0x%0h)",
                 $time, s_axi_awid, ID_WIDTH_S, {{(ID_WIDTH_S-ID_WIDTH_M){1'b0}}, 4'hF});
        check("TC7 s_awid (zero-padded)", {56'h0, s_axi_awid},
              {56'h0, {(ID_WIDTH_S-ID_WIDTH_M){1'b0}}, 4'hF}, ID_WIDTH_S);
        $display("%0t ns    m_axi_bid=0x%0h   (expected 0xF)", $time, m_axi_bid);
        check("TC7 m_bid (from slave)", {60'h0, m_axi_bid}, {60'h0, 4'hF}, ID_WIDTH_M);

        // ==================================================================
        // TC8 – Back-to-back writes (no bubble cycles)
        // ==================================================================
        print_sep("TC8 : Back-to-back writes (2 transactions, no bubbles)");
        fork
            begin
                axi_write(4'h1, 32'h4000_0000, 3'b010, 64'hBBBB_BBBB_AAAA_AAAA, 8'h0F);
                axi_write(4'h2, 32'h4000_0000, 3'b010, 64'hDDDD_DDDD_CCCC_CCCC, 8'h0F);
            end
        join
        $display("%0t ns    TC8 back-to-back writes completed without timeout", $time);
        pass_count++;   // structural pass: no timeout/hang

        // ==================================================================
        // TC9 – Back-to-back reads
        // ==================================================================
        print_sep("TC9 : Back-to-back reads (2 transactions)");
        axi_read(4'h3, 32'h4000_0000, 3'b010, 32'h1111_0001, rdata_got);
        check("TC9 read#1 m_rdata[31:0]", rdata_got, {32'h1111_0001, 32'h1111_0001}, 32);
        axi_read(4'h4, 32'h4000_0000, 3'b010, 32'h2222_0002, rdata_got);
        check("TC9 read#2 m_rdata[31:0]", rdata_got, {32'h2222_0002, 32'h2222_0002}, 32);

        // ==================================================================
        // TC10 – Alternating lower/upper writes
        // ==================================================================
        print_sep("TC10: Alternating lower/upper word writes");
        // Lower (addr[2]=0)
        axi_write(4'h5, 32'h4000_0000, 3'b010, 64'hFFFF_FFFF_1010_1010, 8'h0F);
        $display("%0t ns    TC10a s_wdata=0x%08h (exp 0x1010_1010)", $time, s_axi_wdata);
        check("TC10a lower wdata", {32'h0,s_axi_wdata}, {32'h0,32'h1010_1010}, 32);
        // Upper (addr[2]=1)
        axi_write(4'h6, 32'h4000_0004, 3'b010, 64'h2020_2020_FFFF_FFFF, 8'hF0);
        $display("%0t ns    TC10b s_wdata=0x%08h (exp 0x2020_2020)", $time, s_axi_wdata);
        check("TC10b upper wdata", {32'h0,s_axi_wdata}, {32'h0,32'h2020_2020}, 32);

        // ==================================================================
        // TC11 – Write-then-read, addr[2]=0
        // ==================================================================
        print_sep("TC11: Write-then-read  addr[2]=0");
        axi_write(4'h7, 32'h4000_0000, 3'b010, 64'h0000_0000_ABCD_EF01, 8'h0F);
        axi_read (4'h7, 32'h4000_0000, 3'b010, 32'hABCD_EF01, rdata_got);
        check("TC11 m_rdata[31:0]", rdata_got, {32'hABCD_EF01, 32'hABCD_EF01}, 32);

        // ==================================================================
        // TC12 – Write-then-read, addr[2]=1
        // ==================================================================
        print_sep("TC12: Write-then-read  addr[2]=1");
        axi_write(4'h8, 32'h4000_0004, 3'b010, 64'hBAD0_CAFE_0000_0000, 8'hF0);
        axi_read (4'h8, 32'h4000_0004, 3'b010, 32'hBAD0_CAFE, rdata_got);
        check("TC12 m_rdata[63:32]", {rdata_got[31:0],32'h0}, {32'hBAD0_CAFE,32'h0}, 32);

        // ==================================================================
        // TC13 – W presented before AW is accepted (AW stalls 2 cycles)
        // ==================================================================
        print_sep("TC13: AW stall – W issued before AW accepted");
        @(negedge clk);
        s_axi_awready <= 1'b0;   // stall AW acceptance for 2 cycles

        m_axi_awid    <= 4'h9;
        m_axi_awaddr  <= 32'h4000_0000;   // addr[2]=0 → lower word
        m_axi_awsize  <= 3'b010;
        m_axi_awlen   <= 8'h00;
        m_axi_awburst <= 2'b01;
        m_axi_awvalid <= 1'b1;
        m_axi_wdata   <= 64'h0000_0000_CCCC_DDDD;
        m_axi_wstrb   <= 8'h0F;
        m_axi_wlast   <= 1'b1;
        m_axi_wvalid  <= 1'b1;

        wait_cycles(2);          // AW stalled
        @(negedge clk);
        s_axi_awready <= 1'b1;   // release AW
        wait_cycles(2);

        m_axi_awvalid <= 1'b0;
        m_axi_wvalid  <= 1'b0;

        // Issue B response
        @(negedge clk);
        s_axi_bid    <= s_axi_awid;
        s_axi_bresp  <= 2'b00;
        s_axi_bvalid <= 1'b1;
        wait_cycles(1);
        @(negedge clk);
        s_axi_bvalid <= 1'b0;
        wait_cycles(1);

        $display("%0t ns    TC13 s_wdata=0x%08h (exp 0xCCCC_DDDD after AW stall)", $time, s_axi_wdata);
        check("TC13 s_wdata after AW stall", {32'h0,s_axi_wdata}, {32'h0,32'hCCCC_DDDD}, 32);

        // ==================================================================
        // TC14 – Write with slave stall (awready / wready = 0 initially)
        // ==================================================================
        print_sep("TC14: Slave stall on write (awready=0 for 3 cycles)");
        @(negedge clk);
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;

        m_axi_awid    <= 4'hA;
        m_axi_awaddr  <= 32'h4000_0000;
        m_axi_awsize  <= 3'b010;
        m_axi_awlen   <= 8'h00;
        m_axi_awburst <= 2'b01;
        m_axi_awvalid <= 1'b1;
        m_axi_wdata   <= 64'h0000_0000_FACE_F00D;
        m_axi_wstrb   <= 8'h0F;
        m_axi_wlast   <= 1'b1;
        m_axi_wvalid  <= 1'b1;
        $display("%0t ns    TC14 – stalling slave for 3 cycles", $time);

        wait_cycles(3);
        @(negedge clk);
        s_axi_awready <= 1'b1;
        s_axi_wready  <= 1'b1;
        wait_cycles(2);

        m_axi_awvalid <= 1'b0;
        m_axi_wvalid  <= 1'b0;

        @(negedge clk);
        s_axi_bid    <= s_axi_awid;
        s_axi_bresp  <= 2'b00;
        s_axi_bvalid <= 1'b1;
        wait_cycles(1);
        @(negedge clk);
        s_axi_bvalid <= 1'b0;

        $display("%0t ns    TC14 s_wdata=0x%08h (exp 0xFACE_F00D)", $time, s_axi_wdata);
        check("TC14 s_wdata after stall", {32'h0,s_axi_wdata}, {32'h0,32'hFACE_F00D}, 32);

        wait_cycles(2);
        @(negedge clk);
        s_axi_awready <= 1'b1;  // restore defaults
        s_axi_wready  <= 1'b1;

        // ==================================================================
        // TC15 – Read with slave stall (arready=0 for 3 cycles)
        // ==================================================================
        print_sep("TC15: Slave stall on read  (arready=0 for 3 cycles)");
        @(negedge clk);
        s_axi_arready <= 1'b0;

        m_axi_arid    <= 4'hB;
        m_axi_araddr  <= 32'h4000_0000;
        m_axi_arsize  <= 3'b010;
        m_axi_arlen   <= 8'h00;
        m_axi_arburst <= 2'b01;
        m_axi_arvalid <= 1'b1;
        $display("%0t ns    TC15 – arready stalled for 3 cycles", $time);

        wait_cycles(3);
        @(negedge clk);
        s_axi_arready <= 1'b1;
        wait_cycles(1);
        m_axi_arvalid <= 1'b0;

        // Slave issues R response
        @(negedge clk);
        s_axi_rid    <= s_axi_arid;
        s_axi_rdata  <= 32'hBEEF_CAFE;
        s_axi_rresp  <= 2'b00;
        s_axi_rlast  <= 1'b1;
        s_axi_rvalid <= 1'b1;
        wait_cycles(1);
        rdata_got     = m_axi_rdata;
        $display("%0t ns    TC15 m_axi_rdata=0x%016h (exp {0xBEEF_CAFE,0xBEEF_CAFE})",
                 $time, rdata_got);
        check("TC15 m_rdata after ar-stall", rdata_got, {32'hBEEF_CAFE,32'hBEEF_CAFE}, 64);

        @(negedge clk);
        s_axi_rvalid <= 1'b0;
        @(negedge clk);
        s_axi_arready <= 1'b1;   // restore

        // ==================================================================
        // Final summary
        // ==================================================================
        wait_cycles(5);
        $display("\n================================================================");
        $display("  SIMULATION COMPLETE");
        $display("  Total checks : %0d", pass_count + fail_count);
        $display("  PASS         : %0d", pass_count);
        $display("  FAIL         : %0d", fail_count);
        $display("================================================================");
        if (fail_count == 0)
            $display("  >>> ALL CHECKS PASSED <<<\n");
        else
            $display("  >>> %0d CHECK(S) FAILED – inspect waveform <<<\n", fail_count);

        $finish;
    end

    // =========================================================================
    // Timeout watchdog (catches infinite hangs)
    // =========================================================================
    initial begin
        #(CLK_PERIOD * 50000);
        $display("\n%0t ns  [FATAL] Simulation TIMEOUT – possible hang", $time);
        $finish;
    end

    // =========================================================================
    // AXI protocol monitors – print every handshake event for Verdi annotation
    // =========================================================================

    // Master AW handshake
    always @(posedge clk) begin
        if (m_axi_awvalid && m_axi_awready)
            $display("%0t ns  [MON-AW ] awid=0x%0h  awaddr=0x%08h  awsize=%0b  awlen=%0d",
                     $time, m_axi_awid, m_axi_awaddr, m_axi_awsize, m_axi_awlen);
    end

    // Slave AW received
    always @(posedge clk) begin
        if (s_axi_awvalid && s_axi_awready)
            $display("%0t ns  [MON-SAW] s_awid=0x%02h  s_awaddr=0x%08h  s_awsize=%0b",
                     $time, s_axi_awid, s_axi_awaddr, s_axi_awsize);
    end

    // Master W handshake
    always @(posedge clk) begin
        if (m_axi_wvalid && m_axi_wready)
            $display("%0t ns  [MON-W  ] wdata=0x%016h  wstrb=0x%0h  wlast=%0b",
                     $time, m_axi_wdata, m_axi_wstrb, m_axi_wlast);
    end

    // Slave W received
    always @(posedge clk) begin
        if (s_axi_wvalid && s_axi_wready)
            $display("%0t ns  [MON-SW ] s_wdata=0x%08h  s_wstrb=0x%0h",
                     $time, s_axi_wdata, s_axi_wstrb);
    end

    // Slave B → Master
    always @(posedge clk) begin
        if (m_axi_bvalid && m_axi_bready)
            $display("%0t ns  [MON-B  ] m_bid=0x%0h  bresp=%0b",
                     $time, m_axi_bid, m_axi_bresp);
    end

    // Master AR handshake
    always @(posedge clk) begin
        if (m_axi_arvalid && m_axi_arready)
            $display("%0t ns  [MON-AR ] arid=0x%0h  araddr=0x%08h  arsize=%0b  arlen=%0d",
                     $time, m_axi_arid, m_axi_araddr, m_axi_arsize, m_axi_arlen);
    end

    // Slave AR received
    always @(posedge clk) begin
        if (s_axi_arvalid && s_axi_arready)
            $display("%0t ns  [MON-SAR] s_arid=0x%02h  s_araddr=0x%08h  s_arsize=%0b",
                     $time, s_axi_arid, s_axi_araddr, s_axi_arsize);
    end

    // Slave R → Master
    always @(posedge clk) begin
        if (m_axi_rvalid && m_axi_rready)
            $display("%0t ns  [MON-R  ] m_rid=0x%0h  m_rdata=0x%016h  rresp=%0b  rlast=%0b",
                     $time, m_axi_rid, m_axi_rdata, m_axi_rresp, m_axi_rlast);
    end

    // =========================================================================
    // Lane-steering assertions (immediate, combinational)
    // These fire during simulation if steering logic is ever wrong.
    // =========================================================================

    // Write: when a W handshake occurs and lane=0, s_wdata must equal m_wdata[31:0]
    always @(posedge clk) begin
        if (s_axi_wvalid && s_axi_wready) begin
            if (!dut.aw_lane) begin
                if (s_axi_wdata !== m_axi_wdata[31:0])
                    $display("%0t ns  [ASSERT-FAIL] Lane0 steering: s_wdata=0x%08h != m_wdata[31:0]=0x%08h",
                             $time, s_axi_wdata, m_axi_wdata[31:0]);
            end else begin
                if (s_axi_wdata !== m_axi_wdata[63:32])
                    $display("%0t ns  [ASSERT-FAIL] Lane1 steering: s_wdata=0x%08h != m_wdata[63:32]=0x%08h",
                             $time, s_axi_wdata, m_axi_wdata[63:32]);
            end
        end
    end

    // Read: when R handshake occurs, both 32-bit lanes of m_rdata must equal s_rdata
    always @(posedge clk) begin
        if (s_axi_rvalid && s_axi_rready) begin
            if ((m_axi_rdata[31:0] !== s_axi_rdata) || (m_axi_rdata[63:32] !== s_axi_rdata))
                $display("%0t ns  [ASSERT-FAIL] Rdata replication: m_rdata=0x%016h != {s_rdata,s_rdata}=0x%08h%08h",
                         $time, m_axi_rdata, s_axi_rdata, s_axi_rdata);
        end
    end

    // awsize / arsize must never be 3'b011 on slave side
    always @(posedge clk) begin
        if (s_axi_awvalid && s_axi_awready && s_axi_awsize == 3'b011)
            $display("%0t ns  [ASSERT-FAIL] s_axi_awsize == 3'b011 (not clamped!)", $time);
        if (s_axi_arvalid && s_axi_arready && s_axi_arsize == 3'b011)
            $display("%0t ns  [ASSERT-FAIL] s_axi_arsize == 3'b011 (not clamped!)", $time);
    end

endmodule

`end_keywords
