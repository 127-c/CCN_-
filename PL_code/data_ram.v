//需要1bit 28深度的RAM  data_ram_ip
module data_ram (
    //system signals
    input               sclk,
    input               s_rst_n, 
    //downsample signals
    input              dowm_data,
    input              dowm_data_valid,
    input              [6:0]dowm_col_cnt,//列计数器
    input              [6:0] dowm_row_cnt//行计数器
);
//=======================================\
//define parameter and internal signal====
//=======================================/
wire    [4:0]                           wr_addr; //写地址

reg     [27:0]                          wr_en; //写使能




//=======================================\
//======= main code ===============
//=======================================/

assign wr_addr =    dowm_col_cnt[6:2];//取高5位作为地址写入信号
integer i;

always @(*) begin
    for (i = 0; i<=27 ; i = i+1 ) begin
        if(dowm_col_cnt == i)
            wr_en[i] =      dowm_data_valid;
        else
            wr_en[i] =      1'b0;
        
    end

end




data_ram_ip data_ram_ip_inst[27:0] (
    .clka                                       (sclk               ), // input clka
    .wea                                        (wr_en[27:0]        ), // input [0 : 0] wea
    .addra                                      (wr_addr              ), // input [4 : 0] addra
    .dina                                       (dowm_data          ), // input [0 : 0] dina
    .clkb                                       (sclk               ), // input clkb
    .enb                                        (                   ),
    .addrb                                      (                   ),
    .doutb                                      (                   ) // output [0 : 0] doutb
);



endmodule
