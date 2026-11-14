`default_nettype none
`timescale 1ps/1ps

module ifetch_fu #(
    parameter N = 4,
    parameter IN_N = 2,
    parameter OUT_N = 2,
    parameter ADDR_WIDTH = 6,
    parameter WIDTH = 32,
    parameter bit [ADDR_WIDTH-1:0] PC_T = 1,
    parameter bit [ADDR_WIDTH-1:0] PC_R = 1
) (
    input wire clk,
    input wire rst_n,

    input  wire  [ADDR_WIDTH-1:0] in_addr_busses [0:IN_N-1],
    input  wire  [WIDTH-1:0]      in_busses   [0:IN_N-1],
    input  wire  [ADDR_WIDTH-1:0] out_addr_busses [0:OUT_N-1],
    output logic [WIDTH-1:0]      out_busses   [0:OUT_N-1],
    output logic                  busses_valid [0:OUT_N-1],

    output logic [ADDR_WIDTH-1:0] read_addr_busses  [0:N-1],  
    output logic [ADDR_WIDTH-1:0] write_addr_busses [0:N-1]
);

    logic [64-1:0] instruction_mem [0:8191];

    logic [12:0] pc;

    logic [WIDTH-1:0] pc_trigger;
    logic             pc_triggered;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(PC_T)
    ) pc_trigger_inst (
        .clk(clk),
        .rst_n(rst_n),
        .busses(in_busses),
        .addr_busses(in_addr_busses),
        .data(pc_trigger),
        .data_valid(pc_triggered)
    );

    out_port #(
        .N(OUT_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(PC_R)
    ) pc_result_port (
        .clk(clk),
        .rst_n(rst_n),
        .addr_busses(out_addr_busses),
        .busses(out_busses),
        .busses_valid(busses_valid),
        .data(pc_triggered ? pc_trigger : WIDTH'(pc+1)),
        .data_valid(1),
        .data_read()
    );

    always_ff @( posedge clk or negedge rst_n )
    if (!rst_n)
        pc <= 0;
    else
        if (pc_triggered)
            pc <= 13'(pc_trigger);
        else
            pc <= pc + 1;

    int i;
    logic [63:0] instr_group;
    logic [15:0]  instr_single;
    always_comb begin
        instr_group = instruction_mem[pc];
        for (i = 0; i < N; i++) begin
            instr_single = instr_group[((i + 1) * 16) - 1 -: 16];
            read_addr_busses[i] = instr_single[5:0];
            write_addr_busses[i] = instr_single[11:6];
        end
    end
endmodule
