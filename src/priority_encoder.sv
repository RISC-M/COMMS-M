`timescale 1ps/1ps
`default_nettype none
module priority_encoder #(
    parameter N = 2,
    parameter WIDTH = 32
) (
    input  wire  [WIDTH-1:0] in     [0:N-1],
    input  wire              select [0:N-1],
    output logic [WIDTH-1:0] out,
    output logic [N-1:0]     selected
);

    int i;
    always_comb begin
        out = in[N-1];
        selected = 0;
        for (i = 0; i < N; i = i + 1) begin
            if (select[i]) begin
                out = in[i];
                selected = N'(1) << i;
            end
        end
    end

endmodule