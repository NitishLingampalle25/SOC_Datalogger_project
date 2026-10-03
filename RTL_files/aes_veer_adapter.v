// =============================================================================
// Module  : aes_veer_adapter
// File    : RTL_files/aes_veer_adapter.v
//
// Purpose : 32-bit to 128-bit AXI4 Slave Adapter for AES-128 Encryption &
//           Decryption Engine in the VeeR2 TCAS SoC.
//
// Features:
//   1. Bus Adaptation:
//      - Connects to 32-bit AXI4 Interconnect Master Port (m02 at 0x4000_2000).
//      - Adapts single-beat 32-bit CPU transactions to 128-bit AES registers.
//   2. Register Mapping:
//      - 0x00: AES_CTRL_STAT (Control & Status Register)
//              [0]  START      - Pulse to load text & trigger encryption/decryption
//              [1]  KEY_LD     - Pulse to trigger key expansion for decryption
//              [2]  MODE / DIR - 0 = Encrypt, 1 = Decrypt
//              [3]  IRQ_EN     - Interrupt enable (1 = enabled)
//              [7]  KDONE      - Key expansion done (read-only)
//              [8]  DONE       - Operation complete flag (read; write 1 to clear)
//              [16] IDLE       - Core is idle (read-only)
//              [17] PROCESSING - Core is busy processing (read-only)
//      - 0x04: AES_KEY_0       - Key bits [127:96] (Word 0 / MSW)
//      - 0x08: AES_KEY_1       - Key bits [95:64]  (Word 1)
//      - 0x0C: AES_KEY_2       - Key bits [63:32]  (Word 2)
//      - 0x10: AES_KEY_3       - Key bits [31:0]   (Word 3 / LSW)
//      - 0x14: AES_TEXT_IN_0   - Input text bits [127:96] (Word 0 / MSW)
//      - 0x18: AES_TEXT_IN_1   - Input text bits [95:64]  (Word 1)
//      - 0x1C: AES_TEXT_IN_2   - Input text bits [63:32]  (Word 2)
//      - 0x20: AES_TEXT_IN_3   - Input text bits [31:0]   (Word 3 / LSW)
//      - 0x24: AES_TEXT_OUT_0  - Output text bits [127:96] (Word 0 / MSW)
//      - 0x28: AES_TEXT_OUT_1  - Output text bits [95:64]  (Word 1)
//      - 0x2C: AES_TEXT_OUT_2  - Output text bits [63:32]  (Word 2)
//      - 0x30: AES_TEXT_OUT_3  - Output text bits [31:0]   (Word 3 / LSW)
//   3. Hardware Handshaking (TCAS Spec Doc Compliant):
//      - aes_done_pulse_o: 1-cycle hardware pulse upon encryption completion,
//        routed directly to Watchdog Timer HW kick to prevent counter expiration.
//      - irq_aes_done_o: Maskable interrupt routed to the VeeR PIC.
//   4. Direct AES Core Instantiation:
//      - Directly instantiates aes_cipher_top (forward encryption) and
//        aes_inv_cipher_top (inverse decryption).
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module aes_veer_adapter #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 8,
    parameter STRB_WIDTH = DATA_WIDTH / 8
)(
    input  wire                         clk,
    input  wire                         rst_n,      // Active-low system reset

    // =========================================================================
    // AXI4 Slave Interface (connects to Interconnect Master Port m02)
    // =========================================================================
    // Write Address Channel
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

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]        s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]        s_axi_wstrb,
    input  wire                         s_axi_wlast,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,

    // Write Response Channel
    output wire [ID_WIDTH-1:0]          s_axi_bid,
    output wire [1:0]                   s_axi_bresp,
    output wire                         s_axi_bvalid,
    input  wire                         s_axi_bready,

    // Read Address Channel
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

    // Read Data Channel
    output wire [ID_WIDTH-1:0]          s_axi_rid,
    output wire [DATA_WIDTH-1:0]        s_axi_rdata,
    output wire [1:0]                   s_axi_rresp,
    output wire                         s_axi_rlast,
    output wire                         s_axi_rvalid,
    input  wire                         s_axi_rready,

    // =========================================================================
    // 128-bit AES Interface Probes / Observation Signals
    // =========================================================================
    output wire [127:0]                 aes_key_128_o,
    output wire [127:0]                 aes_text_in_128_o,
    output wire [127:0]                 aes_text_out_128_o,
    output wire                         aes_core_start_o,
    output wire                         aes_core_mode_o,
    output wire                         aes_core_done_o,
    output wire                         aes_core_busy_o,

    // =========================================================================
    // SoC Interrupt & Handshaking Signals (TCAS Spec Compliant)
    // =========================================================================
    output wire                         aes_done_pulse_o,  // Direct kick to Watchdog Timer
    output wire                         irq_aes_done_o     // Interrupt to PIC
);

    // =========================================================================
    // Internal Registers for 32-to-128 bit Adaptation
    // =========================================================================
    reg [127:0] reg_key;
    reg [127:0] reg_text_in;
    reg [127:0] reg_text_out;
    reg         reg_mode;       // 0: Encrypt, 1: Decrypt
    reg         reg_start_ld;   // Pulse to load text & start cipher
    reg         reg_key_ld;     // Pulse to expand key for decryption
    reg         reg_irq_en;     // Interrupt enable

    reg         aes_busy;
    reg         done_latched;
    reg         done_r;
    reg         irq_latched;

    reg [3:0]   kdone_cnt;
    reg         kdone_r;

    // Signals from 128-bit AES Cores
    wire [127:0] cipher_text_out;
    wire [127:0] inv_cipher_text_out;
    wire         cipher_done;
    wire         inv_cipher_done;

    wire [127:0] core_text_out = reg_mode ? inv_cipher_text_out : cipher_text_out;
    wire         core_done     = reg_mode ? inv_cipher_done     : cipher_done;

    // Probe assignments
    assign aes_key_128_o      = reg_key;
    assign aes_text_in_128_o  = reg_text_in;
    assign aes_text_out_128_o = reg_text_out;
    assign aes_core_start_o   = reg_start_ld;
    assign aes_core_mode_o    = reg_mode;
    assign aes_core_done_o    = core_done;
    assign aes_core_busy_o    = aes_busy;

    // Pulse & IRQ outputs
    // 1-cycle hardware pulse when core_done rises
    assign aes_done_pulse_o   = core_done & ~done_r;
    assign irq_aes_done_o     = irq_latched & reg_irq_en;

    // =========================================================================
    // AXI4 Write Handshake State Machine
    // =========================================================================
    localparam WR_IDLE = 2'd0;
    localparam WR_DATA = 2'd1;
    localparam WR_RESP = 2'd2;

    reg [1:0]          wr_state;
    reg [ID_WIDTH-1:0] wr_id_r;
    reg [5:0]          wr_addr_r;

    assign s_axi_awready = (wr_state == WR_IDLE);
    assign s_axi_wready  = (wr_state == WR_IDLE) ? s_axi_awvalid : (wr_state == WR_DATA);

    assign s_axi_bid     = wr_id_r;
    assign s_axi_bresp   = 2'b00; // OKAY
    assign s_axi_bvalid  = (wr_state == WR_RESP);

    wire write_en = (wr_state == WR_IDLE && s_axi_awvalid && s_axi_wvalid) ||
                    (wr_state == WR_DATA && s_axi_wvalid);

    wire [5:0] target_wr_addr = (wr_state == WR_IDLE) ? s_axi_awaddr[5:0] : wr_addr_r;

    function [31:0] apply_wstrb;
        input [31:0] old_val;
        input [31:0] new_val;
        input [3:0]  strb;
        begin
            apply_wstrb[ 7: 0] = strb[0] ? new_val[ 7: 0] : old_val[ 7: 0];
            apply_wstrb[15: 8] = strb[1] ? new_val[15: 8] : old_val[15: 8];
            apply_wstrb[23:16] = strb[2] ? new_val[23:16] : old_val[23:16];
            apply_wstrb[31:24] = strb[3] ? new_val[31:24] : old_val[31:24];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state  <= WR_IDLE;
            wr_id_r   <= {ID_WIDTH{1'b0}};
            wr_addr_r <= 6'b0;
        end else begin
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
        end
    end

    // =========================================================================
    // Write Data Decoding into 128-bit Registers
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_key      <= 128'h0;
            reg_text_in  <= 128'h0;
            reg_mode     <= 1'b0;
            reg_start_ld <= 1'b0;
            reg_key_ld   <= 1'b0;
            reg_irq_en   <= 1'b1;
        end else begin
            reg_start_ld <= 1'b0;
            reg_key_ld   <= 1'b0;

            if (write_en) begin
                case (target_wr_addr)
                    6'h00: begin
                        reg_start_ld <= s_axi_wdata[0];
                        reg_key_ld   <= s_axi_wdata[1];
                        reg_mode     <= s_axi_wdata[2];
                        if (s_axi_wstrb[0]) reg_irq_en <= s_axi_wdata[3];
                    end

                    // 128-bit Key: 4 x 32-bit registers (0x04, 0x08, 0x0C, 0x10)
                    6'h04: reg_key[127:96] <= apply_wstrb(reg_key[127:96], s_axi_wdata, s_axi_wstrb);
                    6'h08: reg_key[95:64]  <= apply_wstrb(reg_key[95:64],  s_axi_wdata, s_axi_wstrb);
                    6'h0C: reg_key[63:32]  <= apply_wstrb(reg_key[63:32],  s_axi_wdata, s_axi_wstrb);
                    6'h10: reg_key[31:0]   <= apply_wstrb(reg_key[31:0],   s_axi_wdata, s_axi_wstrb);

                    // 128-bit Text In: 4 x 32-bit registers (0x14, 0x18, 0x1C, 0x20)
                    6'h14: reg_text_in[127:96] <= apply_wstrb(reg_text_in[127:96], s_axi_wdata, s_axi_wstrb);
                    6'h18: reg_text_in[95:64]  <= apply_wstrb(reg_text_in[95:64],  s_axi_wdata, s_axi_wstrb);
                    6'h1C: reg_text_in[63:32]  <= apply_wstrb(reg_text_in[63:32],  s_axi_wdata, s_axi_wstrb);
                    6'h20: reg_text_in[31:0]   <= apply_wstrb(reg_text_in[31:0],   s_axi_wdata, s_axi_wstrb);

                    default: ;
                endcase
            end
        end
    end

    // =========================================================================
    // Status, Busy, Done Latch, and Key-Done Tracking
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aes_busy     <= 1'b0;
            done_latched <= 1'b0;
            done_r       <= 1'b0;
            irq_latched  <= 1'b0;
            reg_text_out <= 128'h0;
            kdone_cnt    <= 4'd0;
            kdone_r      <= 1'b0;
        end else begin
            done_r <= core_done;
            if (core_done) begin
                reg_text_out <= core_text_out;
            end

            // Busy and Done flags
            if (reg_start_ld) begin
                aes_busy     <= 1'b1;
                done_latched <= 1'b0;
                irq_latched  <= 1'b0;
            end else if (core_done) begin
                aes_busy     <= 1'b0;
                done_latched <= 1'b1;
                irq_latched  <= 1'b1;
            end else if (write_en && target_wr_addr == 6'h00 && s_axi_wdata[8]) begin
                // W1C clear done
                done_latched <= 1'b0;
                irq_latched  <= 1'b0;
            end

            // Key-expansion done counter for decryption (11 cycles)
            if (reg_key_ld && reg_mode) begin
                kdone_cnt <= 4'd11;
                kdone_r   <= 1'b0;
            end else if (kdone_cnt > 4'd1) begin
                kdone_cnt <= kdone_cnt - 4'd1;
                kdone_r   <= 1'b0;
            end else if (kdone_cnt == 4'd1) begin
                kdone_cnt <= 4'd0;
                kdone_r   <= 1'b1;
            end else begin
                kdone_r   <= 1'b0;
            end
        end
    end

    // =========================================================================
    // AXI4 Read Handshake State Machine & Read Multiplexer
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
            6'h00: rd_data_mux = {14'b0, aes_busy, ~aes_busy, 6'b0, kdone_r, done_latched, 4'b0, reg_irq_en, reg_mode, reg_key_ld, reg_start_ld};
            6'h04: rd_data_mux = reg_key[127:96];
            6'h08: rd_data_mux = reg_key[95:64];
            6'h0C: rd_data_mux = reg_key[63:32];
            6'h10: rd_data_mux = reg_key[31:0];
            6'h14: rd_data_mux = reg_text_in[127:96];
            6'h18: rd_data_mux = reg_text_in[95:64];
            6'h1C: rd_data_mux = reg_text_in[63:32];
            6'h20: rd_data_mux = reg_text_in[31:0];
            // 128-bit Text Out (Ciphertext / Plaintext): read across 4 words
            6'h24: rd_data_mux = reg_text_out[127:96];
            6'h28: rd_data_mux = reg_text_out[95:64];
            6'h2C: rd_data_mux = reg_text_out[63:32];
            6'h30: rd_data_mux = reg_text_out[31:0];
            default: rd_data_mux = 32'h0;
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

    // =========================================================================
    // 128-bit AES Cryptographic Core Instantiations
    // =========================================================================
    // Forward Cipher Core (Encryption)
    aes_cipher_top u_aes_cipher (
        .clk      (clk),
        .rst      (rst_n),    // active-low reset
        .ld       (reg_start_ld & ~reg_mode),
        .done     (cipher_done),
        .key      (reg_key),
        .text_in  (reg_text_in),
        .text_out (cipher_text_out)
    );

    // Inverse Cipher Core (Decryption)
    aes_inv_cipher_top u_aes_inv_cipher (
        .clk      (clk),
        .rst      (rst_n),    // active-low reset
        .kld      (reg_key_ld & reg_mode),
        .ld       (reg_start_ld & reg_mode),
        .done     (inv_cipher_done),
        .key      (reg_key),
        .text_in  (reg_text_in),
        .text_out (inv_cipher_text_out)
    );

endmodule

`default_nettype wire
