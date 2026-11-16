`default_nettype none
`timescale 1ps/1ps

module ifetch_fu #(
    parameter N = 4,
    parameter IN_N = 2,
    parameter OUT_N = 2,
    parameter ADDR_WIDTH = 7,
    parameter WIDTH = 32,
    parameter bit [ADDR_WIDTH-1:0] PC_T = 1,
    parameter bit [ADDR_WIDTH-1:0] PCR_T = 2,
    parameter bit [ADDR_WIDTH-1:0] PC_R = 1
) (
    input wire clk,
    input wire rst_n,

    input  wire  [ADDR_WIDTH-1:0] in_addr_busses     [0:IN_N-1],
    input  wire  [WIDTH-1:0]      in_busses          [0:IN_N-1],
    input  wire  [1:0]            in_condition_flags [0:IN_N-1],
    input  wire                   status_bus,

    input  wire  [ADDR_WIDTH-1:0] out_addr_busses    [0:OUT_N-1],
    output logic [WIDTH-1:0]      out_busses         [0:OUT_N-1],
    output logic                  busses_valid       [0:OUT_N-1],

    output logic [ADDR_WIDTH-1:0] read_addr_busses   [0:N-1],  
    output logic [ADDR_WIDTH-1:0] write_addr_busses  [0:N-1],
    output logic [1:0]            condition_flags    [0:N-1],
    output logic                  squash_line
);

    logic [64-1:0] instruction_mem [0:8191];

    logic [12:0] pc;
    logic [12:0] next_pc;

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
        .status_bus(status_bus),
        .squash_line(squash_line),
        .condition_flags(in_condition_flags),
        .data(pc_trigger),
        .data_valid(pc_triggered)
    );

    logic [WIDTH-1:0] pcr_trigger;
    logic             pcr_triggered;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(PCR_T)
    ) pcr_trigger_inst (
        .clk(clk),
        .rst_n(rst_n),
        .busses(in_busses),
        .addr_busses(in_addr_busses),
        .status_bus(status_bus),
        .squash_line(squash_line),
        .condition_flags(in_condition_flags),
        .data(pcr_trigger),
        .data_valid(pcr_triggered)
    );

    out_port #(
        .N(OUT_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(PC_R),
        .ALLOW_OVERWRITE(1)
    ) pc_result_port (
        .clk(clk),
        .rst_n(rst_n),
        .addr_busses(out_addr_busses),
        .squash_line(squash_line),
        .busses(out_busses),
        .busses_valid(busses_valid),
        .data(WIDTH'(next_pc)),
        .data_valid(1),
        .data_read()
    );

    always_comb begin
        if (pc_triggered)
            next_pc = 13'(pc_trigger);
        else if (pcr_triggered)
            next_pc = 13'($signed(pc) + $signed(pcr_trigger));
        else
            next_pc = pc + 1;
    end

    always_ff @( posedge clk or negedge rst_n )
    if (!rst_n)
        pc <= 0;
    else
        pc <= next_pc;

    int i;
    logic [63:0] instr_group;
    logic [15:0]  instr_single;
    always_comb begin
        squash_line = pc_triggered | pcr_triggered;

        instr_group = instruction_mem[pc];
        for (i = 0; i < N; i++) begin
            instr_single = instr_group[((i + 1) * 16) - 1 -: 16];
            read_addr_busses[i] = instr_single[6:0];
            write_addr_busses[i] = instr_single[13:7];
            condition_flags[i] = instr_single[15:14];
        end
    end
endmodule
