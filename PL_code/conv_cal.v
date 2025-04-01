module conv_cal#(
        parameter   W_WIDTH =       8           ,
        parameter   B_WIDTH =       8           
)(
//system signals
    input               sclk                    ,
    input               s_rst_n                 ,
//DATA RAM
    output reg [ 4:0]   data_rd_addr            ,//读地址   
    output reg [ 4:0]   row_cnt                 ,//行计数器
    input      [ 4:0]   col_data                ,//列数据 
    input               cal_start               ,
//PARAM ROM
    output reg [ 8:0]   param_rd_addr           ,//同时读5个ROM地址 每个ROM   depth 150 一共30 个卷积核，每读一次读5X5的W也就是25个
    output reg [ 4:0]   conv_cnt                ,//计算卷积核个数
    input [ W_WIDTH-1:0]param_w_h0              ,//权重
    input [ W_WIDTH-1:0]param_w_h1              ,
    input [ W_WIDTH-1:0]param_w_h2              ,
    input [ W_WIDTH-1:0]param_w_h3              ,
    input [ W_WIDTH-1:0]param_w_h4              ,
    input [ B_WIDTH-1:0]param_bias              ,//偏执
//
    output wire [15:0]  conv_rslt               ,
    output reg          conv_rslt_act_vld           

); 
//Define parameter
reg                 conv_flag                    ;//卷积运算开始标志位
reg [ W_WIDTH*5-1:0] param_w_h0_arr              ;//权重矩阵
reg [ W_WIDTH*5-1:0] param_w_h1_arr              ;
reg [ W_WIDTH*5-1:0] param_w_h2_arr              ;
reg [ W_WIDTH*5-1:0] param_w_h3_arr              ;
reg [ W_WIDTH*5-1:0] param_w_h4_arr              ;
reg [ 4:0]           col_data_r4                 ;//图像数据缓存
reg [ 4:0]           col_data_r3                 ;
reg [ 4:0]           col_data_r2                 ;
reg [ 4:0]           col_data_r1                 ;  
reg [ 4:0]           col_data_r0                 ;

//===================================================\\
//====================== main code ==================\\

//卷积开始标志位时序
always @(posedge sclk or negedge s_rst_n) begin
        if (!s_rst_n) 
                conv_flag       <=      1'b0;
        else if (conv_cnt == 5'd29 && row_cnt == 5'd23 && data_rd_addr == 5'd31)
                conv_flag       <=      1'b0;
       
        else if (cal_start == 1'b1)
                conv_flag       <=      1'b1;  
end

//读取权重参数时序
always@(posedge sclk or negedge s_rst_n)begin
        if (!s_rst_n)
            param_rd_addr       <=      1'b0;
        else if (conv_flag == 1'b0)//清零
            param_rd_addr       <=      1'b0;
        else if (conv_flag == 1'd1 && row_cnt == 4'd0 && data_rd_addr <= 5'd4)//当卷积开始&&从第一列&&图像数据读完5*5之前  要把ROM参数导进来
            param_rd_addr       <=      1'b1 + param_rd_addr; 
        

end

//存储权重参数
always @(posedge sclk or negedge s_rst_n) begin
        if (!s_rst_n)begin
            param_w_h0_arr      <=      'd0;//权重参数矩阵
            param_w_h1_arr      <=      'd0;
            param_w_h2_arr      <=      'd0;
            param_w_h3_arr      <=      'd0;
            param_w_h4_arr      <=      'd0;
        end
        else if (data_rd_addr >= 'd1 && data_rd_addr <= 'd4 && row_cnt == 'd0)begin//读取图像数据5*5的    缓存到权重arr数组
            param_w_h0_arr      <=     {param_w_h0_arr[ W_WIDTH*4-1:0] , param_w_h0};
            param_w_h1_arr      <=     {param_w_h1_arr[ W_WIDTH*4-1:0] , param_w_h1};
            param_w_h2_arr      <=     {param_w_h2_arr[ W_WIDTH*4-1:0] , param_w_h2};
            param_w_h3_arr      <=     {param_w_h3_arr[ W_WIDTH*4-1:0] , param_w_h3};
            param_w_h4_arr      <=     {param_w_h4_arr[ W_WIDTH*4-1:0] , param_w_h4};
        end
end

//row_cnt 的时序，从第一行一直到23行

endmodule