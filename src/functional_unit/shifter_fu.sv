`default_nettype none
`timescale 1ps/1ps

module shifter_fu #(
    parameter IN_N = 2,
    parameter OUT_N = 2,
    parameter ADDR_WIDTH = 7,
    parameter WIDTH = 32,
    //parameter bit [ADDR_WIDTH-1:0] SHIFT_T = 3,   Optional
    parameter bit [ADDR_WIDTH-1:0] SHIFT_O = 4,
    parameter bit [ADDR_WIDTH-1:0] SHIFT_R = 5
)(
    //3. Do we use wires instead of logics to allow multiple drivers?
    input wire clk,
    input wire rst_n,
    
    //4. Are these the same name across multiple modules so that in synthesizes into multiple driven wires? i.e. on purpose?
    input wire [ADDR_WIDTH-1:0] in_addr_busses [IN_N-1:0],
    input wire [WIDTH-1:0]      in_busses [IN_N-1:0],
    
    //5. Should these be wires or logics? Can be driven from multiple places I think.
    input wire [ADDR_WIDTH-1:0] out_addr_busses [OUT_N-1:0],
    output logic [WIDTH-1:0]      out_busses [OUT_N-1:0],
    output logic                  busses_valid [OUT_N-1:0]

);
    //Potential for multiple shifts? Wrote the module here

    /*logic [WIDTH-1:0] shift_trigger;
    logic             shift_triggered;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(SHIFT_T),
        .REGISTER_WITH_BYPASS(0)
        //6. No bypass for now, check with henry
    ) shift_trigger_inst (
        .clk(clk),
        .rst_n(reset),
        .addr_busses(in_addr_busses),  
        .busses(in_busses),
        .data(shift_trigger),
        .data_valid(shift_triggered)
    );*/

    //7. In this case do we want a changed name, so the "operand_valid" wire isn't driven across modules? Is that even a valid concern?
    logic [WIDTH-1:0] shift_operand;
    logic             shift_operand_valid;
    in_port #(
        .N(IN_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(SHIFT_O),
        //Testing this, leaving bypass on locks the data in the data register and keeps the operand, unlike the un-bypassed version.
        //.REGISTER_WITH_BYPASS(1)
        .REGISTER_WITH_BYPASS(0)
        //No bypass for now, check with henry on operand vs trigger bypassing
    ) shift_operand_inst (
        .clk(clk),
        .rst_n(rst_n),
        .addr_busses(in_addr_busses),  
        .busses(in_busses),
        .data(shift_operand),
        .data_valid(shift_operand_valid)
    );

    logic [WIDTH-1:0] shift_result;
    logic             shift_valid;
    out_port #(
        .N(OUT_N),
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDRESS(SHIFT_R)
    ) shift_result_inst (
        .clk(clk),
        .rst_n(rst_n),
        .addr_busses(out_addr_busses),  
        .busses(out_busses),
        .busses_valid(busses_valid),
        .data(shift_result),
        .data_valid(shift_valid),
        //8. IDK what to do with this port
        .data_read()
    );

    //Data update:
    //9. Entirely unsure of if we even need 2 ports, I wrote the second port in just in case
    always_comb begin
        shift_result = shift_operand << 1;
        shift_valid = shift_operand_valid;
    end

endmodule
