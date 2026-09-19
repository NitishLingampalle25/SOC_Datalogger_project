// =============================================================================
  // tb_aes_subsystem.sv
  // Testbench for aes_subsystem (bridge + aes_axi_slave)
  // Verifies AES-128 encryption and decryption using FIPS test vectors.
  // =============================================================================
  `timescale 1ns/1ps
  
  module tb_aes_subsystem;
  
  // ---------------------------------------------------------------------------
  // Parameters
  // ---------------------------------------------------------------------------
  localparam ADDR_WIDTH = 32;
  localparam DATA_WIDTH = 32;
  localparam ID_WIDTH   = 8;
  
  // ---------------------------------------------------------------------------
  // Clock & Reset
  // ---------------------------------------------------------------------------
  reg aclk    = 0;
  reg aresetn = 0;
  always #5 aclk = ~aclk;   // 100 MHz
  
  // ---------------------------------------------------------------------------
  // AXI4 Master → DUT signals
  // ---------------------------------------------------------------------------
  // AW
  reg  [ID_WIDTH-1:0]   m_awid    = 0;
  reg  [ADDR_WIDTH-1:0] m_awaddr  = 0;
  reg  [7:0]            m_awlen   = 0;
  reg  [2:0]            m_awsize  = 3'd2;
  reg  [1:0]            m_awburst = 2'd1;
  reg                   m_awlock  = 0;
  reg  [3:0]            m_awcache = 0;
  reg  [2:0]            m_awprot  = 0;
  reg  [3:0]            m_awqos   = 0;
  reg  [3:0]            m_awregion= 0;
  reg                   m_awvalid = 0;
  wire                  m_awready;
  // W
  reg  [DATA_WIDTH-1:0]   m_wdata  = 0;
  reg  [DATA_WIDTH/8-1:0] m_wstrb  = 4'hF;
  reg                     m_wlast  = 1;
  reg                     m_wvalid = 0;
  wire                    m_wready;
  // B
  wire [ID_WIDTH-1:0] m_bid;
  wire [1:0]          m_bresp;
  wire                m_bvalid;
  reg                 m_bready = 0;
  // AR
  reg  [ID_WIDTH-1:0]   m_arid    = 0;
  reg  [ADDR_WIDTH-1:0] m_araddr  = 0;
  reg  [7:0]            m_arlen   = 0;
  reg  [2:0]            m_arsize  = 3'd2;
  reg  [1:0]            m_arburst = 2'd1;
  reg                   m_arlock  = 0;
  reg  [3:0]            m_arcache = 0;
  reg  [2:0]            m_arprot  = 0;
  reg  [3:0]            m_arqos   = 0;
  reg  [3:0]            m_arregion= 0;
  reg                   m_arvalid = 0;
  wire                  m_arready;
  // R
  wire [ID_WIDTH-1:0]   m_rid;
  wire [DATA_WIDTH-1:0] m_rdata;
  wire [1:0]            m_rresp;
  wire                  m_rlast;
  wire                  m_rvalid;
  reg                   m_rready  = 0;
  
  // ---------------------------------------------------------------------------
  // DUT
  // ---------------------------------------------------------------------------
  aes_subsystem #(
      .ADDR_WIDTH  (ADDR_WIDTH),
      .DATA_WIDTH  (DATA_WIDTH),
      .ID_WIDTH    (ID_WIDTH),
      .LITE_ADDR_W (6)
  ) dut (
      .aclk           (aclk),
      .aresetn        (aresetn),
      .s_axi_awid     (m_awid),    .s_axi_awaddr  (m_awaddr),
      .s_axi_awlen    (m_awlen),   .s_axi_awsize  (m_awsize),
      .s_axi_awburst  (m_awburst), .s_axi_awlock  (m_awlock),
      .s_axi_awcache  (m_awcache), .s_axi_awprot  (m_awprot),
      .s_axi_awqos    (m_awqos),   .s_axi_awregion(m_awregion),
      .s_axi_awvalid  (m_awvalid), .s_axi_awready (m_awready),
      .s_axi_wdata    (m_wdata),   .s_axi_wstrb   (m_wstrb),
      .s_axi_wlast    (m_wlast),   .s_axi_wvalid  (m_wvalid),
      .s_axi_wready   (m_wready),
      .s_axi_bid      (m_bid),     .s_axi_bresp   (m_bresp),
      .s_axi_bvalid   (m_bvalid),  .s_axi_bready  (m_bready),
      .s_axi_arid     (m_arid),    .s_axi_araddr  (m_araddr),
      .s_axi_arlen    (m_arlen),   .s_axi_arsize  (m_arsize),
      .s_axi_arburst  (m_arburst), .s_axi_arlock  (m_arlock),
      .s_axi_arcache  (m_arcache), .s_axi_arprot  (m_arprot),
      .s_axi_arqos    (m_arqos),   .s_axi_arregion(m_arregion),
      .s_axi_arvalid  (m_arvalid), .s_axi_arready (m_arready),
      .s_axi_rid      (m_rid),     .s_axi_rdata   (m_rdata),
      .s_axi_rresp    (m_rresp),   .s_axi_rlast   (m_rlast),
      .s_axi_rvalid   (m_rvalid),  .s_axi_rready  (m_rready)
  );
  
  // ---------------------------------------------------------------------------
  // Timeout watchdog
  // ---------------------------------------------------------------------------
  initial begin
      #200000;
      $display("[TIMEOUT] Simulation exceeded budget.");
      $finish;
  end
  
  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------
  task axi_write;
      input [ADDR_WIDTH-1:0] addr;
      input [DATA_WIDTH-1:0] data;
      begin
          @(negedge aclk);
          m_awaddr  = addr;  m_awvalid = 1;
          m_wdata   = data;  m_wvalid  = 1;  m_wlast = 1;
          m_bready  = 1;
  
          // AW handshake
          @(posedge aclk); while (!m_awready) @(posedge aclk);
          @(negedge aclk); m_awvalid = 0;
  
          // W handshake
          @(posedge aclk); while (!m_wready) @(posedge aclk);
          @(negedge aclk); m_wvalid = 0;
  
          // B handshake
          @(posedge aclk); while (!m_bvalid) @(posedge aclk);
          @(negedge aclk); m_bready = 0;
  
          @(posedge aclk);
      end
  endtask
  
  // Returns read data; checks against expected if check_en=1
  reg [DATA_WIDTH-1:0] rd_data;
  task axi_read;
      input [ADDR_WIDTH-1:0]  addr;
      input [DATA_WIDTH-1:0]  expected;
      input                   check_en;
      begin
          @(negedge aclk);
          m_araddr  = addr; m_arvalid = 1;
          m_rready  = 1;
  
          @(posedge aclk); while (!m_arready) @(posedge aclk);
          @(negedge aclk); m_arvalid = 0;
  
          @(posedge aclk); while (!m_rvalid) @(posedge aclk);
          rd_data = m_rdata;
          @(negedge aclk); m_rready = 0;
  
          @(posedge aclk);
  
          if (check_en && (rd_data !== expected)) begin
              $display("[MISMATCH] addr=0x%02X  got=0x%08X  exp=0x%08X",
                       addr, rd_data, expected);
          end
      end
  endtask
  
  // Poll a register until a specific bit is set (max 2000 cycles)
  task poll_bit;
      input [ADDR_WIDTH-1:0] addr;
      input integer           bit_pos;
      integer i;
      begin
          for (i = 0; i < 2000; i = i + 1) begin
              axi_read(addr, 32'h0, 0);
              if (rd_data[bit_pos]) i = 2001; // break
              else @(posedge aclk);
          end
      end
  endtask
  
  // ---------------------------------------------------------------------------
  // Test vectors (FIPS-197 Appendix B)
  // Key    : 2b7e1516 28aed2a6 abf71588 09cf4f3c
  // Plain  : 3243f6a8 885a308d 313198a2 e0370734
  // Cipher : 3ad77bb4 0d7a3660 a89ecaf3 2466ef97
  // ---------------------------------------------------------------------------
  // 128-bit values split into 4×32-bit words (little-endian reg order: [31:0] first)
  localparam [31:0] KEY0   = 32'h2b7e1516;  // key[31:0]
  localparam [31:0] KEY1   = 32'h28aed2a6;  // key[63:32]
  localparam [31:0] KEY2   = 32'habf71588;  // key[95:64]
  localparam [31:0] KEY3   = 32'h09cf4f3c;  // key[127:96]
  
  localparam [31:0] PT0    = 32'h3243f6a8;
  localparam [31:0] PT1    = 32'h885a308d;
  localparam [31:0] PT2    = 32'h313198a2;
  localparam [31:0] PT3    = 32'he0370734;
  
  localparam [31:0] CT0    = 32'h3ad77bb4;
  localparam [31:0] CT1    = 32'h0d7a3660;
  localparam [31:0] CT2    = 32'ha89ecaf3;
  localparam [31:0] CT3    = 32'h2466ef97;
  
  integer fail = 0;
  
  // ---------------------------------------------------------------------------
  // Main sequence
  // ---------------------------------------------------------------------------
  initial begin
      // ---- Reset ----
      aresetn = 0;
      repeat(10) @(posedge aclk);
      aresetn = 1;
      repeat(5)  @(posedge aclk);
  
      // ==================================================================
      // TEST 1 : AES-128 Encryption
      // ==================================================================
  
      // Write Key → 0x04..0x10
      axi_write(32'h04, KEY0);
      axi_write(32'h08, KEY1);
      axi_write(32'h0C, KEY2);
      axi_write(32'h10, KEY3);
  
      // Write Plaintext → 0x14..0x20
      axi_write(32'h14, PT0);
      axi_write(32'h18, PT1);
      axi_write(32'h1C, PT2);
      axi_write(32'h20, PT3);
  
      // CTRL_STAT = 0x01 (start_ld=1, mode=encrypt)
      axi_write(32'h00, 32'h01);
  
      // Poll bit[8] (done)
      poll_bit(32'h00, 8);
  
      // Read & check ciphertext output
      axi_read(32'h24, CT0, 1); if (rd_data !== CT0) fail = fail + 1;
      axi_read(32'h28, CT1, 1); if (rd_data !== CT1) fail = fail + 1;
      axi_read(32'h2C, CT2, 1); if (rd_data !== CT2) fail = fail + 1;
      axi_read(32'h30, CT3, 1); if (rd_data !== CT3) fail = fail + 1;
  
      // ==================================================================
      // TEST 2 : AES-128 Decryption
      // ==================================================================
  
      // Write Key
      axi_write(32'h04, KEY0);
      axi_write(32'h08, KEY1);
      axi_write(32'h0C, KEY2);
      axi_write(32'h10, KEY3);
  
      // CTRL_STAT = 0x06 (key_ld=1, mode=decrypt) → trigger key schedule
      axi_write(32'h00, 32'h06);
  
      // Poll bit[9] (inv_kdone)
      poll_bit(32'h00, 9);
  
      // Write Ciphertext → 0x14..0x20
      axi_write(32'h14, CT0);
      axi_write(32'h18, CT1);
      axi_write(32'h1C, CT2);
      axi_write(32'h20, CT3);
  
      // CTRL_STAT = 0x05 (start_ld=1, mode=decrypt)
      axi_write(32'h00, 32'h05);
  
      // Poll bit[8] (done)
      poll_bit(32'h00, 8);
  
      // Read & check plaintext output
      axi_read(32'h24, PT0, 1); if (rd_data !== PT0) fail = fail + 1;
      axi_read(32'h28, PT1, 1); if (rd_data !== PT1) fail = fail + 1;
      axi_read(32'h2C, PT2, 1); if (rd_data !== PT2) fail = fail + 1;
      axi_read(32'h30, PT3, 1); if (rd_data !== PT3) fail = fail + 1;
  
      // ==================================================================
      // Result
      // ==================================================================
      if (fail == 0)
          $display("[TEST PASSED] AES-128 Encrypt + Decrypt verified successfully.");
      else
          $display("[TEST FAILED] %0d word(s) did not match expected values.", fail);
  
      $finish;
  end
  
  endmodule

