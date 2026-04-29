`timescale 1ns / 1ps

module UDP_Ethernet#(
    parameter logic[47:0] local_mac     = 48'h00_0a_35_01_02_03,    // a Xilinx mac address
    parameter logic[31:0] local_ip      = 32'h10_00_00_80,          // 16.0.0.128
    parameter logic[15:0] local_port    = 16'h04d2,                 // 1234
    parameter logic[15:0] remote_port   = 16'h04d2                  // 1234
)
(   
    input   logic           clk,
    input   logic           locked,
    input   logic           mii_tx_clk,
    output  logic [3:0]     mii_txd,    
    output  logic           mii_tx_en,  
        
    input   logic           mii_rx_clk,              
    input   logic [3:0]     mii_rxd,     
    input   logic           mii_rx_dv,           
    input   logic           mii_rx_er,
    output  logic           mii_rst_n,
    
    input  logic            udp_tx_tvalid, 
    output logic            udp_tx_tready, 
    input  logic            udp_tx_tlast,  
    input  logic            udp_tx_tuser,
    input  logic [7:0]      udp_tx_tdata,
    
    
    output logic            clk_read_fifo
    );
    
    assign clk_read_fifo = rx_axis_mac_aclk;
    logic           rx_axis_mac_aclk;
    logic           rx_axis_mac_tvalid;
    logic [7 : 0]   rx_axis_mac_tdata;
    logic           rx_axis_mac_tlast;
    logic           rx_axis_mac_tuser;
                                           
    logic           tx_axis_mac_aclk;
    logic           tx_axis_mac_tvalid;
    logic           tx_axis_mac_tready;
    logic [7 : 0]   tx_axis_mac_tdata;
    logic           tx_axis_mac_tlast;
    logic           tx_axis_mac_tuser;


    
    
temac temac_inst (
    .resetn(locked),
    //
    .eth_mii_tx_clk (mii_tx_clk), 
    .eth_mii_txd    (mii_txd), 
    .eth_mii_tx_en  (mii_tx_en),  
    
    .eth_mii_rx_clk (mii_rx_clk), 
    .eth_mii_rxd    (mii_rxd), 
    .eth_mii_rx_dv  (mii_rx_dv), 
    .eth_mii_rx_er  (mii_rx_er), 
    .eth_mii_rst_n  (mii_rst_n),
    //    
    .rx_axis_aclk   (rx_axis_mac_aclk), 
    .rx_axis_tvalid (rx_axis_mac_tvalid),                                       
    .rx_axis_tdata  (rx_axis_mac_tdata), 
    .rx_axis_tlast  (rx_axis_mac_tlast), 
    .rx_axis_tuser  (rx_axis_mac_tuser),
    //
    .tx_axis_aclk   (tx_axis_mac_aclk), 
    .tx_axis_tvalid (tx_axis_mac_tvalid), 
    .tx_axis_tready (tx_axis_mac_tready),  
    .tx_axis_tdata  (tx_axis_mac_tdata), 
    .tx_axis_tlast  (tx_axis_mac_tlast), 
    .tx_axis_tuser  (tx_axis_mac_tuser)
);





logic udp_rx_tvalid, udp_rx_tready, udp_rx_tlast, udp_rx_tuser;
logic[7:0] udp_rx_tdata;


udp_stack #(.local_mac(local_mac), .local_ip(local_ip), .local_port(local_port), .remote_port(remote_port)) udp_stack_inst (
    .clk(clk),
    .srst(locked),
    // rx data from temac
    .rx_axis_mac_aclk   (rx_axis_mac_aclk   ), //RX clock from PHY
    .rx_axis_mac_tvalid (rx_axis_mac_tvalid ),
    .rx_axis_mac_tdata  (rx_axis_mac_tdata  ),
    .rx_axis_mac_tlast  (rx_axis_mac_tlast  ),
    .rx_axis_mac_tuser  (rx_axis_mac_tuser  ),
    // tx data to temac
    .tx_axis_mac_aclk   (tx_axis_mac_aclk   ), //TX clock from PHY
    .tx_axis_mac_tvalid (tx_axis_mac_tvalid ),
    .tx_axis_mac_tready (tx_axis_mac_tready ),   //input from MAC
    .tx_axis_mac_tdata  (tx_axis_mac_tdata  ),
    .tx_axis_mac_tlast  (tx_axis_mac_tlast  ),
    .tx_axis_mac_tuser  (tx_axis_mac_tuser  ),
    // udp message to receive
    .udp_rx_tvalid      (udp_rx_tvalid  ), 
    .udp_rx_tready      (udp_rx_tready  ), 
    .udp_rx_tdata       (udp_rx_tdata   ),
    .udp_rx_tlast       (udp_rx_tlast   ), 
    .udp_rx_tuser       (udp_rx_tuser   ),
    // udp message to transmit
    .udp_tx_tvalid      (udp_tx_tvalid  ), 
    .udp_tx_tready      (udp_tx_tready  ), 
    .udp_tx_tdata       (udp_tx_tdata   ),
    .udp_tx_tlast       (udp_tx_tlast   ), 
    .udp_tx_tuser       (udp_tx_tuser   )
    );



endmodule
