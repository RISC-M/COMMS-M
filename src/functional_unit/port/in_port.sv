`default_nettype none
`timescale 1ps/1ps

module in_port #(
    parameter N = 2,
    parameter WIDTH = 32,
    parameter ADDR_WIDTH = 6,
    parameter bit [ADDR_WIDTH-1:0] ADDRESS  = 6'b000000,
    parameter REGISTER_WITH_BYPASS = 0
)(
    input  wire  clk,
    input  wire  rst_n,

    input  wire  [WIDTH-1:0]      busses      [0:N-1],
    input  wire  [ADDR_WIDTH-1:0] addr_busses [0:N-1],

    output logic [WIDTH-1:0]      data,
    output logic                  data_valid
);

    logic [N-1:0] bus_valid;


    int i;
    always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)
        bus_valid <= 0;
    else begin
        for (i = 0 ; i < N; i++)
            bus_valid[i] <= addr_busses[i] == ADDRESS;
    end

    logic [WIDTH-1:0] data_in;
    logic             data_in_valid;

    int j;
    always_comb begin : bus_mux
        data_in = 0;
        data_in_valid = 0;
        for (j = 0; j < N; j++)
        if (bus_valid[j]) begin
            data_in = busses[j];
            data_in_valid = 1;
        end
    end

    generate 
    if (REGISTER_WITH_BYPASS != 0) begin : bypass_reg_block
        logic [WIDTH-1:0] data_reg;
        logic             valid_reg;
        always_ff @(posedge clk or negedge rst_n)
        if (!rst_n)
            {data_reg, valid_reg} <= 0;
        else if (data_in_valid)
            {data_reg, valid_reg} <= {data_in, data_in_valid};

        always_comb begin
            data = data_in_valid ? data_in : data_reg;
            data_valid = data_in_valid ? 1 : valid_reg;
        end
    end else begin : no_reg_block
        always_comb begin
            data = data_in;
            data_valid = data_in_valid;
        end
    end
    endgenerate

endmodule
