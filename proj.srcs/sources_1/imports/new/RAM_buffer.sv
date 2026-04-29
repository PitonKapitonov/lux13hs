`timescale 1ns / 1ps



module RAM_buffer (
    input  logic               clka,
    input  logic               clkb,

    input  logic               ena,
    input  logic               enb,
    input  logic               wea,
    input  logic [9:0]         addra,
    input  logic [4320:0]       dina,
    input  logic [179:0][9:0]  addrb,
    output logic [179:0][71:0] doutb
);

    genvar i;
    generate
        for (i = 0; i < 180; i++) begin : ram_block
            blk_mem_gen_0 ram_inst (
                .clka(clka),            // input wire clka
                .ena(ena),           // input wire ena
                .wea(wea),           // input wire [0 : 0] wea
                .addra(addra),       // input wire [9 : 0] addra
                .dina(dina),         // input wire [71 : 0] dina
                .clkb(clkb),            // input wire clkb
                .enb(enb),           // input wire enb
                .addrb(addrb[i]),       // input wire [9 : 0] addrb
                .doutb(doutb[i])        // output wire [71 : 0] doutb
            );
        end
    endgenerate

endmodule
