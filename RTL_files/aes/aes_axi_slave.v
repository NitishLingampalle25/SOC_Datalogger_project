`timescale 1ns / 1ps

module aes_axi_slave #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32
)(
    // AXI4-Lite Signals
    input  wire                  aclk,
    input  wire                  aresetn,

    // Write Address Channel
    input  wire [ADDR_WIDTH-1:0] awaddr,
    input  wire                  awvalid,
    output reg                   awready,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire [(DATA_WIDTH/8)-1:0] wstrb,
    input  wire                  wvalid,
    output reg                   wready,

    // Write Response Channel
    output reg  [1:0]            bresp,
    output reg                   bvalid,
    input  wire                  bready,

    // Read Address Channel
    input  wire [ADDR_WIDTH-1:0] araddr,
    input  wire                  arvalid,
    output reg                   arready,

    // Read Data Channel
    output reg  [DATA_WIDTH-1:0] rdata,
    output reg  [1:0]            rresp,
    output reg                   rvalid,
    input  wire                  rready
);

    // Active-High Reset for internal AES cores
    wire rst = ~aresetn;

    // Internal Registers
    reg [127:0] reg_key;
    reg [127:0] reg_text_in;
    reg         reg_mode;     // 0: Encrypt, 1: Decrypt
    reg         reg_start_ld; // Pulse for text load
    reg         reg_key_ld;   // Pulse for key load (Decryption)

    // Signals from AES Cores
    wire [127:0] cipher_text_out;
    wire [127:0] inv_cipher_text_out;
    wire         cipher_done;
    wire         inv_cipher_done;
    wire         inv_cipher_kdone;

    // Multiplexed Core Outputs based on reg_mode
    wire [127:0] text_out = reg_mode ? inv_cipher_text_out : cipher_text_out;
    wire         done     = reg_mode ? inv_cipher_done     : cipher_done;

    // Control Register value
    wire [DATA_WIDTH-1:0] ctrl_stat_reg = {22'b0, inv_cipher_kdone, done, 5'b0, reg_mode, reg_key_ld, reg_start_ld};

    // ------------------------------------------------------------------------
    // AXI4-Lite Write Handshake Logic
    // ------------------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] axi_awaddr;

    always @(posedge aclk) begin
        if (!aresetn) begin
            awready <= 1'b0;
            wready  <= 1'b0;
            bvalid  <= 1'b0;
            bresp   <= 2'b00; // OKAY response
            
            reg_key      <= 128'b0;
            reg_text_in  <= 128'b0;
            reg_mode     <= 1'b0;
            reg_start_ld <= 1'b0;
            reg_key_ld   <= 1'b0;
        end else begin
            // Pulse auto-clear logic
            reg_start_ld <= 1'b0;
            reg_key_ld   <= 1'b0;

            // AW & W Ready Logic
            if (~awready && awvalid && wvalid) begin
                awready    <= 1'b1; // Set ready to accept address/data
                wready     <= 1'b1;
                axi_awaddr <= awaddr;
            end else begin
                awready    <= 1'b0;
                wready     <= 1'b0;
            end

            // Write Execution
            if (awready && wready && awvalid && wvalid) begin
                bvalid <= 1'b1;
                case (axi_awaddr[5:0])
                    6'h00: begin
                        reg_start_ld <= wdata[0];
                        reg_key_ld   <= wdata[1];
                        reg_mode     <= wdata[2];
                    end
                    6'h04: reg_key[31:0]     <= wdata;
                    6'h08: reg_key[63:32]    <= wdata;
                    6'h0C: reg_key[95:64]    <= wdata;
                    6'h10: reg_key[127:96]   <= wdata;
                    6'h14: reg_text_in[31:0]   <= wdata;
                    6'h18: reg_text_in[63:32]  <= wdata;
                    6'h1C: reg_text_in[95:64]  <= wdata;
                    6'h20: reg_text_in[127:96] <= wdata;
                    default: ; // Write to read-only or unused addresses ignored
                endcase
            end

            if (bvalid && bready) begin
                bvalid <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // AXI4-Lite Read Handshake Logic
    // ------------------------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            arready <= 1'b0;
            rvalid  <= 1'b0;
            rresp   <= 2'b00;
            rdata   <= {DATA_WIDTH{1'b0}};
        end else begin
            if (~arready && arvalid) begin
                arready <= 1'b1;
            end else begin
                arready <= 1'b0;
            end

            if (arready && arvalid && ~rvalid) begin
                rvalid <= 1'b1;
                case (araddr[5:0])
                    6'h00: rdata <= ctrl_stat_reg;
                    6'h04: rdata <= reg_key[31:0];
                    6'h08: rdata <= reg_key[63:32];
                    6'h0C: rdata <= reg_key[95:64];
                    6'h10: rdata <= reg_key[127:96];
                    6'h14: rdata <= reg_text_in[31:0];
                    6'h18: rdata <= reg_text_in[63:32];
                    6'h1C: rdata <= reg_text_in[95:64];
                    6'h20: rdata <= reg_text_in[127:96];
                    6'h24: rdata <= text_out[31:0];
                    6'h28: rdata <= text_out[63:32];
                    6'h2C: rdata <= text_out[95:64];
                    6'h30: rdata <= text_out[127:96];
                    default: rdata <= 32'h0;
                endcase
            end else if (rvalid && rready) begin
                rvalid <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // AES Cores Instantiations
    // ------------------------------------------------------------------------
    
    // AES Cipher Core (Encryption)
    aes_cipher_top u_aes_cipher (
        .clk      (aclk),
        .rst      (rst),
        .ld       (reg_start_ld & ~reg_mode),
        .done     (cipher_done),
        .key      (reg_key),
        .text_in  (reg_text_in),
        .text_out (cipher_text_out)
    );

    // AES Inverse Cipher Core (Decryption)
    aes_inv_cipher_top u_aes_inv_cipher (
        .clk      (aclk),
        .rst      (rst),
        .kld      (reg_key_ld   & reg_mode),
        .kdone    (inv_cipher_kdone),
        .ld       (reg_start_ld & reg_mode),
        .done     (inv_cipher_done),
        .key      (reg_key),
        .text_in  (reg_text_in),
        .text_out (inv_cipher_text_out)
    );

endmodule
