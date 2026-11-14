`default_nettype none
`timescale 1ps/1ps

module out_port #(
    parameter N = 2,
    parameter WIDTH = 32,
    parameter ADDR_WIDTH = 7,
    parameter bit [ADDR_WIDTH-1:0] ADDRESS  = 7'b0000000
)(
    input  wire  clk,
    input  wire  rst_n,

    // Inputs from busses
    input  wire [ADDR_WIDTH-1:0]  addr_busses  [0:N-1],

    // Outputs to busses
    output logic [WIDTH-1:0]      busses       [0:N-1],
    output logic                  busses_valid [0:N-1],

    // Inputs from FU
    input  wire  [WIDTH-1:0]      data,
    input  wire                   data_valid,

    // Outputs to FU
    output wire                   data_read
);
    // Compute bus to output to
    logic [N-1:0] addr_match;
    int i;
    always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)
        addr_match <= 0;
    else begin
        for (i = 0 ; i < N; i++)
            addr_match[i] <= addr_busses[i] == ADDRESS;
    end

    assign data_read = |addr_match | !valid_reg;

    // Register data from FU
    logic [WIDTH-1:0] data_reg;
    logic             valid_reg;

    always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)
        {data_reg, valid_reg} <= 0;
    else begin
        if (data_read) 
            {data_reg, valid_reg} <= {data, data_valid};
    end

    // Wire up outputs
    genvar idx;
    generate
    for (idx = 0; idx < N; idx++) begin
        assign busses_valid[idx] = addr_match[idx] & valid_reg;
        assign busses[idx]       = data_reg;
    end
    endgenerate

endmodule
