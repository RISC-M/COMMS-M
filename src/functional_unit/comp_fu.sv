`default_nettype none
`timescale 1ps/1ps

module comp_fu #(
    parameter IN_N = 4,
    parameter OUT_N = 2,
    parameter ADDR_WIDTH = 7,
    parameter WIDTH = 32,
    parameter bit [ADDR_WIDTH-1:0] COMPEQ_T = 0,
    parameter bit [ADDR_WIDTH-1:0] COMPNEQ_T = 1,
    parameter bit [ADDR_WIDTH-1:0] COMPGT_T = 2,
    parameter bit [ADDR_WIDTH-1:0] COMP_O = 3,
    parameter bit [ADDR_WIDTH-1:0] COMP_R = 0
)(
    input  wire clk,
    input  wire rst_n,
    
    input  wire  [ADDR_WIDTH-1:0] in_addr_busses  [IN_N-1:0],
    input  wire  [WIDTH-1:0]      in_busses       [IN_N-1:0],
    input  wire  [1:0]            condition_flags [IN_N-1:0],
    input  wire                   squash_line,

    input  wire  [ADDR_WIDTH-1:0] out_addr_busses [OUT_N-1:0],
    output logic [WIDTH-1:0]      out_busses      [OUT_N-1:0],
    output logic                  busses_valid    [OUT_N-1:0],

    output logic                   status_bus
);

    logic [WIDTH-1:0]   equal_trigger;
    logic               equal_triggered;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(COMPEQ_T)
    ) equal_trigger_inst (
        .clk(clk),
        .rst_n(rst_n),
        .busses(in_busses),
        .addr_busses(in_addr_busses),
        .condition_flags(condition_flags),
        .status_bus(status_bus),
        .squash_line(squash_line),
        .data(equal_trigger),
        .data_valid(equal_triggered)
    );

    logic [WIDTH-1:0]   not_equal_trigger;
    logic               not_equal_triggered;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(COMPNEQ_T)
    ) not_equal_trigger_inst (
        .clk(clk),
        .rst_n(rst_n),
        .busses(in_busses),
        .addr_busses(in_addr_busses),
        .condition_flags(condition_flags),
        .status_bus(status_bus),
        .squash_line(squash_line),
        .data(not_equal_trigger),
        .data_valid(not_equal_triggered)
    );

    logic [WIDTH-1:0]   GT_trigger;
    logic               GT_triggered;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(COMPGT_T)
    ) GT_trigger_inst (
        .clk(clk),
        .rst_n(rst_n),
        .busses(in_busses),
        .addr_busses(in_addr_busses),
        .condition_flags(condition_flags),
        .status_bus(status_bus),
        .squash_line(squash_line),
        .data(GT_trigger),
        .data_valid(GT_triggered)
    );

    logic [WIDTH-1:0]   operand_trigger;
    logic               operand_triggered;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(COMP_O),
        .REGISTER_WITH_BYPASS(1)
    ) operand_trigger_inst (
        .clk(clk),
        .rst_n(rst_n),
        .busses(in_busses),
        .addr_busses(in_addr_busses),
        .condition_flags(condition_flags),
        .status_bus(status_bus),
        .squash_line(squash_line),
        .data(operand_trigger),
        .data_valid(operand_triggered)
    );

    //Signals
    logic equal;
    logic not_equal;
    logic greater_than;

    logic next_status_bus, next_status_bus_valid;

    out_port #(
        .N(OUT_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(COMP_R),
        .ALLOW_OVERWRITE(1)
    ) comp_res_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        .addr_busses(out_addr_busses),
        .busses(out_busses),
        .busses_valid(busses_valid),
        .squash_line(squash_line),
        .data({31'd0, next_status_bus}),
        .data_valid(next_status_bus_valid),
        .data_read()
    );


    always_comb begin
        equal = (equal_trigger == operand_trigger) & (equal_triggered & operand_triggered);
        not_equal = (not_equal_trigger != operand_trigger) & (not_equal_triggered & operand_triggered);
        greater_than = (GT_trigger > operand_trigger) & (GT_triggered & operand_triggered);

        next_status_bus = equal | not_equal | greater_than;
        next_status_bus_valid = operand_triggered & (equal_triggered | not_equal_triggered | GT_triggered);
    end

    always_ff @( posedge clk or negedge rst_n )
    if (!rst_n)
        status_bus <= 0;
    else if (next_status_bus_valid)
        status_bus <= next_status_bus;

endmodule
