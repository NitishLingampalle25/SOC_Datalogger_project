class uart_driver extends uvm_driver #(uart_seq_item);
    `uvm_component_utils(uart_driver)

    // Virtual interface handle
    virtual uart_vip_if vif;

    function new(string name = "uart_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Retrieve the virtual interface in build_phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual uart_vip_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("VIF_GET_FAIL", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
        end
    endfunction

    // Drive stimulus in run_phase
    virtual task run_phase(uvm_phase phase);
        // Reset defaults
        reset_signals();

        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task reset_signals();
        wait(vif.rst_n == 0);
        vif.awvalid   <= 1'b0;
        vif.wvalid    <= 1'b0;
        vif.bready    <= 1'b0;
        vif.arvalid   <= 1'b0;
        vif.rready    <= 1'b0;
        vif.uart_rx_i <= 1'b1; // UART idle state is high
        wait(vif.rst_n == 1);
    endtask

    


    virtual task drive_item(uart_seq_item item);
    @(posedge vif.clk);

    case (item.op_type)
        AXI_WRITE:      drive_axi_write(item.addr, item.wdata, item.resp);
        AXI_READ:       drive_axi_read(item.addr, item.rdata, item.resp);
        UART_RX_SERIAL: drive_uart_rx(item.serial_data, item.baud_rate);
        default:        `uvm_error("DRV", $sformatf("Unsupported operation: %s", item.op_type.name()))
    endcase
   endtask

  virtual task drive_axi_write(input logic [31:0] addr, input logic [31:0] data, output logic [1:0] resp);
    @(posedge vif.clk);
    vif.awaddr  <= addr;
    vif.awvalid <= 1'b1;
    vif.wdata   <= data;
    vif.wvalid  <= 1'b1;
    vif.bready  <= 1'b1;

    // Parallel handshake for AW and W channels
    fork
        begin
            do @(posedge vif.clk); while (!vif.awready);
            vif.awvalid <= 1'b0;
        end
        begin
            do @(posedge vif.clk); while (!vif.wready);
            vif.wvalid <= 1'b0;
        end
    join

    // Wait for response handshake
    do @(posedge vif.clk); while (!vif.bvalid);
    resp = vif.bresp;
    vif.bready <= 1'b0;
endtask



  virtual task drive_axi_read(input logic [31:0] addr, output logic [31:0] data, output logic [1:0] resp);
    @(posedge vif.clk);
    vif.araddr  <= addr;
    vif.arvalid <= 1'b1;
    vif.rready  <= 1'b1;

    // Address Read handshake
    do @(posedge vif.clk); while (!vif.arready);
    vif.arvalid <= 1'b0;

    // Wait for Read Data and Response
    do @(posedge vif.clk); while (!vif.rvalid);
    data = vif.rdata;
    resp = vif.rresp;
    vif.rready <= 1'b0;
endtask


 virtual task drive_uart_rx(input logic [7:0] data, input int unsigned baud_rate);
    realtime bit_period;
    bit_period = (1.0 / baud_rate) * 1s; // e.g. ~8.68 us for 115200

    // Ensure line starts idle
    vif.uart_rx_i <= 1'b1;
    #(bit_period);

    // 1. Start bit
    vif.uart_rx_i <= 1'b0;
    #(bit_period);

    // 2. 8 Data bits (LSB first)
    for (int i = 0; i < 8; i++) begin
        vif.uart_rx_i <= data[i];
        #(bit_period);
    end

    // 3. Stop bit
    vif.uart_rx_i <= 1'b1;
    #(bit_period);
endtask



virtual task run_phase(uvm_phase phase);
    reset_signals();

    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
        seq_item_port.get_next_item(req);
        
        // Clone item if response data needs to go back to sequence
        $cast(rsp, req.clone());
        rsp.set_id_info(req);

        drive_item(rsp);

        seq_item_port.item_done();
        seq_item_port.put_response(rsp);
    end
endtask





endclass
