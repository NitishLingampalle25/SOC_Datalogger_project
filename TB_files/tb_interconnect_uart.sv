// =============================================================================
// TB      : tb_interconnect_uart.sv
// DUT     : axi_interconnect_uart_top
//           (axi_interconnect_wrap_2x6 → axi4_to_axilite_bridge → axi_uart_top)
//
// Master  : testbench drives the AXI4 s00 slave port of the interconnect.
// Slave   : UART (axi_uart_top) is mapped at UART_BASE = 32'h4000_0000.
//
// Register offsets (5-bit AXI4-Lite address inside UART):
//   0x00  RBR / THR
//   0x04  IER
//   0x08  BAUD divisor
//   0x0C  LCR
//   0x14  LSR
//
// Test sequence
//  1. Reset DUT.
//  2. Configure UART: LCR=0x03 (8N1), BAUD divisor = SIM_BAUD_DIV.
//  3. Write 0x55 to THR (transmit).
//  4. Poll LSR until TX FIFO empty (TEMT=1).
//  5. Drive loopback byte 0xA5 on uart_rx.
//  6. Poll LSR until RX data ready.
//  7. Read RBR and verify == 0xA5.
//
// Waveform: FSDB dump for Verdi.
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module tb_interconnect_uart;

  // ===========================================================================
  // Parameters
  // ===========================================================================

  parameter integer DATA_W        = 32;
  parameter integer ADDR_W        = 32;   // full AXI4 address width
  parameter integer IC_ID_W       = 8;    // interconnect ID width
  parameter integer STRB_W        = DATA_W / 8;

  // UART base address in the interconnect address map
  parameter [ADDR_W-1:0] UART_BASE = 32'h4000_0000;

  // UART register offsets (relative to UART_BASE)
  parameter [ADDR_W-1:0] OFF_RBR_THR = 32'h00;
  parameter [ADDR_W-1:0] OFF_IER     = 32'h04;
  parameter [ADDR_W-1:0] OFF_BAUD    = 32'h08;
  parameter [ADDR_W-1:0] OFF_LCR     = 32'h0C;
  parameter [ADDR_W-1:0] OFF_LSR     = 32'h14;

  // Simulation baud divisor (small to keep sim fast)
  parameter integer SIM_BAUD_DIV  = 10;
  // Cycles per UART bit at 16x oversampling (used for rx drive timing)
  parameter integer CYCLES_PER_BIT = SIM_BAUD_DIV;

  // LSR bit positions
  parameter integer LSR_DATA_READY = 0;
  parameter integer LSR_THRE       = 5;
  parameter integer LSR_TEMT       = 6;

  // ===========================================================================
  // Clocks and reset
  // ===========================================================================

  reg clk;
  reg fixed_clk;
  reg rst_n;

  initial begin
    clk       = 1'b0;
    fixed_clk = 1'b0;
  end

  always #5 clk       = ~clk;        // 100 MHz
  always #5 fixed_clk = ~fixed_clk;  // 100 MHz

  // ===========================================================================
  // AXI4 signals – s00 master (testbench drives these)
  // ===========================================================================

  // Write address channel
  reg  [IC_ID_W-1:0]  s00_awid;
  reg  [ADDR_W-1:0]   s00_awaddr;
  reg  [7:0]          s00_awlen;
  reg  [2:0]          s00_awsize;
  reg  [1:0]          s00_awburst;
  reg                 s00_awlock;
  reg  [3:0]          s00_awcache;
  reg  [2:0]          s00_awprot;
  reg  [3:0]          s00_awqos;
  reg                 s00_awvalid;
  wire                s00_awready;

  // Write data channel
  reg  [DATA_W-1:0]   s00_wdata;
  reg  [STRB_W-1:0]   s00_wstrb;
  reg                 s00_wlast;
  reg                 s00_wvalid;
  wire                s00_wready;

  // Write response channel
  wire [IC_ID_W-1:0]  s00_bid;
  wire [1:0]          s00_bresp;
  wire                s00_bvalid;
  reg                 s00_bready;

  // Read address channel
  reg  [IC_ID_W-1:0]  s00_arid;
  reg  [ADDR_W-1:0]   s00_araddr;
  reg  [7:0]          s00_arlen;
  reg  [2:0]          s00_arsize;
  reg  [1:0]          s00_arburst;
  reg                 s00_arlock;
  reg  [3:0]          s00_arcache;
  reg  [2:0]          s00_arprot;
  reg  [3:0]          s00_arqos;
  reg                 s00_arvalid;
  wire                s00_arready;

  // Read data channel
  wire [IC_ID_W-1:0]  s00_rid;
  wire [DATA_W-1:0]   s00_rdata;
  wire [1:0]          s00_rresp;
  wire                s00_rlast;
  wire                s00_rvalid;
  reg                 s00_rready;

  // ===========================================================================
  // AXI4 signals – s01 (tied off; not used in this TB)
  // ===========================================================================

  // All s01 inputs driven to inactive; s01 outputs ignored.
  wire s01_awready_nc, s01_wready_nc, s01_arready_nc, s01_bvalid_nc, s01_rvalid_nc, s01_rlast_nc;
  wire [IC_ID_W-1:0] s01_bid_nc, s01_rid_nc;
  wire [1:0] s01_bresp_nc, s01_rresp_nc;
  wire [DATA_W-1:0] s01_rdata_nc;

  // ===========================================================================
  // UART physical signals
  // ===========================================================================

  wire uart_tx;
  reg  uart_rx;
  wire uart_irq;

  // ===========================================================================
  // DUT
  // ===========================================================================

  axi_interconnect_uart_top #(
      .DATA_WIDTH    (DATA_W),
      .ADDR_WIDTH    (ADDR_W),
      .IC_ID_WIDTH   (IC_ID_W),
      .UART_BASE_ADDR(UART_BASE)
  ) dut (
      .clk               (clk),
      .rst_n             (rst_n),
      .fixed_clk         (fixed_clk),

      // s00
      .s00_axi_awid      (s00_awid),
      .s00_axi_awaddr    (s00_awaddr),
      .s00_axi_awlen     (s00_awlen),
      .s00_axi_awsize    (s00_awsize),
      .s00_axi_awburst   (s00_awburst),
      .s00_axi_awlock    (s00_awlock),
      .s00_axi_awcache   (s00_awcache),
      .s00_axi_awprot    (s00_awprot),
      .s00_axi_awqos     (s00_awqos),
      .s00_axi_awvalid   (s00_awvalid),
      .s00_axi_awready   (s00_awready),

      .s00_axi_wdata     (s00_wdata),
      .s00_axi_wstrb     (s00_wstrb),
      .s00_axi_wlast     (s00_wlast),
      .s00_axi_wvalid    (s00_wvalid),
      .s00_axi_wready    (s00_wready),

      .s00_axi_bid       (s00_bid),
      .s00_axi_bresp     (s00_bresp),
      .s00_axi_bvalid    (s00_bvalid),
      .s00_axi_bready    (s00_bready),

      .s00_axi_arid      (s00_arid),
      .s00_axi_araddr    (s00_araddr),
      .s00_axi_arlen     (s00_arlen),
      .s00_axi_arsize    (s00_arsize),
      .s00_axi_arburst   (s00_arburst),
      .s00_axi_arlock    (s00_arlock),
      .s00_axi_arcache   (s00_arcache),
      .s00_axi_arprot    (s00_arprot),
      .s00_axi_arqos     (s00_arqos),
      .s00_axi_arvalid   (s00_arvalid),
      .s00_axi_arready   (s00_arready),

      .s00_axi_rid       (s00_rid),
      .s00_axi_rdata     (s00_rdata),
      .s00_axi_rresp     (s00_rresp),
      .s00_axi_rlast     (s00_rlast),
      .s00_axi_rvalid    (s00_rvalid),
      .s00_axi_rready    (s00_rready),

      // s01 – inactive
      .s01_axi_awid      ({IC_ID_W{1'b0}}),
      .s01_axi_awaddr    ({ADDR_W{1'b0}}),
      .s01_axi_awlen     (8'd0),
      .s01_axi_awsize    (3'd2),
      .s01_axi_awburst   (2'b01),
      .s01_axi_awlock    (1'b0),
      .s01_axi_awcache   (4'd0),
      .s01_axi_awprot    (3'd0),
      .s01_axi_awqos     (4'd0),
      .s01_axi_awvalid   (1'b0),
      .s01_axi_awready   (s01_awready_nc),

      .s01_axi_wdata     ({DATA_W{1'b0}}),
      .s01_axi_wstrb     ({STRB_W{1'b0}}),
      .s01_axi_wlast     (1'b1),
      .s01_axi_wvalid    (1'b0),
      .s01_axi_wready    (s01_wready_nc),

      .s01_axi_bid       (s01_bid_nc),
      .s01_axi_bresp     (s01_bresp_nc),
      .s01_axi_bvalid    (s01_bvalid_nc),
      .s01_axi_bready    (1'b1),

      .s01_axi_arid      ({IC_ID_W{1'b0}}),
      .s01_axi_araddr    ({ADDR_W{1'b0}}),
      .s01_axi_arlen     (8'd0),
      .s01_axi_arsize    (3'd2),
      .s01_axi_arburst   (2'b01),
      .s01_axi_arlock    (1'b0),
      .s01_axi_arcache   (4'd0),
      .s01_axi_arprot    (3'd0),
      .s01_axi_arqos     (4'd0),
      .s01_axi_arvalid   (1'b0),
      .s01_axi_arready   (s01_arready_nc),

      .s01_axi_rid       (s01_rid_nc),
      .s01_axi_rdata     (s01_rdata_nc),
      .s01_axi_rresp     (s01_rresp_nc),
      .s01_axi_rlast     (s01_rlast_nc),
      .s01_axi_rvalid    (s01_rvalid_nc),
      .s01_axi_rready    (1'b1),

      // UART
      .uart_tx_o         (uart_tx),
      .uart_rx_i         (uart_rx),
      .uart_read_irq_o   (uart_irq)
  );

  // ===========================================================================
  // FSDB / VCD dump
  // ===========================================================================
  initial begin
    $display("[%0t] FSDB waveform dumping enabled", $time);
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, tb_axi_uart_top);
end  // ===========================================================================
  // Initialisation
  // ===========================================================================

  initial begin
    // Default AXI4 values (inactive)
    s00_awid    = {IC_ID_W{1'b0}};
    s00_awaddr  = {ADDR_W{1'b0}};
    s00_awlen   = 8'd0;                 // single beat
    s00_awsize  = 3'd2;                 // 4 bytes
    s00_awburst = 2'b01;                // INCR
    s00_awlock  = 1'b0;
    s00_awcache = 4'd0;
    s00_awprot  = 3'd0;
    s00_awqos   = 4'd0;
    s00_awvalid = 1'b0;

    s00_wdata   = {DATA_W{1'b0}};
    s00_wstrb   = {STRB_W{1'b1}};
    s00_wlast   = 1'b1;                 // always last for single beat
    s00_wvalid  = 1'b0;

    s00_bready  = 1'b1;

    s00_arid    = {IC_ID_W{1'b0}};
    s00_araddr  = {ADDR_W{1'b0}};
    s00_arlen   = 8'd0;
    s00_arsize  = 3'd2;
    s00_arburst = 2'b01;
    s00_arlock  = 1'b0;
    s00_arcache = 4'd0;
    s00_arprot  = 3'd0;
    s00_arqos   = 4'd0;
    s00_arvalid = 1'b0;

    s00_rready  = 1'b1;

    uart_rx     = 1'b1;   // idle line (UART idle = high)
    rst_n       = 1'b0;
  end

  // ===========================================================================
  // AXI4 write task  (single-beat, targets full 32-bit address)
  // ===========================================================================

  task automatic axi4_write(
      input [ADDR_W-1:0]  addr,
      input [DATA_W-1:0]  data,
      input [IC_ID_W-1:0] id
  );
    integer cnt;
    begin
      $display("[%0t ns] AXI4 WRITE  addr=0x%08h  data=0x%08h", $time, addr, data);

      @(posedge clk); #1;

      // Present write address + data simultaneously (AXI4 allows this)
      s00_awid    <= id;
      s00_awaddr  <= addr;
      s00_awlen   <= 8'd0;
      s00_awsize  <= 3'd2;
      s00_awburst <= 2'b01;
      s00_awvalid <= 1'b1;

      s00_wdata   <= data;
      s00_wstrb   <= 4'hF;
      s00_wlast   <= 1'b1;
      s00_wvalid  <= 1'b1;

      s00_bready  <= 1'b1;

      // Wait for both AWREADY and WREADY
      cnt = 0;
      fork
        begin : wait_aw
          @(posedge clk);
          while (!s00_awready) begin
            cnt = cnt + 1;
            if (cnt > 500) begin $display("[%0t ns] ERROR: AW timeout", $time); $finish; end
            @(posedge clk);
          end
          s00_awvalid <= 1'b0;
        end
        begin : wait_w
          @(posedge clk);
          while (!s00_wready) begin
            @(posedge clk);
          end
          s00_wvalid <= 1'b0;
          s00_wlast  <= 1'b0;
        end
      join

      // Wait for BVALID
      cnt = 0;
      @(posedge clk);
      while (!s00_bvalid) begin
        cnt = cnt + 1;
        if (cnt > 500) begin $display("[%0t ns] ERROR: BVALID timeout", $time); $finish; end
        @(posedge clk);
      end

      if (s00_bresp == 2'b00)
        $display("[%0t ns] WRITE OKAY  bresp=%0b", $time, s00_bresp);
      else
        $display("[%0t ns] WRITE ERROR bresp=%0b (NOT OKAY)", $time, s00_bresp);

      @(posedge clk); #1;
      s00_bready <= 1'b1;   // keep asserted
    end
  endtask

  // ===========================================================================
  // AXI4 read task  (single-beat)
  // ===========================================================================

  task automatic axi4_read(
      input  [ADDR_W-1:0]  addr,
      input  [IC_ID_W-1:0] id,
      output [DATA_W-1:0]  rdata_out
  );
    integer cnt;
    begin
      $display("[%0t ns] AXI4 READ   addr=0x%08h", $time, addr);

      @(posedge clk); #1;

      s00_arid    <= id;
      s00_araddr  <= addr;
      s00_arlen   <= 8'd0;
      s00_arsize  <= 3'd2;
      s00_arburst <= 2'b01;
      s00_arvalid <= 1'b1;
      s00_rready  <= 1'b1;

      // Wait for ARREADY
      cnt = 0;
      @(posedge clk);
      while (!s00_arready) begin
        cnt = cnt + 1;
        if (cnt > 500) begin $display("[%0t ns] ERROR: AR timeout", $time); $finish; end
        @(posedge clk);
      end
      s00_arvalid <= 1'b0;

      // Wait for RVALID
      cnt = 0;
      @(posedge clk);
      while (!s00_rvalid) begin
        cnt = cnt + 1;
        if (cnt > 500) begin $display("[%0t ns] ERROR: RVALID timeout", $time); $finish; end
        @(posedge clk);
      end

      rdata_out = s00_rdata;

      $display("[%0t ns] READ  DATA=0x%08h  rresp=%0b", $time, s00_rdata, s00_rresp);

      @(posedge clk); #1;
      s00_rready <= 1'b1;
    end
  endtask

  // ===========================================================================
  // Task: drive a UART byte on uart_rx (LSB first, NRZ)
  // ===========================================================================

  task automatic drive_uart_rx_byte(input [7:0] byte_in);
    integer i;
    begin
      // Start bit (low)
      uart_rx = 1'b0;
      repeat (CYCLES_PER_BIT) @(posedge clk);

      // Data bits LSB first
      for (i = 0; i < 8; i = i + 1) begin
        uart_rx = byte_in[i];
        repeat (CYCLES_PER_BIT) @(posedge clk);
      end

      // Stop bit (high)
      uart_rx = 1'b1;
      repeat (CYCLES_PER_BIT) @(posedge clk);
    end
  endtask

  // ===========================================================================
  // Task: poll LSR until a given bit is set (with timeout)
  // ===========================================================================

  task automatic poll_lsr(input integer bit_pos, output [DATA_W-1:0] lsr_val);
    integer attempt;
    reg  [DATA_W-1:0] rd;
    begin
      attempt = 0;
      rd      = {DATA_W{1'b0}};
      while (!rd[bit_pos]) begin
        attempt = attempt + 1;
        if (attempt > 50000) begin
          $display("[%0t ns] ERROR: LSR poll timeout waiting for bit %0d", $time, bit_pos);
          $finish;
        end
        axi4_read(UART_BASE + OFF_LSR, 8'h01, rd);
        repeat (4) @(posedge clk);
      end
      lsr_val = rd;
    end
  endtask

  // ===========================================================================
  // Main test stimulus
  // ===========================================================================

  reg [DATA_W-1:0] rd_data;
  reg [DATA_W-1:0] lsr_val;
  integer          errors;

  initial begin

    errors = 0;

    // -----------------------------------------------------------------------
    // 1. Reset
    // -----------------------------------------------------------------------
    $display("=================================================================");
    $display("[%0t ns] TEST 1: Reset", $time);
    $display("=================================================================");
    rst_n = 1'b0;
    repeat (20) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);
    $display("[%0t ns] Reset deasserted", $time);

    // -----------------------------------------------------------------------
    // 2. Configure UART: LCR = 0x03 (8N1), BAUD divisor = SIM_BAUD_DIV
    // -----------------------------------------------------------------------
    $display("");
    $display("=================================================================");
    $display("[%0t ns] TEST 2: UART configuration (LCR + BAUD)", $time);
    $display("=================================================================");

    // Write LCR: 8 data bits, no parity, 1 stop bit
    axi4_write(UART_BASE + OFF_LCR, 32'h0000_0003, 8'h01);

    // Write baud divisor
    axi4_write(UART_BASE + OFF_BAUD, SIM_BAUD_DIV, 8'h01);

    $display("[%0t ns] LCR and BAUD configured", $time);

    // -----------------------------------------------------------------------
    // 3. Write 0x55 to THR (transmit a byte)
    // -----------------------------------------------------------------------
    $display("");
    $display("=================================================================");
    $display("[%0t ns] TEST 3: Transmit 0x55 via THR", $time);
    $display("=================================================================");

    axi4_write(UART_BASE + OFF_RBR_THR, 32'h0000_0055, 8'h02);
    $display("[%0t ns] Wrote 0x55 to THR", $time);

    // -----------------------------------------------------------------------
    // 4. Poll LSR until TEMT (transmitter empty)
    // -----------------------------------------------------------------------
    $display("");
    $display("=================================================================");
    $display("[%0t ns] TEST 4: Poll LSR[TEMT] until TX done", $time);
    $display("=================================================================");

    poll_lsr(LSR_TEMT, lsr_val);
    $display("[%0t ns] PASS: LSR[TEMT]=1  LSR=0x%08h", $time, lsr_val);

    // -----------------------------------------------------------------------
    // 5. Drive 0xA5 on uart_rx (simulated external sender → UART RX)
    // -----------------------------------------------------------------------
    $display("");
    $display("=================================================================");
    $display("[%0t ns] TEST 5: Drive 0xA5 on uart_rx (loopback byte)", $time);
    $display("=================================================================");

    drive_uart_rx_byte(8'hA5);
    $display("[%0t ns] Finished driving 0xA5 on uart_rx", $time);

    // Wait a bit for the byte to be loaded into RX FIFO
    repeat (20) @(posedge clk);

    // -----------------------------------------------------------------------
    // 6. Poll LSR[DATA_READY] until RX data is available
    // -----------------------------------------------------------------------
    $display("");
    $display("=================================================================");
    $display("[%0t ns] TEST 6: Poll LSR[DATA_READY]", $time);
    $display("=================================================================");

    poll_lsr(LSR_DATA_READY, lsr_val);
    $display("[%0t ns] PASS: LSR[DATA_READY]=1  LSR=0x%08h", $time, lsr_val);

    // -----------------------------------------------------------------------
    // 7. Read RBR and verify received data = 0xA5
    // -----------------------------------------------------------------------
    $display("");
    $display("=================================================================");
    $display("[%0t ns] TEST 7: Read RBR and verify == 0xA5", $time);
    $display("=================================================================");

    axi4_read(UART_BASE + OFF_RBR_THR, 8'h03, rd_data);

    if (rd_data[7:0] === 8'hA5) begin
      $display("[%0t ns] PASS: RBR = 0x%02h (expected 0xA5)", $time, rd_data[7:0]);
    end else begin
      $display("[%0t ns] FAIL: RBR = 0x%02h (expected 0xA5)", $time, rd_data[7:0]);
      errors = errors + 1;
    end

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    $display("");
    $display("=================================================================");
    if (errors == 0)
      $display("[%0t ns] ALL TESTS PASSED", $time);
    else
      $display("[%0t ns] %0d TEST(S) FAILED", $time, errors);
    $display("=================================================================");

    repeat (20) @(posedge clk);
    $finish;
  end

  // ===========================================================================
  // Watchdog – safety timeout to prevent infinite simulation
  // ===========================================================================

  initial begin
    #10_000_000;
    $display("[%0t ns] WATCHDOG: simulation timed out", $time);
    $finish;
  end


 

endmodule


