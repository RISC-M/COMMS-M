`timescale 1ps/1ps
`default_nettype none

module immediate_fu #(
    parameter N = 4,
    parameter ADDR_WIDTH = 7,
    parameter WIDTH = 32
) (
    input wire clk,
    input wire rst_n,

    input  wire  [ADDR_WIDTH-1:0] out_addr_busses [0:N-1],
    output logic [WIDTH-1:0]      out_busses   [0:N-1],
    output logic                  busses_valid [0:N-1]
);

    genvar i;
    generate
        for (i = 0; i < N; i++) begin
            out_port #(
                .N(1),
                .ADDR_WIDTH(1),
                .ADDRESS(1'b1)
            ) out_port_inst (
                .clk(clk),
                .rst_n(rst_n),
                .addr_busses({out_addr_busses[i][ADDR_WIDTH-1]}),
                .busses({out_busses[i]}),
                .busses_valid({busses_valid[i]}),
                .data(WIDTH'(out_addr_busses[i][ADDR_WIDTH-2:0])),
                .data_valid(1),
                .data_read()
            );
        end
    endgenerate

endmodule
