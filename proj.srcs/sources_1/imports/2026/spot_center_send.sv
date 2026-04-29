`timescale 1ns / 1ps



module spot_centers_to_UDP#(
    parameter  max_number_rows    = 23,
    parameter  max_number_columns = 23
)(
    input logic          clk,
    input logic          rst,
    //interface to array_of_centers
    input logic [11*(max_number_columns + 1)-1:0] Xc_row,
    input logic [11*(max_number_columns + 1)-1:0] Yc_row,
    input logic          s_axis_tvalid,
    output logic         s_axis_tready,
    output logic         sending_centers_array_finished,
    //interface to UDP
    output logic [7:0]  m_axis_tdata,
    output logic        m_axis_tvalid,
    output logic        m_axis_tlast,
    input logic         m_axis_tready

    );
    
logic  [2*11*(max_number_columns + 1)-1:0] Xc_Yc_row;
logic  [6:0]  byte_index;
logic         UDP_sending_active;


always @(posedge clk) begin
    if (rst) begin
        UDP_sending_active  <= 0;
        byte_index <= 0;
        s_axis_tready <= 0;
        sending_centers_array_finished <= 0;
    end 
    else begin
        if (!UDP_sending_active) begin
         sending_centers_array_finished <=0;
            if (s_axis_tvalid) begin
                s_axis_tready <= 1;
               
            end
            if (s_axis_tready) begin
                Xc_Yc_row <= {Xc_row,Yc_row};
                UDP_sending_active  <= 1;
                byte_index <= 0;
                s_axis_tready <= 0; 
            end
        end 
        else if (UDP_sending_active && m_axis_tready) begin
            byte_index <= byte_index + 1;
            if (byte_index == (11*(max_number_columns + 1)/4)) begin 
                UDP_sending_active <= 0;
                sending_centers_array_finished <= 1; 
            end
        end
    end
end

assign m_axis_tdata  = Xc_Yc_row[8*byte_index +: 8];
assign m_axis_tvalid = UDP_sending_active;
assign m_axis_tlast  = UDP_sending_active && (byte_index == (11*(max_number_columns + 1)/4));
endmodule
