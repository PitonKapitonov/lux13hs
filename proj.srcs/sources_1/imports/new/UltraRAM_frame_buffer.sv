`timescale 1ns / 1ps
module frame_buffer_ultraram_base #(
    parameter DWIDTH = 72,
    parameter AWIDTH = 23
)(
    input  logic clk,
    input  logic we,
    input  logic en,
    input  logic [AWIDTH-1:0] addr,
    input  logic [DWIDTH-1:0] din,
    output logic [DWIDTH-1:0] dout
);

    URAM288_BASE #(
      
    ) uram_inst (
        .CLK(clk),
        .EN_A(en),
        .RDB_WR_A(we),
        .ADDR_A(addr),
        .DIN_A(din),
        .BWE_A(9'h1FF),
        .DOUT_A(dout),

        // Порт B отключён
        .EN_B(1'b0),
        .RDB_WR_B(1'b0),
        .ADDR_B(23'd0),
        .DIN_B(72'd0),
        .BWE_B(9'd0),
        .DOUT_B(),

        // Остальные сигналы - константы
        .DBITERR_A(),
        .DBITERR_B(),
        .SBITERR_A(),
        .SBITERR_B(),
        .RST_A(1'b0),
        .RST_B(1'b0),
        .SLEEP(1'b0),
        .INJECT_DBITERR_A(1'b0),
        .INJECT_DBITERR_B(1'b0),
        .INJECT_SBITERR_A(1'b0),
        .INJECT_SBITERR_B(1'b0),
        .OREG_CE_A(1'b0),
        .OREG_CE_B(1'b0),
        .OREG_ECC_CE_A(1'b0),
        .OREG_ECC_CE_B(1'b0)
    );

endmodule