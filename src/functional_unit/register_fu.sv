`default_nettype none
`timescale 1ps/1ps

module register_fu #(
    parameter N = 4,
    parameter WIDTH = 32,
    parameter ADDR_WIDTH = 7,
    parameter bit [ADDR_WIDTH-1:0] ADDRESS_MASK  = 7'b0000111
)(
    input  wire  clk,
    input  wire  rst_n,

    input  wire  [ADDR_WIDTH-1:0] waddr_busses [0:N-1],
    input  wire  [ADDR_WIDTH-1:0] raddr_busses [0:N-1],
    input  wire  [1:0]            condition_flags [0:N-1],
    input  wire                   status_bus,
    input  wire                   squash_line,

    input  wire  [WIDTH-1:0]      write_busses [0:N-1],
    output logic [WIDTH-1:0]      read_busses  [0:N-1],
    output logic                  read_busses_valid [0:N-1]
);

    localparam bit [ADDR_WIDTH-1:0] ADDRESS_MASK_INV = ~ADDRESS_MASK;
    localparam ADDRESS_BITS = $clog2(ADDRESS_MASK);
    localparam REGISTER_COUNT = (1 << ADDRESS_BITS);

    logic [ADDRESS_BITS-1:0] read_bus_reg    [0:N-1];
    logic [N-1:0]            write_bus_valid;
    logic [ADDRESS_BITS-1:0] write_bus_reg   [0:N-1];


    int i;
    logic condition_met;
    always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        for (i = 0 ; i < N; i++)
            read_busses_valid[i] <= 0;
        write_bus_valid <= 0;
    end
    else begin
        for (i = 0 ; i < N; i++) begin
            read_busses_valid[i] <= ~|(raddr_busses[i] & ADDRESS_MASK_INV);
            read_bus_reg[i] <= ADDRESS_BITS'(raddr_busses[i] & ADDRESS_MASK);
            
            condition_met = condition_flags[i][0] ? (condition_flags[i][1] ? status_bus : ~status_bus) : 1;
            write_bus_valid[i] <= !squash_line & ~|(waddr_busses[i] & ADDRESS_MASK_INV) & condition_met;
            write_bus_reg[i] <= ADDRESS_BITS'(waddr_busses[i] & ADDRESS_MASK);
        end
    end

    logic [WIDTH-1:0] registers [0:REGISTER_COUNT-1];

    logic [WIDTH-1:0] data_in;
    logic             data_in_valid;

    int j;
    always_comb begin : bus_mux
        for (j = 0; j < N; j++)
        if (read_busses_valid[j])
            read_busses[j] = registers[read_bus_reg[j]];
        else
            read_busses[j] = 0;
    end

    int k;
    always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)
        for (k = 0; k < N; k++)
            registers[k] <= 0;
    else
        for (k = 0; k < N; k++)
            if (write_bus_valid[k])
                registers[write_bus_reg[k]] <= write_busses[k];

endmodule
