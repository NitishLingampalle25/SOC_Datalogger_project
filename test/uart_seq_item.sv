typedef enum bit [1:0] {
    AXI_WRITE,
    AXI_READ,
    UART_RX_SERIAL
} uart_op_e;

class uart_seq_item extends uvm_sequence_item;
    `uvm_object_utils(uart_seq_item)

    rand uart_op_e      op_type;
    
    // AXI-Lite fields
    rand logic [31:0]   addr;
    rand logic [31:0]   wdata;
    logic [31:0]        rdata;
    logic [1:0]         resp;

    // Serial fields
    rand logic [7:0]    serial_data;
    rand int unsigned   baud_rate; // e.g., 115200

    function new(string name = "uart_seq_item");
        super.new(name);
        baud_rate = 115200; // default
    endfunction
endclass
