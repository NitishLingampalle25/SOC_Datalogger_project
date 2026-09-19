// =============================================================================
// axi4_to_axilite_bridge.v
// Bridges one AXI4 master port (from axi_interconnect_wrap_2x6, ID_WIDTH=8)
// to one AXI4-Lite slave port (aes_axi_slave, ADDR_WIDTH=6, DATA_WIDTH=32).
//
// Supports single-beat transfers only (len=0). Burst beats are dropped after
// the first — sufficient for register-mapped peripherals.
// =============================================================================
`timescale 1ns/1ps
`default_nettype none

module axi4_to_axilite_bridge #(
    parameter ADDR_WIDTH  = 32,  // AXI4 full address width
    parameter DATA_WIDTH  = 32,
    parameter ID_WIDTH    = 8,
    parameter LITE_ADDR_W = 6    // aes_axi_slave ADDR_WIDTH
)(
    input  wire                   aclk,
    input  wire                   aresetn,

    // =========================================================
    // AXI4 Slave port  (connects to interconnect master mXX_*)
    // =========================================================
    // AW
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
    // W
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,
    // B
    output wire [ID_WIDTH-1:0]    s_axi_bid,
    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,
    // AR
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
    // R
    output wire [ID_WIDTH-1:0]    s_axi_rid,
    output wire [DATA_WIDTH-1:0]  s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rlast,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready,

    // =========================================================
    // AXI4-Lite Master port  (connects to aes_axi_slave)
    // =========================================================
    // AW
    output reg  [LITE_ADDR_W-1:0] m_axil_awaddr,
    output reg                    m_axil_awvalid,
    input  wire                   m_axil_awready,
    // W
    output reg  [DATA_WIDTH-1:0]  m_axil_wdata,
    output reg  [DATA_WIDTH/8-1:0] m_axil_wstrb,
    output reg                    m_axil_wvalid,
    input  wire                   m_axil_wready,
    // B
    input  wire [1:0]             m_axil_bresp,
    input  wire                   m_axil_bvalid,
    output reg                    m_axil_bready,
    // AR
    output reg  [LITE_ADDR_W-1:0] m_axil_araddr,
    output reg                    m_axil_arvalid,
    input  wire                   m_axil_arready,
    // R
    input  wire [DATA_WIDTH-1:0]  m_axil_rdata,
    input  wire [1:0]             m_axil_rresp,
    input  wire                   m_axil_rvalid,
    output reg                    m_axil_rready
);

    // =========================================================
    // Write path state machine
    // =========================================================
    localparam WR_IDLE    = 2'd0,
               WR_ADDR    = 2'd1,   // AW+W issued to lite slave
               WR_RESP    = 2'd2;   // waiting for B

    reg [1:0]          wr_state;
    reg [ID_WIDTH-1:0] wr_id;
    reg [1:0]          wr_bresp;

    // Accept AW from AXI4 master immediately when idle
    assign s_axi_awready = (wr_state == WR_IDLE);
    assign s_axi_wready  = (wr_state == WR_IDLE);   // accept W same cycle as AW

    // B response back to AXI4 master
    assign s_axi_bid    = wr_id;
    assign s_axi_bresp  = wr_bresp;
    assign s_axi_bvalid = (wr_state == WR_RESP) && m_axil_bvalid;

    always @(posedge aclk) begin
        if (!aresetn) begin
            wr_state       <= WR_IDLE;
            wr_id          <= 0;
            wr_bresp       <= 2'b00;
            m_axil_awvalid <= 1'b0;
            m_axil_wvalid  <= 1'b0;
            m_axil_bready  <= 1'b0;
            m_axil_awaddr  <= 0;
            m_axil_wdata   <= 0;
            m_axil_wstrb   <= 0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    // Latch AW and W together (AXI4-Lite requires simultaneous issue)
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        wr_id          <= s_axi_awid;
                        m_axil_awaddr  <= s_axi_awaddr[LITE_ADDR_W-1:0];
                        m_axil_awvalid <= 1'b1;
                        m_axil_wdata   <= s_axi_wdata;
                        m_axil_wstrb   <= s_axi_wstrb;
                        m_axil_wvalid  <= 1'b1;
                        m_axil_bready  <= 1'b1;
                        wr_state       <= WR_ADDR;
                    end
                end

                WR_ADDR: begin
                    // Clear awvalid once slave accepts address
                    if (m_axil_awready && m_axil_awvalid)
                        m_axil_awvalid <= 1'b0;
                    // Clear wvalid once slave accepts data
                    if (m_axil_wready && m_axil_wvalid)
                        m_axil_wvalid <= 1'b0;
                    // Move to response phase once both accepted
                    if (!m_axil_awvalid && !m_axil_wvalid)
                        wr_state <= WR_RESP;
                end

                WR_RESP: begin
                    if (m_axil_bvalid && m_axil_bready) begin
                        wr_bresp      <= m_axil_bresp;
                        m_axil_bready <= 1'b0;
                        // Wait for AXI4 master to accept B
                        if (s_axi_bready)
                            wr_state <= WR_IDLE;
                        else
                            wr_state <= WR_RESP; // hold bvalid (driven combinatorially)
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // =========================================================
    // Read path state machine
    // =========================================================
    localparam RD_IDLE = 2'd0,
               RD_ADDR = 2'd1,   // AR issued to lite slave
               RD_DATA = 2'd2;   // waiting for R

    reg [1:0]            rd_state;
    reg [ID_WIDTH-1:0]   rd_id;
    reg [DATA_WIDTH-1:0] rd_data_r;
    reg [1:0]            rd_rresp_r;

    // Declared before being referenced in s_axi_rvalid assign statement
    reg                  rd_data_ready;

    assign s_axi_arready = (rd_state == RD_IDLE);

    assign s_axi_rid   = rd_id;
    assign s_axi_rdata = rd_data_r;
    assign s_axi_rresp = rd_rresp_r;
    assign s_axi_rlast = 1'b1;   // always single beat
    assign s_axi_rvalid = (rd_state == RD_DATA) && !m_axil_rvalid
                          ? 1'b0   // data not yet captured
                          : (rd_state == RD_DATA) && rd_data_ready;

    always @(posedge aclk) begin
        if (!aresetn) begin
            rd_state       <= RD_IDLE;
            rd_id          <= 0;
            rd_data_r      <= 0;
            rd_rresp_r     <= 2'b00;
            rd_data_ready  <= 1'b0;
            m_axil_arvalid <= 1'b0;
            m_axil_araddr  <= 0;
            m_axil_rready  <= 1'b0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    rd_data_ready <= 1'b0;
                    if (s_axi_arvalid) begin
                        rd_id          <= s_axi_arid;
                        m_axil_araddr  <= s_axi_araddr[LITE_ADDR_W-1:0];
                        m_axil_arvalid <= 1'b1;
                        m_axil_rready  <= 1'b1;
                        rd_state       <= RD_ADDR;
                    end
                end

                RD_ADDR: begin
                    if (m_axil_arready && m_axil_arvalid) begin
                        m_axil_arvalid <= 1'b0;
                        rd_state       <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    if (m_axil_rvalid && m_axil_rready) begin
                        rd_data_r     <= m_axil_rdata;
                        rd_rresp_r    <= m_axil_rresp;
                        rd_data_ready <= 1'b1;
                        m_axil_rready <= 1'b0;
                    end
                    // Wait for AXI4 master to accept R
                    if (rd_data_ready && s_axi_rready)
                        rd_state <= RD_IDLE;
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
`default_nettype wire
