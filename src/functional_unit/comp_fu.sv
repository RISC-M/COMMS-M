`default_nettype none
`timescale 1ps/1ps

module comp_fu #(
    //I made these 4 becuase we talked about the comparator being able to connect to all 4 busses
    parameter IN_N = 4,
    //I think we don't have any out busses, just stat.
    //parameter OUT_N = 4,
    parameter ADDR_WIDTH = 7,
    parameter WIDTH = 32,
    parameter bit [ADDR_WIDTH-1:0] COMPEQ_T = 7,   //TO-DO: arbitrary port addresses, we have to change that
    parameter bit [ADDR_WIDTH-1:0] COMPNEQ_T = 8,
    //I can't remember if we agreed up on the 3 triggers or'ed together or if we were sticking to 2, so I'll put this just in case
    parameter bit [ADDR_WIDTH-1:0] COMPGT_T = 9,
    parameter bit [ADDR_WIDTH-1:0] COMP_O = 10
    //Do we need a result register?
)(
    input  wire clk,
    input  wire rst_n,
    
    input  wire  [ADDR_WIDTH-1:0] in_addr_busses  [IN_N-1:0],
    input  wire  [WIDTH-1:0]      in_busses       [IN_N-1:0],
    input  wire  [1:0]            condition_flags [IN_N-1:0],
    input  wire                   status_bus, 
    
    //See above comment on output busses.

    /*input  wire  [ADDR_WIDTH-1:0] out_addr_busses [OUT_N-1:0],
    output logic [WIDTH-1:0]      out_busses      [OUT_N-1:0],
    output logic                  busses_valid    [OUT_N-1:0],*/

    //new_status_bus needs to be an output to the rest of the in_ports of the other FUs I think
    //Also takes status_bus as an input
    //Do we want status bus to be registered when comparator is not used?
    output wire                   new_status_bus
);
    
    //Just to clarify, do we want conditional comparator operation too if its setting the status_bus?
    //Should the status bus be registered/hold its previous value until the next comparator operation?

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
        .data(GT_trigger),
        .data_valid(GT_triggered)
    );

    logic [WIDTH-1:0]   operand_trigger;
    logic               operand_triggered;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(COMP_O)
    ) operand_trigger_inst (
        .clk(clk),
        .rst_n(rst_n),
        .busses(in_busses),
        .addr_busses(in_addr_busses),
        .condition_flags(condition_flags),
        .status_bus(status_bus),
        .data(operand_trigger),
        .data_valid(operand_triggered)
    );

    //Signals
    logic equal;
    logic not_equal;
    logic greater_than;


    always_comb begin
        equal = (equal_trigger == operand_trigger) & (equal_triggered & operand_triggered);
        not_equal = (not_equal_trigger == operand_trigger) & (not_equal_triggered & operand_triggered);
        greater_than = (GT_trigger == operand_trigger) & (GT_triggered & operand_triggered);
    end

    assign new_status_bus = equal | not_equal | greater_than;
    
endmodule
