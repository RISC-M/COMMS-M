`timescale 1ps/1ps
`default_nettype none

module core (
    input wire clk,
    input wire rst_n
);
    localparam WIDTH = 32;
    localparam ADDR_WIDTH = 7;

    // Cross chip busses (data, read address, write address)
    logic [31:0] busses         [0:3];
    logic [ADDR_WIDTH-1:0]  raddr_busses [0:3];
    logic [ADDR_WIDTH-1:0]  waddr_busses [0:3];

    // Bus Multiplexers
    localparam BUS_0_OUT_N = 3;
    logic [BUS_0_OUT_N-1:0] selected_bus_0;
    logic [WIDTH-1:0]       bus_0_writers   [0:BUS_0_OUT_N-1];
    logic                   bus_0_writers_v [0:BUS_0_OUT_N-1];
    priority_encoder #(.N(BUS_0_OUT_N)) bus_0_encoder (
        .in(bus_0_writers),
        .select(bus_0_writers_v),
        .out(busses[0]),
        .selected(selected_bus_0)
    );

    localparam BUS_1_OUT_N = 4;
    logic [BUS_1_OUT_N-1:0] selected_bus_1;
    logic [WIDTH-1:0]       bus_1_writers   [0:BUS_1_OUT_N-1];
    logic                   bus_1_writers_v [0:BUS_1_OUT_N-1];
    priority_encoder #(.N(BUS_1_OUT_N)) bus_1_encoder (
        .in(bus_1_writers),
        .select(bus_1_writers_v),
        .out(busses[1]),
        .selected(selected_bus_1)
    );
    
    localparam BUS_2_OUT_N = 3;
    logic [BUS_2_OUT_N-1:0] selected_bus_2;
    logic [WIDTH-1:0]       bus_2_writers   [0:BUS_2_OUT_N-1];
    logic                   bus_2_writers_v [0:BUS_2_OUT_N-1];
    priority_encoder #(.N(BUS_2_OUT_N)) bus_2_encoder (
        .in(bus_2_writers),
        .select(bus_2_writers_v),
        .out(busses[2]),
        .selected(selected_bus_2)
    );
    
    localparam BUS_3_OUT_N = 2;
    logic [BUS_3_OUT_N-1:0] selected_bus_3;
    logic [WIDTH-1:0]       bus_3_writers   [0:BUS_3_OUT_N-1];
    logic                   bus_3_writers_v [0:BUS_3_OUT_N-1];
    priority_encoder #(.N(BUS_3_OUT_N)) bus_3_encoder (
        .in(bus_3_writers),
        .select(bus_3_writers_v),
        .out(busses[3]),
        .selected(selected_bus_3)
    );

    // Function Units
    register_fu register_fu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .waddr_busses(waddr_busses),
        .raddr_busses(raddr_busses),
        .write_busses(busses),
        .read_busses({bus_0_writers[0], bus_1_writers[0], bus_2_writers[0], bus_3_writers[0]}),
        .read_busses_valid({bus_0_writers_v[0], bus_1_writers_v[0], bus_2_writers_v[0], bus_3_writers_v[0]})
    );

    immediate_fu #(

    ) immediate_fu_inst (
        .clk(clk),
        .rst_n(rst_n),

        .out_addr_busses(raddr_busses),
        .out_busses({bus_0_writers[1], bus_1_writers[1], bus_2_writers[1], bus_3_writers[1]}),
        .busses_valid({bus_0_writers_v[1], bus_1_writers_v[1], bus_2_writers_v[1], bus_3_writers_v[1]})
    );

    // Connect ifetch trigger and result to busses 0 and 1
    ifetch_fu #(
        .PC_T(1),
        .PC_R(1)
    ) ifetch_fu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .in_addr_busses({waddr_busses[0], waddr_busses[1]}),
        .in_busses({busses[0], busses[1]}),
        .out_addr_busses({raddr_busses[0], raddr_busses[1]}),
        .out_busses({bus_0_writers[2], bus_1_writers[2]}),
        .busses_valid({bus_0_writers_v[2], bus_1_writers_v[2]}),
        .read_addr_busses(raddr_busses),
        .write_addr_busses(waddr_busses)
    );

    

    // Integer fu allowing reading on bus 1,2 writing on 0,1
    integer_fu #(
        .IN_N(2),
        .OUT_N(2),
        .ADD_T(6'h0),
        .INT_O(6'h1),
        .INT_R(6'h2)
    ) integer_fu_0 (
        .clk(clk),
        .rst_n(rst_n),

        .in_addr_busses({waddr_busses[0], waddr_busses[1]}),
        .in_busses({busses[0], busses[1]}),
        .out_addr_busses({raddr_busses[1], raddr_busses[2]}),
        .out_busses({bus_1_writers[3], bus_2_writers[2]}),
        .busses_valid({bus_1_writers_v[3], bus_2_writers_v[2]})
    );
endmodule
