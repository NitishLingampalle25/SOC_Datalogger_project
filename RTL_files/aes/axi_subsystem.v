`timescale 1ns/1ps

module aes_subsystem #(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter ID_WIDTH    = 8,
    parameter LITE_ADDR_W = 6
)(
    input  wire                   aclk,
    input  wire                   aresetn,

    // =========================================================
    // AXI4 Target Port (Connects to Interconnect Master Port)
    // =========================================================
    // Write Address Channel
    input  wire [ID_WIDTH-1:0]    s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire                   s_axi_awlock,
    input  wire [3:0]             s_axi_awcache,
    input  wire [2:0]             s_axi_awprot,
    input  wire [3:0]             s_axi_awqos,
    input  wire [3:0]             s_axi_awregion,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,

    // Write Response Channel
    output wire [ID_WIDTH-1:0]    s_axi_bid,
    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,

    // Read Address Channel
    input  wire [ID_WIDTH-1:0]    s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire                   s_axi_arlock,
    input  wire [3:0]             s_axi_arcache,
    input  wire [2:0]             s_axi_arprot,
    input  wire [3:0]             s_axi_arqos,
    input  wire [3:0]             s_axi_arregion,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,

    // Read Data Channel
    output wire [ID_WIDTH-1:0]    s_axi_rid,
    output wire [DATA_WIDTH-1:0]  s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rlast,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready
);

    // =========================================================
    // Internal Interconnect: AXI4-Lite Wires
    // =========================================================
    wire [LITE_ADDR_W-1:0] axil_awaddr;
    wire                   axil_awvalid;
    wire                   axil_awready;

    wire [DATA_WIDTH-1:0]  axil_wdata;
    wire [DATA_WIDTH/8-1:0] axil_wstrb;
    wire                   axil_wvalid;
    wire                   axil_wready;

    wire [1:0]             axil_bresp;
    wire                   axil_bvalid;
    wire                   axil_bready;

    wire [LITE_ADDR_W-1:0] axil_araddr;
    wire                   axil_arvalid;
    wire                   axil_arready;

    wire [DATA_WIDTH-1:0]  axil_rdata;
    wire [1:0]             axil_rresp;
    wire                   axil_rvalid;
    wire                   axil_rready;

    // =========================================================
    // 1. AXI4 to AXI4-Lite Bridge Instantiation
    // =========================================================
    axi4_to_axilite_bridge #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .ID_WIDTH    (ID_WIDTH),
        .LITE_ADDR_W (LITE_ADDR_W)
    ) u_axi4_to_axilite_bridge (
        .aclk           (aclk),
        .aresetn        (aresetn),

        // AXI4 Interface
        .s_axi_awid     (s_axi_awid),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awlen    (s_axi_awlen),
        .s_axi_awsize   (s_axi_awsize),
        .s_axi_awburst  (s_axi_awburst),
        .s_axi_awlock   (s_axi_awlock),
        .s_axi_awcache  (s_axi_awcache),
        .s_axi_awprot   (s_axi_awprot),
        .s_axi_awqos    (s_axi_awqos),
        .s_axi_awregion (s_axi_awregion),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),

        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),

        .s_axi_bid      (s_axi_bid),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),

        .s_axi_arid     (s_axi_arid),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arlen    (s_axi_arlen),
        .s_axi_arsize   (s_axi_arsize),
        .s_axi_arburst  (s_axi_arburst),
        .s_axi_arlock   (s_axi_arlock),
        .s_axi_arcache  (s_axi_arcache),
        .s_axi_arprot   (s_axi_arprot),
        .s_axi_arqos    (s_axi_arqos),
        .s_axi_arregion (s_axi_arregion),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),

        .s_axi_rid      (s_axi_rid),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rlast    (s_axi_rlast),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),

        // AXI4-Lite Internal Master Interface
        .m_axil_awaddr  (axil_awaddr),
        .m_axil_awvalid (axil_awvalid),
        .m_axil_awready (axil_awready),

        .m_axil_wdata   (axil_wdata),
        .m_axil_wstrb   (axil_wstrb),
        .m_axil_wvalid  (axil_wvalid),
        .m_axil_wready  (axil_wready),

        .m_axil_bresp   (axil_bresp),
        .m_axil_bvalid  (axil_bvalid),
        .m_axil_bready  (axil_bready),

        .m_axil_araddr  (axil_araddr),
        .m_axil_arvalid (axil_arvalid),
        .m_axil_arready (axil_arready),

        .m_axil_rdata   (axil_rdata),
        .m_axil_rresp   (axil_rresp),
        .m_axil_rvalid  (axil_rvalid),
        .m_axil_rready  (axil_rready)
    );

    // =========================================================
    // 2. AES AXI4-Lite Slave Instantiation
    // =========================================================
    aes_axi_slave #(
        .ADDR_WIDTH (LITE_ADDR_W),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_aes_axi_slave (
        .aclk    (aclk),
        .aresetn (aresetn),

        // Write Address Channel
        .awaddr  (axil_awaddr),
        .awvalid (axil_awvalid),
        .awready (axil_awready),

        // Write Data Channel
        .wdata   (axil_wdata),
        .wstrb   (axil_wstrb),
        .wvalid  (axil_wvalid),
        .wready  (axil_wready),

        // Write Response Channel
        .bresp   (axil_bresp),
        .bvalid  (axil_bvalid),
        .bready  (axil_bready),

        // Read Address Channel
        .araddr  (axil_araddr),
        .arvalid (axil_arvalid),
        .arready (axil_arready),

        // Read Data Channel
        .rdata   (axil_rdata),
        .rresp   (axil_rresp),
        .rvalid  (axil_rvalid),
        .rready  (axil_rready)
    );

endmodule
