`timescale 1ns / 1ps



module AXIS_MUX_to_UDP(

    input logic         clk,
    input logic         rst,
    input logic         clk533,
    //interface to FIFO
    input logic [159:0]  s_axis_tdata [79:0],
    input logic          s_axis_tvalid,
    output logic [79:0] s_axis_tready,
    output logic [9:0]   read_addr_b,
    output logic         read_finished,
    //interface to UDP
    input logic         m_axis_tready_udp,
    output logic [7:0]  m_axis_tdata_udp,
    output logic        m_axis_tvalid_udp,
    output logic        m_axis_tlast_udp,
    
    output logic        sending_data_active_bufg,
    input logic         start_sending_data
    );
    
logic [159:0]    ram_row             = 0;
logic [4:0]     byte_index           = 0;
logic           UDP_sending_active   = 0;
logic [6:0]     group_index          = 0;
logic           s_axis_tready_del    = 0;
logic           s_axis_tready_del2   = 0;
logic           s_axis_tready_del3   = 0;

logic [7:0]  m_axis_tdata;
logic        m_axis_tvalid;
logic        m_axis_tlast;
logic  sending_data_active;
initial begin
    s_axis_tready       = 0;
    sending_data_active = 0;
    read_addr_b         = 0;
    read_finished       = 0;
    m_axis_tdata        = 0;
    m_axis_tvalid       = 0;
end

BUFG BUFG_sending_data_active(
    .I(sending_data_active),
    .O(sending_data_active_bufg)
);


always @(posedge clk533) begin

        if (start_sending_data) sending_data_active <= 1;

        if (!m_axis_tvalid & fifo_ready) begin
            if (s_axis_tvalid) begin
                s_axis_tready[group_index] <= 1;
                s_axis_tready_del <= s_axis_tready[group_index];
                s_axis_tready_del2 <= s_axis_tready_del;
                 s_axis_tready_del3 <= s_axis_tready_del2;
            end
            if (s_axis_tready_del3 & fifo_ready) begin
                ram_row <= s_axis_tdata[group_index];
                m_axis_tvalid  <= 1;
                byte_index <= 0;
                s_axis_tready[group_index] <= 0;
                s_axis_tready_del <= 0; 
                s_axis_tready_del2 <= 0; 
                s_axis_tready_del3 <= 0; 
            end
        end 
        else if (m_axis_tvalid /*&& m_axis_tready_udp*/ && fifo_ready) begin
            if (byte_index < 19) byte_index <= byte_index + 1;
            else begin 
                m_axis_tvalid <= 0;
                group_index  <= (group_index == 'd79) ? 0 : group_index + 1;
                read_addr_b <= (group_index == 'd79) ? read_addr_b + 1 : read_addr_b ;
                if (read_addr_b == 'd824 && group_index == 'd79) begin read_addr_b <= 0; read_finished <= 1; sending_data_active <= 0; end
            end
        end
end


assign m_axis_tdata  = ram_row[8*byte_index +: 8];
assign m_axis_tlast  = m_axis_tvalid && (byte_index == 'd19) && (group_index == 'd79);


// always_ff @ (posedge clk533) begin
//     m_axis_tdata_udp    <= m_axis_tdata;
//     m_axis_tvalid_udp   <= m_axis_tvalid;
//     m_axis_tlast_udp    <= m_axis_tlast;
// end

axis_data_fifo_0 axis_fifo_MUX_to_UDP (
  .s_axis_aresetn(!rst),  // input wire s_axis_aresetn
  .s_axis_aclk(clk533),        // input wire s_axis_aclk
  .s_axis_tvalid(m_axis_tvalid & fifo_ready),    // input wire s_axis_tvalid
  .s_axis_tready(fifo_ready),    // output wire s_axis_tready
  .s_axis_tdata(m_axis_tdata),      // input wire [7 : 0] s_axis_tdata
  .s_axis_tlast(m_axis_tlast),      // input wire s_axis_tlast

  .m_axis_aclk(clk),        // input wire m_axis_aclk
  .m_axis_tvalid(m_axis_tvalid_udp),    // output wire m_axis_tvalid
  .m_axis_tready(m_axis_tready_udp),    // input wire m_axis_tready
  .m_axis_tdata(m_axis_tdata_udp),      // output wire [7 : 0] m_axis_tdata
  .m_axis_tlast(m_axis_tlast_udp)      // output wire m_axis_tlast
);

endmodule
