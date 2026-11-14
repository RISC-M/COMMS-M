`default_nettype none
`timescale 1ps/1ps

module integer_fu #(
    parameter IN_N = 2,
    parameter OUT_N = 2,
    parameter ADDR_WIDTH = 7,
    parameter WIDTH = 32,
    parameter bit [ADDR_WIDTH-1:0] ADD_T = 0,
    parameter bit [ADDR_WIDTH-1:0] INT_O = 1,
    parameter bit [ADDR_WIDTH-1:0] INT_R = 2
) (
    input wire clk,
    input wire rst_n,

    input  wire  [ADDR_WIDTH-1:0] in_addr_busses [0:IN_N-1],
    input  wire  [WIDTH-1:0]      in_busses   [0:IN_N-1],
    input  wire  [ADDR_WIDTH-1:0] out_addr_busses [0:OUT_N-1],
    output logic [WIDTH-1:0]      out_busses   [0:OUT_N-1],
    output logic                  busses_valid [0:OUT_N-1]
);
    logic [WIDTH-1:0] add_trigger;
    logic             add_triggered;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(ADD_T)
    ) add_trigger_inst (
        .clk(clk),
        .rst_n(rst_n),
        .busses(in_busses),
        .addr_busses(in_addr_busses),
        .data(add_trigger),
        .data_valid(add_triggered)
    );

    logic [WIDTH-1:0] operand;
    logic             operand_valid;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(INT_O),
        .REGISTER_WITH_BYPASS(1)
    ) operand_port_inst (
        .clk(clk),
        .rst_n(rst_n),
        .busses(in_busses),
        .addr_busses(in_addr_busses),
        .data(operand),
        .data_valid(operand_valid)
    );

    logic [WIDTH-1:0] result;
    logic             result_valid;
    out_port #(
        .N(OUT_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(INT_R)
    ) result_port (
        .clk(clk),
        .rst_n(rst_n),
        .addr_busses(out_addr_busses),
        .busses(out_busses),
        .busses_valid(busses_valid),
        .data(result),
        .data_valid(result_valid),
        .data_read()
    );

    always_comb begin
        result = operand + add_trigger;
        result_valid = operand_valid & add_triggered;
    end
endmodule
