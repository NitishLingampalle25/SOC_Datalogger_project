// =============================================================================
// Module  : ef_wdt32_axi_wrapper
// File    : RTL_files/WDT/ef_wdt32_axi_wrapper.v
//
// Purpose : AXI4 Slave Wrapper for EF_WDT32 32-bit Watchdog Timer.
//           Remaps registers to compact offsets within a 4 KB window:
//             0x00 : WDT_TIMER   (RO)  - Current down-counter value (WDTMR)
//             0x04 : WDT_LOAD    (RW)  - Initial / reload value (WDTLOAD)
//             0x08 : WDT_CTRL    (RW)  - Control register:
//                                        [0] WDTEN (1=enable, 0=disabled/reload)
//                                        [1] AUTO_KICK_EN (1=kick on aes_done_pulse_i)
//                                        [2] NMI_MODE_EN (1=escalate to NMI on timeout)
//                                        [3] HARD_RESET_EN (1=escalate to RESET on timeout)
//             0x0C : WDT_PING    (WO)  - Software ping/kick register (pet the dog)
//             0x10 : WDT_IM      (RW)  - Interrupt mask (1=enable IRQ)
//             0x14 : WDT_RIS     (RO)  - Raw interrupt status (timeout event occurred)
//             0x18 : WDT_MIS     (RO)  - Masked interrupt status (RIS & IM)
//             0x1C : WDT_IC      (WO)  - Interrupt clear (write 1 to clear RIS)
//             0x20 : WDT_GCLK    (RW)  - Clock enable register (default 1)
//
// Hardware Handshaking:
//   - aes_done_pulse_i: 1-cycle hardware pulse from AES-128 engine upon completion.
//     When AUTO_KICK_EN is 1, this reloads WDTMR <= WDTLOAD autonomously.
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module ef_wdt32_axi_wrapper #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 8,
    parameter STRB_WIDTH = DATA_WIDTH / 8
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // AXI4 Slave Interface (connects to interconnect m04 @ 0x4000_4000)
    input  wire [ID_WIDTH-1:0]          s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  wire [7:0]                   s_axi_awlen,
    input  wire [2:0]                   s_axi_awsize,
    input  wire [1:0]                   s_axi_awburst,
    input  wire                         s_axi_awlock,
    input  wire [3:0]                   s_axi_awcache,
    input  wire [2:0]                   s_axi_awprot,
    input  wire [3:0]                   s_axi_awqos,
    input  wire [3:0]                   s_axi_awregion,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,

    input  wire [DATA_WIDTH-1:0]        s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]        s_axi_wstrb,
    input  wire                         s_axi_wlast,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,

    output wire [ID_WIDTH-1:0]          s_axi_bid,
    output wire [1:0]                   s_axi_bresp,
    output wire                         s_axi_bvalid,
    input  wire                         s_axi_bready,

    input  wire [ID_WIDTH-1:0]          s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]        s_axi_araddr,
    input  wire [7:0]                   s_axi_arlen,
    input  wire [2:0]                   s_axi_arsize,
    input  wire [1:0]                   s_axi_arburst,
    input  wire                         s_axi_arlock,
    input  wire [3:0]                   s_axi_arcache,
    input  wire [2:0]                   s_axi_arprot,
    input  wire [3:0]                   s_axi_arqos,
    input  wire [3:0]                   s_axi_arregion,
    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,

    output wire [ID_WIDTH-1:0]          s_axi_rid,
    output wire [DATA_WIDTH-1:0]        s_axi_rdata,
    output wire [1:0]                   s_axi_rresp,
    output wire                         s_axi_rlast,
    output wire                         s_axi_rvalid,
    input  wire                         s_axi_rready,

    // Hardware Kick & Escalation Signals
    input  wire                         aes_done_pulse_i, // Auto-kick pulse from AES
    output wire                         wdt_irq_o,        // Early warning maskable IRQ
    output wire                         wdt_nmi_o,        // Emergency hardware NMI
    output wire                         wdt_reset_o,      // Emergency hard reset
    output wire                         wdt_timeout_o     // Raw timeout flag
);

    // =========================================================================
    // Registers
    // =========================================================================
    reg [31:0] load_REG;
    reg [3:0]  control_REG;
    reg        IM_REG;
    reg        RIS_REG;
    reg        GCLK_REG;
    reg        sw_kick_pulse;

    wire [31:0] WDTMR;
    wire [31:0] WDTLOAD = load_REG;
    wire        WDTTO;

    // Auto-kick from AES when enabled + software kick pulse
    wire wdt_hw_kick = control_REG[1] & aes_done_pulse_i;
    wire wdt_kick    = sw_kick_pulse | wdt_hw_kick;
    // When kick is active, pulse WDTEN low for 1 cycle so EF_WDT32 reloads WDTLOAD
    wire WDTEN       = control_REG[0] & ~wdt_kick;

    // =========================================================================
    // EF_WDT32 Core Instantiation
    // =========================================================================
    EF_WDT32 instance_to_wrap (
        .clk     (clk),
        .rst_n   (rst_n),
        .WDTMR   (WDTMR),
        .WDTLOAD (WDTLOAD),
        .WDTTO   (WDTTO),
        .WDTEN   (WDTEN)
    );

    // =========================================================================
    // Interrupt & Fault Escalation Logic
    // =========================================================================
    wire MIS_REG = RIS_REG & IM_REG;
    reg  reg_ic_pulse;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            RIS_REG <= 1'b0;
        end else begin
            if (reg_ic_pulse)
                RIS_REG <= 1'b0;
            else if (WDTTO)
                RIS_REG <= 1'b1;
        end
    end

    assign wdt_irq_o     = MIS_REG;
    assign wdt_timeout_o = WDTTO;
    assign wdt_nmi_o     = WDTTO & control_REG[2];
    assign wdt_reset_o   = WDTTO & control_REG[3];

    // =========================================================================
    // AXI4 Write State Machine
    // =========================================================================
    localparam WR_IDLE = 2'd0;
    localparam WR_DATA = 2'd1;
    localparam WR_RESP = 2'd2;

    reg [1:0]          wr_state;
    reg [ID_WIDTH-1:0] wr_id_r;
    reg [5:0]          wr_addr_r;

    assign s_axi_awready = (wr_state == WR_IDLE);
    assign s_axi_wready  = (wr_state == WR_DATA) || (wr_state == WR_IDLE && s_axi_awvalid);
    assign s_axi_bid     = wr_id_r;
    assign s_axi_bresp   = 2'b00; // OKAY
    assign s_axi_bvalid  = (wr_state == WR_RESP);

    wire write_en = (wr_state == WR_IDLE && s_axi_awvalid && s_axi_wvalid) ||
                    (wr_state == WR_DATA && s_axi_wvalid);
    wire [5:0] target_wr_addr = (wr_state == WR_IDLE) ? s_axi_awaddr[5:0] : wr_addr_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state      <= WR_IDLE;
            wr_id_r       <= {ID_WIDTH{1'b0}};
            wr_addr_r     <= 6'b0;
            load_REG      <= 32'h0;
            control_REG   <= 4'h0;
            IM_REG        <= 1'b0;
            GCLK_REG      <= 1'b1;
            sw_kick_pulse <= 1'b0;
            reg_ic_pulse  <= 1'b0;
        end else begin
            sw_kick_pulse <= 1'b0;
            reg_ic_pulse  <= 1'b0;

            case (wr_state)
                WR_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        wr_id_r  <= s_axi_awid;
                        wr_state <= WR_RESP;
                    end else if (s_axi_awvalid) begin
                        wr_id_r   <= s_axi_awid;
                        wr_addr_r <= s_axi_awaddr[5:0];
                        wr_state  <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (s_axi_wvalid) begin
                        wr_state <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    if (s_axi_bready) begin
                        wr_state <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase

            if (write_en) begin
                case (target_wr_addr)
                    6'h04: load_REG      <= s_axi_wdata;
                    6'h08: control_REG   <= s_axi_wdata[3:0];
                    6'h0C: sw_kick_pulse <= 1'b1; // WDT_PING
                    6'h10: IM_REG        <= s_axi_wdata[0];
                    6'h1C: reg_ic_pulse  <= s_axi_wdata[0]; // WDT_IC
                    6'h20: GCLK_REG      <= s_axi_wdata[0];
                    default: ;
                endcase
            end
        end
    end

    // =========================================================================
    // AXI4 Read State Machine & Multiplexer
    // =========================================================================
    localparam RD_IDLE = 1'b0;
    localparam RD_DATA = 1'b1;

    reg                  rd_state;
    reg [ID_WIDTH-1:0]   rd_id_r;
    reg [DATA_WIDTH-1:0] rd_data_r;

    assign s_axi_arready = (rd_state == RD_IDLE);
    assign s_axi_rid     = rd_id_r;
    assign s_axi_rdata   = rd_data_r;
    assign s_axi_rresp   = 2'b00; // OKAY
    assign s_axi_rlast   = 1'b1;
    assign s_axi_rvalid  = (rd_state == RD_DATA);

    reg [31:0] rd_data_mux;
    always @(*) begin
        case (s_axi_araddr[5:0])
            6'h00: rd_data_mux = WDTMR;
            6'h04: rd_data_mux = load_REG;
            6'h08: rd_data_mux = {28'b0, control_REG};
            6'h0C: rd_data_mux = 32'h0;
            6'h10: rd_data_mux = {31'b0, IM_REG};
            6'h14: rd_data_mux = {31'b0, RIS_REG};
            6'h18: rd_data_mux = {31'b0, MIS_REG};
            6'h1C: rd_data_mux = 32'h0;
            6'h20: rd_data_mux = {31'b0, GCLK_REG};
            default: rd_data_mux = 32'hDEAD_BEEF;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state  <= RD_IDLE;
            rd_id_r   <= {ID_WIDTH{1'b0}};
            rd_data_r <= 32'h0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (s_axi_arvalid) begin
                        rd_id_r   <= s_axi_arid;
                        rd_data_r <= rd_data_mux;
                        rd_state  <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    if (s_axi_rready) begin
                        rd_state <= RD_IDLE;
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
