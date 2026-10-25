module mult_array (
    input clk, 
    input rst_n,
    input [3:0]a,
    input [3:0]b,
    output reg[7:0]p 
);
    reg [3:0] a_r, b_r;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
           a_r <= 4'b0;
           b_r <= 4'b0;
        end else begin
           a_r <=a;
           b_r <=b;
        end
    end

    wire [3:0] pp0 = a_r & {4{b_r[0]}};
    wire [3:0] pp1 = a_r & {4{b_r[1]}}; 
    wire [3:0] pp2 = a_r & {4{b_r[2]}};
    wire [3:0] pp3 = a_r & {4{b_r[3]}};

    wire [3:0] s1, s2, s3; //sum wires
    wire [4:0] c1, c2, c3; //carry wires of the FAs
    wire [3:0] r0, r1, r2, r3; //the part of each row that we pass on to the next along with the concatenated MSB bit (r3 contains p[4:7])

    assign r0  = {1'b0, pp0[3], pp0[2], pp0[1]}; //before passing r0 into the FA, we append it with an MSB of 0
    assign c1[0] = 1'b0;
    assign c2[0] = 1'b0;
    assign c3[0] = 1'b0;

    genvar j ; 
    generate
        for(j = 0; j<4; j = j + 1)   begin : row1
           full_adder fa (.a(pp1[j]), .b(r0[j]), .cin(c1[j]), 
           .sum(s1[j]), .cout(c1[j+1]));
        end
    endgenerate
    assign r1 = {c1[4], s1[3], s1[2], s1[1]}; //the carryout of FA0 will be the MSB of r1

    generate
        for (j=0; j<4; j = j+1) begin : row2
            full_adder fa(.a(pp2[j]), .b(r1[j]), .cin(c2[j]), .sum(s2[j]), .cout(c2[j+1]));
        end
    endgenerate
    assign r2 = {c2[4], s2[3], s2[2], s2[1]};
    generate
        for (j = 0; j < 4 ; j = j+1) begin : row3
            full_adder fa(.a(pp3[j]), .b(r2[j]), .cin(c3[j]), .sum(s3[j]), .cout(c3[j+1]));
        end
    endgenerate
    assign r3 = {c3[4], s3[3], s3[2], s3[1]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            p <= 8'b0;
        else
            p <= {r3, s3[0], s2[0], s1[0], pp0[0]}; //concatenating all the product bits
    end
endmodule            
                                      
