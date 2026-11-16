`default_nettype none
`timescale 1ps/1ps

module big_imm_fu #(
    parameter IN_N = 4,
    parameter OUT_N = 2,
    parameter ADDR_WIDTH = 7,
    parameter WIDTH = 32,
    parameter bit [ADDR_WIDTH-1:0] IMM_O = 0,
    parameter bit [ADDR_WIDTH-1:0] IMM_R = 0
) (
    input wire clk,
    input wire rst_n,

    input  wire  [ADDR_WIDTH-1:0] in_addr_busses [0:IN_N-1],
    input  wire  [WIDTH-1:0]      in_busses   [0:IN_N-1],
    input  wire  [1:0]            condition_flags [0:IN_N-1],
    input  wire                   status_bus,
    input  wire                   squash_line,

    input  wire  [ADDR_WIDTH-1:0] out_addr_busses [0:OUT_N-1],
    output logic [WIDTH-1:0]      out_busses   [0:OUT_N-1],
    output logic                  busses_valid [0:OUT_N-1]
);

    logic [(IN_N * ADDR_WIDTH) - 1:0] big_immediate;
    logic [IN_N-1:0] big_immediate_part_v;
    genvar i;
    generate
        for (i = 0; i < IN_N; i++) begin
            logic [WIDTH-1:0] bus_data;
            in_port #(
                .N(1),
                .WIDTH(WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ADDRESS(IMM_O),
                .REGISTER_WITH_BYPASS(1)
            ) add_trigger_inst (
                .clk(clk),
                .rst_n(rst_n),
                .busses({in_busses[i]}),
                .addr_busses({in_addr_busses[i]}),
                .condition_flags({condition_flags[i]}),
                .status_bus(status_bus),
                .squash_line(squash_line),
                .data(bus_data),
                .data_valid(big_immediate_part_v[i])
            );
            assign big_immediate[(i+1) * ADDR_WIDTH - 1 -: ADDR_WIDTH] = ADDR_WIDTH'(bus_data);
        end
    endgenerate    

    logic [WIDTH-1:0] result;
    logic             result_valid;
    out_port #(
        .N(OUT_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(IMM_R),
        .ALLOW_OVERWRITE(1)
    ) result_port (
        .clk(clk),
        .rst_n(rst_n),
        .addr_busses(out_addr_busses),
        .squash_line(squash_line),
        .busses(out_busses),
        .busses_valid(busses_valid),
        .data(WIDTH'($signed(big_immediate))),
        .data_valid(&big_immediate_part_v),
        .data_read()
    );

endmodule
