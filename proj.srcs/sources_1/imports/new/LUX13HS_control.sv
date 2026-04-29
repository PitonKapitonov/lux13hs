`timescale 1ns / 1ps

module LUX13HS_control(
    input logic             clk133,
//    input logic             clk133_shifted,
//    output logic            clk_lux,                      //133MHz 
    output logic [8:0]      row_address,                  //from 0 to 431 that means 864 rows (because be-line rows in matrix)
    output logic            st_rowb_n,
    output logic            st_readb_n,
    output logic            st_rowt_n,
    output logic            st_readt_n,
   
    
    output logic            TX_n,       // transfer of charge from the photodetector PD to the storage gate SG   
    output logic            TX2_n,      // second transfer control 
    output logic            PD_n,       // shutter control
    output logic            PRST_n,     // resets the pixel memories SG; recommend keeping PRST_n always Low
    
    
    input logic             TX2_enable,
    input logic             rst,
    
    input logic             sending_data_active
                   
    );

//assign clk_lux = clk133_shifted;   
initial begin PRST_n = 0; TX2_n = 1; end
logic [7:0] cnt_clk = 'd174;
logic [7:0] cnt_inter_readout_gap = 0;
logic exposure = 0;
logic inter_readout_gap = 0;
logic inter_readout_gap_del, inter_readout_gap_del2, inter_readout_gap_del3, inter_readout_gap_del4;
logic inter_readout_gap_strb;
assign inter_readout_gap_strb = !inter_readout_gap_del3 & inter_readout_gap_del4;
logic enable_readout = 0;
//logic TX2_enable = 1;
initial row_address =0;
always @ (posedge clk133) begin
    if (rst) begin row_address <= 'd511; /*st_rowb_n <= 1; st_readb_n <= 1; st_rowt_n <= 1; st_readt_n <= 1; */end
 
    else if (!sending_data_active) begin
        cnt_clk <= cnt_clk + 1;
        if (cnt_clk == 'd180) cnt_clk <= 1;                             //180 clocks between st_read to have enough time for readout
        if (((cnt_clk == 'd175) || (cnt_clk == 'd76)) && row_address != 'd431 && !inter_readout_gap)  row_address <= row_address + 1;
        if (cnt_clk == 'd76  && row_address == 'd511) row_address <= row_address;
        if (cnt_clk == 'd120 && row_address == 'd511) inter_readout_gap <= 1;
        if (cnt_inter_readout_gap == 'd145) inter_readout_gap <= 0; 
        if (row_address == 'd431 && cnt_clk == 'd175) row_address <= 'd511;
        if (inter_readout_gap) cnt_inter_readout_gap <= cnt_inter_readout_gap + 1;
        if (row_address == 'd200) exposure <= 1;
        if (cnt_clk == 'd90 && row_address == 'd511 && TX2_enable && TX_n) TX2_n <= 0;
        if (cnt_clk == 'd130 && row_address == 'd511 && TX2_enable) TX2_n <= 1;
    end
    
    if (inter_readout_gap_strb) begin enable_readout <= 1; cnt_clk <= 'd164; cnt_inter_readout_gap <= 0; exposure <= 0; inter_readout_gap <= 0; end
    
    inter_readout_gap_del  <= inter_readout_gap;
    inter_readout_gap_del2 <= inter_readout_gap_del;
    inter_readout_gap_del3 <= inter_readout_gap_del2;
    inter_readout_gap_del4 <= inter_readout_gap_del3;
end
  
  
  
    
assign st_rowb_n  = (enable_readout && (cnt_clk == 'd1  || cnt_clk == 'd2)  && row_address != 'd511 &&                         !inter_readout_gap) ? 0 : 1'b1;
assign st_readb_n = (enable_readout && (cnt_clk == 'd1  || cnt_clk == 'd2)  && row_address != 0     &&                         !inter_readout_gap) ? 0 : 1'b1;
assign st_rowt_n  = (enable_readout && (cnt_clk == 'd82 || cnt_clk == 'd83) && row_address != 0     && row_address != 'd511 && !inter_readout_gap) ? 0 : 1'b1;
assign st_readt_n = (enable_readout && (cnt_clk == 'd82 || cnt_clk == 'd83) && row_address != 1     &&                         !inter_readout_gap) ? 0 : 1'b1;  


assign PD_n = exposure;
assign TX_n = !inter_readout_gap;

endmodule
