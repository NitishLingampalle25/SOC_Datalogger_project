// =============================================================================
  // Testbench: tb_axi_interconnect_wrap_2x6.sv
  // DUT     : axi_interconnect_wrap_2x6
  // Purpose : Single write + single read from M0 to S0 (addr 0x4000_0000)
  // =============================================================================
  `timescale 1ns/1ps
  
  module tb_axi_interconnect_wrap_2x6;
  
  // ---------------------------------------------------------------------------
  // Parameters (match DUT defaults)
  // ---------------------------------------------------------------------------
  localparam DATA_WIDTH  = 32;
  localparam ADDR_WIDTH  = 32;
  localparam STRB_WIDTH  = DATA_WIDTH/8;
  localparam ID_WIDTH    = 8;
  localparam AWUSER_WIDTH = 1;
  localparam WUSER_WIDTH  = 1;
  localparam BUSER_WIDTH  = 1;
  localparam ARUSER_WIDTH = 1;
  localparam RUSER_WIDTH  = 1;
  
  // S0 base address and address width (24-bit window => 0x4000_0000 .. 0x40FF_FFFF)
  localparam [ADDR_WIDTH-1:0] S0_BASE  = 32'h4000_0000;
  localparam integer           S0_AWIDTH = 24;
  
  localparam [ADDR_WIDTH-1:0] S1_BASE  = 32'h4100_0000;
  localparam [ADDR_WIDTH-1:0] S2_BASE  = 32'h4200_0000;
  localparam [ADDR_WIDTH-1:0] S3_BASE  = 32'h4300_0000;
  localparam [ADDR_WIDTH-1:0] S4_BASE  = 32'h4400_0000;
  localparam [ADDR_WIDTH-1:0] S5_BASE  = 32'h4500_0000;
  
  localparam [31:0] WR_ADDR = 32'h4000_0000;
  localparam [31:0] WR_DATA = 32'hDEAD_BEEF;
  
  // ---------------------------------------------------------------------------
  // Clock & Reset
  // ---------------------------------------------------------------------------
  reg clk;
  reg rst;
  // DUT uses active-high rst
  initial clk = 0;
  always #5 clk = ~clk;   // 100 MHz
  
  // ---------------------------------------------------------------------------
  // ---- S00 (DUT slave side, driven by M0 logic in TB) ----------------------
  // ---------------------------------------------------------------------------
  // AW
  reg  [ID_WIDTH-1:0]    s00_awid;
  reg  [ADDR_WIDTH-1:0]  s00_awaddr;
  reg  [7:0]             s00_awlen;
  reg  [2:0]             s00_awsize;
  reg  [1:0]             s00_awburst;
  reg                    s00_awlock;
  reg  [3:0]             s00_awcache;
  reg  [2:0]             s00_awprot;
  reg  [3:0]             s00_awqos;
  reg  [AWUSER_WIDTH-1:0] s00_awuser;
  reg                    s00_awvalid;
  wire                   s00_awready;
  // W
  reg  [DATA_WIDTH-1:0]  s00_wdata;
  reg  [STRB_WIDTH-1:0]  s00_wstrb;
  reg                    s00_wlast;
  reg  [WUSER_WIDTH-1:0] s00_wuser;
  reg                    s00_wvalid;
  wire                   s00_wready;
  // B
  wire [ID_WIDTH-1:0]    s00_bid;
  wire [1:0]             s00_bresp;
  wire [BUSER_WIDTH-1:0] s00_buser;
  wire                   s00_bvalid;
  reg                    s00_bready;
  // AR
  reg  [ID_WIDTH-1:0]    s00_arid;
  reg  [ADDR_WIDTH-1:0]  s00_araddr;
  reg  [7:0]             s00_arlen;
  reg  [2:0]             s00_arsize;
  reg  [1:0]             s00_arburst;
  reg                    s00_arlock;
  reg  [3:0]             s00_arcache;
  reg  [2:0]             s00_arprot;
  reg  [3:0]             s00_arqos;
  reg  [ARUSER_WIDTH-1:0] s00_aruser;
  reg                    s00_arvalid;
  wire                   s00_arready;
  // R
  wire [ID_WIDTH-1:0]    s00_rid;
  wire [DATA_WIDTH-1:0]  s00_rdata;
  wire [1:0]             s00_rresp;
  wire                   s00_rlast;
  wire [RUSER_WIDTH-1:0] s00_ruser;
  wire                   s00_rvalid;
  reg                    s00_rready;
  
  // ---- S01 (M1 – idle) -------------------------------------------------------
  reg  [ID_WIDTH-1:0]    s01_awid   = 0;
  reg  [ADDR_WIDTH-1:0]  s01_awaddr = 0;
  reg  [7:0]             s01_awlen  = 0;
  reg  [2:0]             s01_awsize = 0;
  reg  [1:0]             s01_awburst= 2'b01;
  reg                    s01_awlock = 0;
  reg  [3:0]             s01_awcache= 0;
  reg  [2:0]             s01_awprot = 0;
  reg  [3:0]             s01_awqos  = 0;
  reg  [AWUSER_WIDTH-1:0] s01_awuser= 0;
  reg                    s01_awvalid= 0;
  wire                   s01_awready;
  reg  [DATA_WIDTH-1:0]  s01_wdata  = 0;
  reg  [STRB_WIDTH-1:0]  s01_wstrb  = 0;
  reg                    s01_wlast  = 0;
  reg  [WUSER_WIDTH-1:0] s01_wuser  = 0;
  reg                    s01_wvalid = 0;
  wire                   s01_wready;
  wire [ID_WIDTH-1:0]    s01_bid;
  wire [1:0]             s01_bresp;
  wire [BUSER_WIDTH-1:0] s01_buser;
  wire                   s01_bvalid;
  reg                    s01_bready = 1;
  reg  [ID_WIDTH-1:0]    s01_arid   = 0;
  reg  [ADDR_WIDTH-1:0]  s01_araddr = 0;
  reg  [7:0]             s01_arlen  = 0;
  reg  [2:0]             s01_arsize = 0;
  reg  [1:0]             s01_arburst= 2'b01;
  reg                    s01_arlock = 0;
  reg  [3:0]             s01_arcache= 0;
  reg  [2:0]             s01_arprot = 0;
  reg  [3:0]             s01_arqos  = 0;
  reg  [ARUSER_WIDTH-1:0] s01_aruser= 0;
  reg                    s01_arvalid= 0;
  wire                   s01_arready;
  wire [ID_WIDTH-1:0]    s01_rid;
  wire [DATA_WIDTH-1:0]  s01_rdata;
  wire [1:0]             s01_rresp;
  wire                   s01_rlast;
  wire [RUSER_WIDTH-1:0] s01_ruser;
  wire                   s01_rvalid;
  reg                    s01_rready = 1;
  
  // ---------------------------------------------------------------------------
  // DUT master-side wires (connect to slave stubs)
  // ---------------------------------------------------------------------------
  // ---- m00 (S0) --------------------------------------------------------------
  wire [ID_WIDTH-1:0]    m00_awid;
  wire [ADDR_WIDTH-1:0]  m00_awaddr;
  wire [7:0]             m00_awlen;
  wire [2:0]             m00_awsize;
  wire [1:0]             m00_awburst;
  wire                   m00_awlock;
  wire [3:0]             m00_awcache;
  wire [2:0]             m00_awprot;
  wire [3:0]             m00_awqos;
  wire [3:0]             m00_awregion;
  wire [AWUSER_WIDTH-1:0] m00_awuser;
  wire                   m00_awvalid;
  reg                    m00_awready;
  wire [DATA_WIDTH-1:0]  m00_wdata;
  wire [STRB_WIDTH-1:0]  m00_wstrb;
  wire                   m00_wlast;
  wire [WUSER_WIDTH-1:0] m00_wuser;
  wire                   m00_wvalid;
  reg                    m00_wready;
  reg  [ID_WIDTH-1:0]    m00_bid;
  reg  [1:0]             m00_bresp;
  reg  [BUSER_WIDTH-1:0] m00_buser;
  reg                    m00_bvalid;
  wire                   m00_bready;
  wire [ID_WIDTH-1:0]    m00_arid;
  wire [ADDR_WIDTH-1:0]  m00_araddr;
  wire [7:0]             m00_arlen;
  wire [2:0]             m00_arsize;
  wire [1:0]             m00_arburst;
  wire                   m00_arlock;
  wire [3:0]             m00_arcache;
  wire [2:0]             m00_arprot;
  wire [3:0]             m00_arqos;
  wire [3:0]             m00_arregion;
  wire [ARUSER_WIDTH-1:0] m00_aruser;
  wire                   m00_arvalid;
  reg                    m00_arready;
  reg  [ID_WIDTH-1:0]    m00_rid;
  reg  [DATA_WIDTH-1:0]  m00_rdata;
  reg  [1:0]             m00_rresp;
  reg                    m00_rlast;
  reg  [RUSER_WIDTH-1:0] m00_ruser;
  reg                    m00_rvalid;
  wire                   m00_rready;
  
  // Macro to declare idle DUT master port wires (outputs from DUT, inputs driven 0)
  `define IDLE_MPORT(N) \
      wire [ID_WIDTH-1:0]    m``N``_awid;   wire [ADDR_WIDTH-1:0] m``N``_awaddr; \
      wire [7:0]             m``N``_awlen;  wire [2:0]  m``N``_awsize;           \
      wire [1:0]             m``N``_awburst;wire        m``N``_awlock;            \
      wire [3:0]             m``N``_awcache;wire [2:0]  m``N``_awprot;           \
      wire [3:0]             m``N``_awqos; wire [3:0]   m``N``_awregion;         \
      wire [AWUSER_WIDTH-1:0] m``N``_awuser;wire        m``N``_awvalid;          \
      reg                    m``N``_awready = 1;                                  \
      wire [DATA_WIDTH-1:0]  m``N``_wdata;  wire [STRB_WIDTH-1:0] m``N``_wstrb; \
      wire                   m``N``_wlast;  wire [WUSER_WIDTH-1:0] m``N``_wuser;\
      wire                   m``N``_wvalid; reg  m``N``_wready  = 1;             \
      reg  [ID_WIDTH-1:0]    m``N``_bid    = 0; reg [1:0] m``N``_bresp = 0;     \
      reg  [BUSER_WIDTH-1:0] m``N``_buser  = 0; reg       m``N``_bvalid = 0;    \
      wire                   m``N``_bready;                                       \
      wire [ID_WIDTH-1:0]    m``N``_arid;  wire [ADDR_WIDTH-1:0] m``N``_araddr; \
      wire [7:0]             m``N``_arlen; wire [2:0]  m``N``_arsize;            \
      wire [1:0]             m``N``_arburst;wire        m``N``_arlock;            \
      wire [3:0]             m``N``_arcache;wire [2:0]  m``N``_arprot;           \
      wire [3:0]             m``N``_arqos; wire [3:0]   m``N``_arregion;         \
      wire [ARUSER_WIDTH-1:0] m``N``_aruser;wire        m``N``_arvalid;          \
      reg                    m``N``_arready = 1;                                  \
      reg  [ID_WIDTH-1:0]    m``N``_rid    = 0; reg [DATA_WIDTH-1:0] m``N``_rdata = 0; \
      reg  [1:0]             m``N``_rresp  = 0; reg  m``N``_rlast = 1;           \
      reg  [RUSER_WIDTH-1:0] m``N``_ruser  = 0; reg  m``N``_rvalid = 0;         \
      wire                   m``N``_rready;
  
  `IDLE_MPORT(01)
  `IDLE_MPORT(02)
  `IDLE_MPORT(03)
  `IDLE_MPORT(04)
  `IDLE_MPORT(05)
  
  // ---------------------------------------------------------------------------
  // S0 Slave Stub – minimal 1-location memory
  // ---------------------------------------------------------------------------
  reg [DATA_WIDTH-1:0] s0_mem;   // single storage location
  
  // Write path
  reg  s0_aw_accepted;
  reg  s0_w_accepted;
  
  always @(posedge clk) begin
      if (rst) begin
          m00_awready   <= 1'b0;
          m00_wready    <= 1'b0;
          m00_bvalid    <= 1'b0;
          m00_bresp     <= 2'b00;
          m00_bid       <= 0;
          m00_buser     <= 0;
          s0_aw_accepted<= 1'b0;
          s0_w_accepted <= 1'b0;
          s0_mem        <= 32'b0;
      end else begin
          // Accept AW
          if (!s0_aw_accepted) begin
              m00_awready <= 1'b1;
              if (m00_awvalid && m00_awready) begin
                  m00_awready    <= 1'b0;
                  s0_aw_accepted <= 1'b1;
              end
          end
  
          // Accept W and store data
          if (!s0_w_accepted) begin
              m00_wready <= 1'b1;
              if (m00_wvalid && m00_wready) begin
                  s0_mem        <= m00_wdata;
                  m00_wready    <= 1'b0;
                  s0_w_accepted <= 1'b1;
              end
          end
  
          // Send B response once both AW and W accepted
          if (s0_aw_accepted && s0_w_accepted && !m00_bvalid) begin
              m00_bvalid    <= 1'b1;
              m00_bresp     <= 2'b00; // OKAY
              m00_bid       <= 8'h01;
              m00_buser     <= 0;
          end
          if (m00_bvalid && m00_bready) begin
              m00_bvalid    <= 1'b0;
              s0_aw_accepted<= 1'b0;
              s0_w_accepted <= 1'b0;
          end
      end
  end
  
  // Read path
  always @(posedge clk) begin
      if (rst) begin
          m00_arready <= 1'b0;
          m00_rvalid  <= 1'b0;
          m00_rdata   <= 32'b0;
          m00_rresp   <= 2'b00;
          m00_rlast   <= 1'b1;
          m00_rid     <= 0;
          m00_ruser   <= 0;
      end else begin
          m00_arready <= 1'b1;
          if (m00_arvalid && m00_arready) begin
              m00_arready <= 1'b0;
              m00_rvalid  <= 1'b1;
              m00_rdata   <= s0_mem;
              m00_rresp   <= 2'b00;
              m00_rlast   <= 1'b1;
              m00_rid     <= 8'h02;
              m00_ruser   <= 0;
          end
          if (m00_rvalid && m00_rready) begin
              m00_rvalid  <= 1'b0;
              m00_arready <= 1'b1;
          end
      end
  end
  
  // ---------------------------------------------------------------------------
  // DUT Instantiation
  // ---------------------------------------------------------------------------
  axi_interconnect_wrap_2x6 #(
      .DATA_WIDTH         (DATA_WIDTH),
      .ADDR_WIDTH         (ADDR_WIDTH),
      .STRB_WIDTH         (STRB_WIDTH),
      .ID_WIDTH           (ID_WIDTH),
      .AWUSER_ENABLE      (0),
      .WUSER_ENABLE       (0),
      .BUSER_ENABLE       (0),
      .ARUSER_ENABLE      (0),
      .RUSER_ENABLE       (0),
      .FORWARD_ID         (0),
      .M_REGIONS          (1),
      // S0 → 0x4000_0000, 24-bit window
      .M00_BASE_ADDR      (S0_BASE),
      .M00_ADDR_WIDTH     ({1{32'd24}}),
      .M00_CONNECT_READ   (2'b11),
      .M00_CONNECT_WRITE  (2'b11),
      .M00_SECURE         (1'b0),
      // S1 → 0x4100_0000
      .M01_BASE_ADDR      (S1_BASE),
      .M01_ADDR_WIDTH     ({1{32'd24}}),
      .M01_CONNECT_READ   (2'b11),
      .M01_CONNECT_WRITE  (2'b11),
      .M01_SECURE         (1'b0),
      // S2 → 0x4200_0000
      .M02_BASE_ADDR      (S2_BASE),
      .M02_ADDR_WIDTH     ({1{32'd24}}),
      .M02_CONNECT_READ   (2'b11),
      .M02_CONNECT_WRITE  (2'b11),
      .M02_SECURE         (1'b0),
      // S3 → 0x4300_0000
      .M03_BASE_ADDR      (S3_BASE),
      .M03_ADDR_WIDTH     ({1{32'd24}}),
      .M03_CONNECT_READ   (2'b11),
      .M03_CONNECT_WRITE  (2'b11),
      .M03_SECURE         (1'b0),
      // S4 → 0x4400_0000
      .M04_BASE_ADDR      (S4_BASE),
      .M04_ADDR_WIDTH     ({1{32'd24}}),
      .M04_CONNECT_READ   (2'b11),
      .M04_CONNECT_WRITE  (2'b11),
      .M04_SECURE         (1'b0),
      // S5 → 0x4500_0000
      .M05_BASE_ADDR      (S5_BASE),
      .M05_ADDR_WIDTH     ({1{32'd24}}),
      .M05_CONNECT_READ   (2'b11),
      .M05_CONNECT_WRITE  (2'b11),
      .M05_SECURE         (1'b0)
  ) dut (
      .clk                (clk),
      .rst                (rst),
      // ---- S00 (M0 master) ----
      .s00_axi_awid       (s00_awid),
      .s00_axi_awaddr     (s00_awaddr),
      .s00_axi_awlen      (s00_awlen),
      .s00_axi_awsize     (s00_awsize),
      .s00_axi_awburst    (s00_awburst),
      .s00_axi_awlock     (s00_awlock),
      .s00_axi_awcache    (s00_awcache),
      .s00_axi_awprot     (s00_awprot),
      .s00_axi_awqos      (s00_awqos),
      .s00_axi_awuser     (s00_awuser),
      .s00_axi_awvalid    (s00_awvalid),
      .s00_axi_awready    (s00_awready),
      .s00_axi_wdata      (s00_wdata),
      .s00_axi_wstrb      (s00_wstrb),
      .s00_axi_wlast      (s00_wlast),
      .s00_axi_wuser      (s00_wuser),
      .s00_axi_wvalid     (s00_wvalid),
      .s00_axi_wready     (s00_wready),
      .s00_axi_bid        (s00_bid),
      .s00_axi_bresp      (s00_bresp),
      .s00_axi_buser      (s00_buser),
      .s00_axi_bvalid     (s00_bvalid),
      .s00_axi_bready     (s00_bready),
      .s00_axi_arid       (s00_arid),
      .s00_axi_araddr     (s00_araddr),
      .s00_axi_arlen      (s00_arlen),
      .s00_axi_arsize     (s00_arsize),
      .s00_axi_arburst    (s00_arburst),
      .s00_axi_arlock     (s00_arlock),
      .s00_axi_arcache    (s00_arcache),
      .s00_axi_arprot     (s00_arprot),
      .s00_axi_arqos      (s00_arqos),
      .s00_axi_aruser     (s00_aruser),
      .s00_axi_arvalid    (s00_arvalid),
      .s00_axi_arready    (s00_arready),
      .s00_axi_rid        (s00_rid),
      .s00_axi_rdata      (s00_rdata),
      .s00_axi_rresp      (s00_rresp),
      .s00_axi_rlast      (s00_rlast),
      .s00_axi_ruser      (s00_ruser),
      .s00_axi_rvalid     (s00_rvalid),
      .s00_axi_rready     (s00_rready),
      // ---- S01 (M1 idle) ----
      .s01_axi_awid       (s01_awid),
      .s01_axi_awaddr     (s01_awaddr),
      .s01_axi_awlen      (s01_awlen),
      .s01_axi_awsize     (s01_awsize),
      .s01_axi_awburst    (s01_awburst),
      .s01_axi_awlock     (s01_awlock),
      .s01_axi_awcache    (s01_awcache),
      .s01_axi_awprot     (s01_awprot),
      .s01_axi_awqos      (s01_awqos),
      .s01_axi_awuser     (s01_awuser),
      .s01_axi_awvalid    (s01_awvalid),
      .s01_axi_awready    (s01_awready),
      .s01_axi_wdata      (s01_wdata),
      .s01_axi_wstrb      (s01_wstrb),
      .s01_axi_wlast      (s01_wlast),
      .s01_axi_wuser      (s01_wuser),
      .s01_axi_wvalid     (s01_wvalid),
      .s01_axi_wready     (s01_wready),
      .s01_axi_bid        (s01_bid),
      .s01_axi_bresp      (s01_bresp),
      .s01_axi_buser      (s01_buser),
      .s01_axi_bvalid     (s01_bvalid),
      .s01_axi_bready     (s01_bready),
      .s01_axi_arid       (s01_arid),
      .s01_axi_araddr     (s01_araddr),
      .s01_axi_arlen      (s01_arlen),
      .s01_axi_arsize     (s01_arsize),
      .s01_axi_arburst    (s01_arburst),
      .s01_axi_arlock     (s01_arlock),
      .s01_axi_arcache    (s01_arcache),
      .s01_axi_arprot     (s01_arprot),
      .s01_axi_arqos      (s01_arqos),
      .s01_axi_aruser     (s01_aruser),
      .s01_axi_arvalid    (s01_arvalid),
      .s01_axi_arready    (s01_arready),
      .s01_axi_rid        (s01_rid),
      .s01_axi_rdata      (s01_rdata),
      .s01_axi_rresp      (s01_rresp),
      .s01_axi_rlast      (s01_rlast),
      .s01_axi_ruser      (s01_ruser),
      .s01_axi_rvalid     (s01_rvalid),
      .s01_axi_rready     (s01_rready),
      // ---- M00 → S0 slave stub ----
      .m00_axi_awid       (m00_awid),
      .m00_axi_awaddr     (m00_awaddr),
      .m00_axi_awlen      (m00_awlen),
      .m00_axi_awsize     (m00_awsize),
      .m00_axi_awburst    (m00_awburst),
      .m00_axi_awlock     (m00_awlock),
      .m00_axi_awcache    (m00_awcache),
      .m00_axi_awprot     (m00_awprot),
      .m00_axi_awqos      (m00_awqos),
      .m00_axi_awregion   (m00_awregion),
      .m00_axi_awuser     (m00_awuser),
      .m00_axi_awvalid    (m00_awvalid),
      .m00_axi_awready    (m00_awready),
      .m00_axi_wdata      (m00_wdata),
      .m00_axi_wstrb      (m00_wstrb),
      .m00_axi_wlast      (m00_wlast),
      .m00_axi_wuser      (m00_wuser),
      .m00_axi_wvalid     (m00_wvalid),
      .m00_axi_wready     (m00_wready),
      .m00_axi_bid        (m00_bid),
      .m00_axi_bresp      (m00_bresp),
      .m00_axi_buser      (m00_buser),
      .m00_axi_bvalid     (m00_bvalid),
      .m00_axi_bready     (m00_bready),
      .m00_axi_arid       (m00_arid),
      .m00_axi_araddr     (m00_araddr),
      .m00_axi_arlen      (m00_arlen),
      .m00_axi_arsize     (m00_arsize),
      .m00_axi_arburst    (m00_arburst),
      .m00_axi_arlock     (m00_arlock),
      .m00_axi_arcache    (m00_arcache),
      .m00_axi_arprot     (m00_arprot),
      .m00_axi_arqos      (m00_arqos),
      .m00_axi_arregion   (m00_arregion),
      .m00_axi_aruser     (m00_aruser),
      .m00_axi_arvalid    (m00_arvalid),
      .m00_axi_arready    (m00_arready),
      .m00_axi_rid        (m00_rid),
      .m00_axi_rdata      (m00_rdata),
      .m00_axi_rresp      (m00_rresp),
      .m00_axi_rlast      (m00_rlast),
      .m00_axi_ruser      (m00_ruser),
      .m00_axi_rvalid     (m00_rvalid),
      .m00_axi_rready     (m00_rready),
      // ---- M01-M05 → idle slave stubs ----
      .m01_axi_awid       (m01_awid),   .m01_axi_awaddr  (m01_awaddr),
      .m01_axi_awlen      (m01_awlen),  .m01_axi_awsize  (m01_awsize),
      .m01_axi_awburst    (m01_awburst),.m01_axi_awlock  (m01_awlock),
      .m01_axi_awcache    (m01_awcache),.m01_axi_awprot  (m01_awprot),
      .m01_axi_awqos      (m01_awqos),  .m01_axi_awregion(m01_awregion),
      .m01_axi_awuser     (m01_awuser), .m01_axi_awvalid (m01_awvalid),
      .m01_axi_awready    (m01_awready),.m01_axi_wdata   (m01_wdata),
      .m01_axi_wstrb      (m01_wstrb),  .m01_axi_wlast   (m01_wlast),
      .m01_axi_wuser      (m01_wuser),  .m01_axi_wvalid  (m01_wvalid),
      .m01_axi_wready     (m01_wready), .m01_axi_bid     (m01_bid),
      .m01_axi_bresp      (m01_bresp),  .m01_axi_buser   (m01_buser),
      .m01_axi_bvalid     (m01_bvalid), .m01_axi_bready  (m01_bready),
      .m01_axi_arid       (m01_arid),   .m01_axi_araddr  (m01_araddr),
      .m01_axi_arlen      (m01_arlen),  .m01_axi_arsize  (m01_arsize),
      .m01_axi_arburst    (m01_arburst),.m01_axi_arlock  (m01_arlock),
      .m01_axi_arcache    (m01_arcache),.m01_axi_arprot  (m01_arprot),
      .m01_axi_arqos      (m01_arqos),  .m01_axi_arregion(m01_arregion),
      .m01_axi_aruser     (m01_aruser), .m01_axi_arvalid (m01_arvalid),
      .m01_axi_arready    (m01_arready),.m01_axi_rid     (m01_rid),
      .m01_axi_rdata      (m01_rdata),  .m01_axi_rresp   (m01_rresp),
      .m01_axi_rlast      (m01_rlast),  .m01_axi_ruser   (m01_ruser),
      .m01_axi_rvalid     (m01_rvalid), .m01_axi_rready  (m01_rready),
  
      .m02_axi_awid       (m02_awid),   .m02_axi_awaddr  (m02_awaddr),
      .m02_axi_awlen      (m02_awlen),  .m02_axi_awsize  (m02_awsize),
      .m02_axi_awburst    (m02_awburst),.m02_axi_awlock  (m02_awlock),
      .m02_axi_awcache    (m02_awcache),.m02_axi_awprot  (m02_awprot),
      .m02_axi_awqos      (m02_awqos),  .m02_axi_awregion(m02_awregion),
      .m02_axi_awuser     (m02_awuser), .m02_axi_awvalid (m02_awvalid),
      .m02_axi_awready    (m02_awready),.m02_axi_wdata   (m02_wdata),
      .m02_axi_wstrb      (m02_wstrb),  .m02_axi_wlast   (m02_wlast),
      .m02_axi_wuser      (m02_wuser),  .m02_axi_wvalid  (m02_wvalid),
      .m02_axi_wready     (m02_wready), .m02_axi_bid     (m02_bid),
      .m02_axi_bresp      (m02_bresp),  .m02_axi_buser   (m02_buser),
      .m02_axi_bvalid     (m02_bvalid), .m02_axi_bready  (m02_bready),
      .m02_axi_arid       (m02_arid),   .m02_axi_araddr  (m02_araddr),
      .m02_axi_arlen      (m02_arlen),  .m02_axi_arsize  (m02_arsize),
      .m02_axi_arburst    (m02_arburst),.m02_axi_arlock  (m02_arlock),
      .m02_axi_arcache    (m02_arcache),.m02_axi_arprot  (m02_arprot),
      .m02_axi_arqos      (m02_arqos),  .m02_axi_arregion(m02_arregion),
      .m02_axi_aruser     (m02_aruser), .m02_axi_arvalid (m02_arvalid),
      .m02_axi_arready    (m02_arready),.m02_axi_rid     (m02_rid),
      .m02_axi_rdata      (m02_rdata),  .m02_axi_rresp   (m02_rresp),
      .m02_axi_rlast      (m02_rlast),  .m02_axi_ruser   (m02_ruser),
      .m02_axi_rvalid     (m02_rvalid), .m02_axi_rready  (m02_rready),
  
      .m03_axi_awid       (m03_awid),   .m03_axi_awaddr  (m03_awaddr),
      .m03_axi_awlen      (m03_awlen),  .m03_axi_awsize  (m03_awsize),
      .m03_axi_awburst    (m03_awburst),.m03_axi_awlock  (m03_awlock),
      .m03_axi_awcache    (m03_awcache),.m03_axi_awprot  (m03_awprot),
      .m03_axi_awqos      (m03_awqos),  .m03_axi_awregion(m03_awregion),
      .m03_axi_awuser     (m03_awuser), .m03_axi_awvalid (m03_awvalid),
      .m03_axi_awready    (m03_awready),.m03_axi_wdata   (m03_wdata),
      .m03_axi_wstrb      (m03_wstrb),  .m03_axi_wlast   (m03_wlast),
      .m03_axi_wuser      (m03_wuser),  .m03_axi_wvalid  (m03_wvalid),
      .m03_axi_wready     (m03_wready), .m03_axi_bid     (m03_bid),
      .m03_axi_bresp      (m03_bresp),  .m03_axi_buser   (m03_buser),
      .m03_axi_bvalid     (m03_bvalid), .m03_axi_bready  (m03_bready),
      .m03_axi_arid       (m03_arid),   .m03_axi_araddr  (m03_araddr),
      .m03_axi_arlen      (m03_arlen),  .m03_axi_arsize  (m03_arsize),
      .m03_axi_arburst    (m03_arburst),.m03_axi_arlock  (m03_arlock),
      .m03_axi_arcache    (m03_arcache),.m03_axi_arprot  (m03_arprot),
      .m03_axi_arqos      (m03_arqos),  .m03_axi_arregion(m03_arregion),
      .m03_axi_aruser     (m03_aruser), .m03_axi_arvalid (m03_arvalid),
      .m03_axi_arready    (m03_arready),.m03_axi_rid     (m03_rid),
      .m03_axi_rdata      (m03_rdata),  .m03_axi_rresp   (m03_rresp),
      .m03_axi_rlast      (m03_rlast),  .m03_axi_ruser   (m03_ruser),
      .m03_axi_rvalid     (m03_rvalid), .m03_axi_rready  (m03_rready),
  
      .m04_axi_awid       (m04_awid),   .m04_axi_awaddr  (m04_awaddr),
      .m04_axi_awlen      (m04_awlen),  .m04_axi_awsize  (m04_awsize),
      .m04_axi_awburst    (m04_awburst),.m04_axi_awlock  (m04_awlock),
      .m04_axi_awcache    (m04_awcache),.m04_axi_awprot  (m04_awprot),
      .m04_axi_awqos      (m04_awqos),  .m04_axi_awregion(m04_awregion),
      .m04_axi_awuser     (m04_awuser), .m04_axi_awvalid (m04_awvalid),
      .m04_axi_awready    (m04_awready),.m04_axi_wdata   (m04_wdata),
      .m04_axi_wstrb      (m04_wstrb),  .m04_axi_wlast   (m04_wlast),
      .m04_axi_wuser      (m04_wuser),  .m04_axi_wvalid  (m04_wvalid),
      .m04_axi_wready     (m04_wready), .m04_axi_bid     (m04_bid),
      .m04_axi_bresp      (m04_bresp),  .m04_axi_buser   (m04_buser),
      .m04_axi_bvalid     (m04_bvalid), .m04_axi_bready  (m04_bready),
      .m04_axi_arid       (m04_arid),   .m04_axi_araddr  (m04_araddr),
      .m04_axi_arlen      (m04_arlen),  .m04_axi_arsize  (m04_arsize),
      .m04_axi_arburst    (m04_arburst),.m04_axi_arlock  (m04_arlock),
      .m04_axi_arcache    (m04_arcache),.m04_axi_arprot  (m04_arprot),
      .m04_axi_arqos      (m04_arqos),  .m04_axi_arregion(m04_arregion),
      .m04_axi_aruser     (m04_aruser), .m04_axi_arvalid (m04_arvalid),
      .m04_axi_arready    (m04_arready),.m04_axi_rid     (m04_rid),
      .m04_axi_rdata      (m04_rdata),  .m04_axi_rresp   (m04_rresp),
      .m04_axi_rlast      (m04_rlast),  .m04_axi_ruser   (m04_ruser),
      .m04_axi_rvalid     (m04_rvalid), .m04_axi_rready  (m04_rready),
  
      .m05_axi_awid       (m05_awid),   .m05_axi_awaddr  (m05_awaddr),
      .m05_axi_awlen      (m05_awlen),  .m05_axi_awsize  (m05_awsize),
      .m05_axi_awburst    (m05_awburst),.m05_axi_awlock  (m05_awlock),
      .m05_axi_awcache    (m05_awcache),.m05_axi_awprot  (m05_awprot),
      .m05_axi_awqos      (m05_awqos),  .m05_axi_awregion(m05_awregion),
      .m05_axi_awuser     (m05_awuser), .m05_axi_awvalid (m05_awvalid),
      .m05_axi_awready    (m05_awready),.m05_axi_wdata   (m05_wdata),
      .m05_axi_wstrb      (m05_wstrb),  .m05_axi_wlast   (m05_wlast),
      .m05_axi_wuser      (m05_wuser),  .m05_axi_wvalid  (m05_wvalid),
      .m05_axi_wready     (m05_wready), .m05_axi_bid     (m05_bid),
      .m05_axi_bresp      (m05_bresp),  .m05_axi_buser   (m05_buser),
      .m05_axi_bvalid     (m05_bvalid), .m05_axi_bready  (m05_bready),
      .m05_axi_arid       (m05_arid),   .m05_axi_araddr  (m05_araddr),
      .m05_axi_arlen      (m05_arlen),  .m05_axi_arsize  (m05_arsize),
      .m05_axi_arburst    (m05_arburst),.m05_axi_arlock  (m05_arlock),
      .m05_axi_arcache    (m05_arcache),.m05_axi_arprot  (m05_arprot),
      .m05_axi_arqos      (m05_arqos),  .m05_axi_arregion(m05_arregion),
      .m05_axi_aruser     (m05_aruser), .m05_axi_arvalid (m05_arvalid),
      .m05_axi_arready    (m05_arready),.m05_axi_rid     (m05_rid),
      .m05_axi_rdata      (m05_rdata),  .m05_axi_rresp   (m05_rresp),
      .m05_axi_rlast      (m05_rlast),  .m05_axi_ruser   (m05_ruser),
      .m05_axi_rvalid     (m05_rvalid), .m05_axi_rready  (m05_rready)
  );
  
  // ---------------------------------------------------------------------------
  // Timeout watchdog
  // ---------------------------------------------------------------------------
  initial begin
      #50000;
      $display("[TIMEOUT] Simulation exceeded 50 us — check DUT/stub handshake.");
      $finish;
  end
  
  // ---------------------------------------------------------------------------
  // Main test sequence
  // ---------------------------------------------------------------------------
  reg [DATA_WIDTH-1:0] rd_data;
  
  task axi_write;
      input [ADDR_WIDTH-1:0] addr;
      input [DATA_WIDTH-1:0] data;
      begin
          // Drive AW and W simultaneously (single-beat)
          @(negedge clk);
          s00_awid    = 8'h01;
          s00_awaddr  = addr;
          s00_awlen   = 8'h00;       // 1 beat
          s00_awsize  = 3'b010;      // 4 bytes
          s00_awburst = 2'b01;       // INCR
          s00_awlock  = 1'b0;
          s00_awcache = 4'b0000;
          s00_awprot  = 3'b000;
          s00_awqos   = 4'b0000;
          s00_awuser  = 0;
          s00_awvalid = 1'b1;
  
          s00_wdata   = data;
          s00_wstrb   = 4'hF;
          s00_wlast   = 1'b1;
          s00_wuser   = 0;
          s00_wvalid  = 1'b1;
  
          s00_bready  = 1'b1;
  
          // Wait for AW handshake
          @(posedge clk);
          while (!s00_awready) @(posedge clk);
          @(negedge clk);
          s00_awvalid = 1'b0;
  
          // Wait for W handshake
          @(posedge clk);
          while (!s00_wready) @(posedge clk);
          @(negedge clk);
          s00_wvalid = 1'b0;
  
          // Wait for B response
          @(posedge clk);
          while (!s00_bvalid) @(posedge clk);
          @(negedge clk);
          s00_bready = 1'b0;
  
          @(posedge clk);
      end
  endtask
  
  task axi_read;
      input  [ADDR_WIDTH-1:0] addr;
      output [DATA_WIDTH-1:0] data;
      begin
          @(negedge clk);
          s00_arid    = 8'h02;
          s00_araddr  = addr;
          s00_arlen   = 8'h00;
          s00_arsize  = 3'b010;
          s00_arburst = 2'b01;
          s00_arlock  = 1'b0;
          s00_arcache = 4'b0000;
          s00_arprot  = 3'b000;
          s00_arqos   = 4'b0000;
          s00_aruser  = 0;
          s00_arvalid = 1'b1;
          s00_rready  = 1'b1;
  
          // Wait for AR handshake
          @(posedge clk);
          while (!s00_arready) @(posedge clk);
          @(negedge clk);
          s00_arvalid = 1'b0;
  
          // Wait for R response
          @(posedge clk);
          while (!s00_rvalid) @(posedge clk);
          data = s00_rdata;
          @(negedge clk);
          s00_rready = 1'b0;
  
          @(posedge clk);
      end
  endtask
  
  initial begin
      // Initialise M0 driver signals
      s00_awid    = 0; s00_awaddr  = 0; s00_awlen   = 0;
      s00_awsize  = 0; s00_awburst = 2'b01; s00_awlock  = 0;
      s00_awcache = 0; s00_awprot  = 0; s00_awqos   = 0;
      s00_awuser  = 0; s00_awvalid = 0;
      s00_wdata   = 0; s00_wstrb   = 0; s00_wlast   = 0;
      s00_wuser   = 0; s00_wvalid  = 0; s00_bready  = 0;
      s00_arid    = 0; s00_araddr  = 0; s00_arlen   = 0;
      s00_arsize  = 0; s00_arburst = 2'b01; s00_arlock  = 0;
      s00_arcache = 0; s00_arprot  = 0; s00_arqos   = 0;
      s00_aruser  = 0; s00_arvalid = 0; s00_rready  = 0;
  
      // ---- Reset ----
      rst = 1'b1;
      repeat(5) @(posedge clk);
      rst = 1'b0;
      repeat(5) @(posedge clk);
  
      // ---- Write 0xDEADBEEF → 0x4000_0000 ----
      axi_write(WR_ADDR, WR_DATA);
  
      // ---- Read back from 0x4000_0000 ----
      axi_read(WR_ADDR, rd_data);
  
      // ---- Verify ----
      if (rd_data === WR_DATA)
          $display("[TEST PASSED] Read data = 0x%08X matched expected 0xDEADBEEF", rd_data);
      else
          $display("[TEST FAILED] Read data = 0x%08X, expected 0xDEADBEEF", rd_data);
  
      $finish;
  end
    


  initial begin
  $fsdbDumpfile("dump.fsdb");
  $fsdbDumpvars("+all");
  $fsdbDumpSVA();
  $fsdbDumpMDA();
  end

  endmodule

