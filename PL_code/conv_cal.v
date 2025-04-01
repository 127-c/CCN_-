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
    output wire [15:0]  conv_rslt_act              ,
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
reg [ 31:0]          conv_rslt                   ;
//乘法结果
wire[ 31:0] mult00;
wire[ 31:0] mult01;
wire[ 31:0] mult02;
wire[ 31:0] mult03;
wire[ 31:0] mult04;

wire[ 31:0] mult10;
wire[ 31:0] mult11;
wire[ 31:0] mult12;
wire[ 31:0] mult13;
wire[ 31:0] mult14;

wire[ 31:0] mult20;
wire[ 31:0] mult21;
wire[ 31:0] mult22;
wire[ 31:0] mult23;
wire[ 31:0] mult24;


wire[ 31:0] mult30;
wire[ 31:0] mult31;
wire[ 31:0] mult32;
wire[ 31:0] mult33;
wire[ 31:0] mult34;

wire[ 31:0] mult40;
wire[ 31:0] mult41;
wire[ 31:0] mult42;
wire[ 31:0] mult43;
wire[ 31:0] mult44;

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
            param_w_h0_arr      <=     {param_w_h0,param_w_h0_arr[ W_WIDTH*5-1:W_WIDTH]};//数据最初进来存到最高位，往右移存储,因此第0个权重参数值在
            param_w_h1_arr      <=     {param_w_h1,param_w_h1_arr[ W_WIDTH*5-1:W_WIDTH]};
            param_w_h2_arr      <=     {param_w_h2,param_w_h2_arr[ W_WIDTH*5-1:W_WIDTH]};
            param_w_h3_arr      <=     {param_w_h3,param_w_h3_arr[ W_WIDTH*5-1:W_WIDTH]};
            param_w_h4_arr      <=     {param_w_h4,param_w_h4_arr[ W_WIDTH*5-1:W_WIDTH]};//第4行权重
        end
end

//row_cnt 的时序，从第一行一直到23行////窗口滑动部分，这里读取到31完成了一行的扫描，然后换行
always@(posedge sclk or negedge s_rst_n)begin
        if (!s_rst_n)
            row_cnt            <=       'd0;
        else if (row_cnt == 'd23 && conv_flag == 'd1 && data_rd_addr == 'd31)//当到23行，地址读到31（此时结果有效结束），清零
            row_cnt            <=       'd0;
        else if (data_rd_addr == 'd31 && conv_flag == 'd1)//做完一行的卷积  总共向下滑动到23行
            row_cnt            <=       row_cnt + 1'd1;
end

//读RAM时序
always@(posedge sclk or negedge s_rst_n)begin//进行水平滑动0-31
        if(!s_rst_n)
            data_rd_addr       <=       'd0;
        else if (data_rd_addr == 'd31 && conv_flag == 1'd1)//根据时序图，读到address 为31 时滑动计算完一次，本来只有28个图像数据，但是多读的29，30，31的RAM数据是不影响计算的
            data_rd_addr       <=       'd0;                                    //==当data_rd_addr=6时：缓存列2-6形成第一个窗口==//
        else if (conv_flag == 1'd1)                                             //==当data_rd_addr=7时：输出第一个计算结果==//
            data_rd_addr       <=       data_rd_addr +1'd1;                     //==当data_rd_addr=31时：完成第24个水平位置计算，垂直下移一行==//
end
//缓存RAM读到的图像数据数据每个数据位宽[4：0]有5位
always@(posedge sclk or negedge s_rst_n)begin
        if(!s_rst_n)begin//读出来的数据缓存在这几个寄存器里
            col_data_r0           <=       'd0;
            col_data_r1           <=       'd0;
            col_data_r2           <=       'd0;
            col_data_r3           <=       'd0;
            col_data_r4           <=       'd0;
        end
        else
            col_data_r4           <=        col_data;//进行缓存，当ramADDR读到6时，5*5的图片像素矩阵缓存到这5个寄存器里（同时进行计算）
            col_data_r3           <=        col_data_r4;//ram'ADDR=7时得出计算的结果。从ADDR6到ADDR29一共滑动23次，进行24次计算，得到卷积后的第一行的结果
            col_data_r2           <=        col_data_r3;
            col_data_r1           <=        col_data_r2;
            col_data_r0           <=        col_data_r1;       
end

////////////////////////////////进行计算，调用乘法器IP////////////////////////////////////////////////
//这里是因为当读取r0[0]的时候数据为D0，因为移位寄存，r1[0]的数据是D1，依次倒推。

//第0行
mult_gen_0 mult_gen_U00(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r0[0]}}    ),//输入A   [7:0]   进行位宽对其，          //col_data_r0[0]本质是有符号数的最高位（类似温度计的±号）
        .B                      (param_w_h0_arr[W_WIDTH-1 :0]),//输入B   [17:0] 第0个权重存再最低位 //举例：当col_data_r0[0]=1，表示十进制-1（二进制补码），若直接补0会变成+1（00000001），导致错误
        .P                      (mult00                 )//输出[25:0]   P   
);

mult_gen_0 mult_gen_U01(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r1[0]}}    ),//输入A   [7:0]   进行位宽对其，          //col_data_r0[0]本质是有符号数的最高位（类似温度计的±号）
        .B                      (param_w_h0_arr[W_WIDTH*2-1 :W_WIDTH]),//输入B   [17:0] 第0个权重存再最低位 //举例：当col_data_r0[0]=1，表示十进制-1（二进制补码），若直接补0会变成+1（00000001），导致错误
        .P                      (mult01                 )//输出[25:0]   P   
);

mult_gen_0 mult_gen_U02(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r2[0]}}    ),//输入A   [7:0]   进行位宽对其，          //col_data_r0[0]本质是有符号数的最高位（类似温度计的±号）
        .B                      (param_w_h0_arr[W_WIDTH*3-1 :W_WIDTH*2]),//输入B   [17:0] 第0个权重存再最低位 //举例：当col_data_r0[0]=1，表示十进制-1（二进制补码），若直接补0会变成+1（00000001），导致错误
        .P                      (mult02                 )//输出[25:0]   P   
);

mult_gen_0 mult_gen_U03(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r3[0]}}    ),//输入A   [7:0]   进行位宽对其，          //col_data_r0[0]本质是有符号数的最高位（类似温度计的±号）
        .B                      (param_w_h0_arr[W_WIDTH*4-1 :W_WIDTH*3]),//输入B   [17:0] 第0个权重存再最低位 //举例：当col_data_r0[0]=1，表示十进制-1（二进制补码），若直接补0会变成+1（00000001），导致错误
        .P                      (mult03                 )//输出[25:0]   P   
);

mult_gen_0 mult_gen_U04(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r4[0]}}    ),//输入A   [7:0]   进行位宽对其，          //col_data_r0[0]本质是有符号数的最高位（类似温度计的±号）
        .B                      (param_w_h0_arr[W_WIDTH*5-1 :W_WIDTH*4]),//输入B   [17:0] 第0个权重存再最低位 //举例：当col_data_r0[0]=1，表示十进制-1（二进制补码），若直接补0会变成+1（00000001），导致错误
        .P                      (mult04                 )//输出[25:0]   P   
);

//第1行 1*5
mult_gen_0 mult_gen_U10(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r0[1]}}    ),//输入A   [7:0]
        .B                      (param_w_h1_arr[W_WIDTH-1 :0]),//输入B   
        .P                      (mult10                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U11(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r1[1]}}    ),//输入A   [7:0]
        .B                      (param_w_h1_arr[W_WIDTH*2-1 :W_WIDTH]),//
        .P                      (mult11                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U12(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r2[1]}}    ),//输入A   [7:0]
        .B                      (param_w_h1_arr[W_WIDTH*3-1 :W_WIDTH*2]),
        .P                      (mult12                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U13(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r3[1]}}    ),//输入A   [7:0]
        .B                      (param_w_h1_arr[W_WIDTH*4-1 :W_WIDTH*3]),
        .P                      (mult13                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U14(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r4[1]}}    ),//输入A   [7:0]
        .B                      (param_w_h1_arr[W_WIDTH*5-1 :W_WIDTH*4]),
        .P                      (mult14                 )//输出[25:0]   P
);

//第2行 

mult_gen_0 mult_gen_U20(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r0[2]}}    ),//输入A   [7:0]
        .B                      (param_w_h2_arr[W_WIDTH-1 :0]),//输入B   
        .P                      (mult20                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U21(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r1[2]}}    ),//输入A   [7:0]
        .B                      (param_w_h2_arr[W_WIDTH*2-1 :W_WIDTH]),//
        .P                      (mult21                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U22(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r2[2]}}    ),//输入A   [7:0]
        .B                      (param_w_h2_arr[W_WIDTH*3-1 :W_WIDTH*2]),
        .P                      (mult22                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U23(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r3[2]}}    ),//输入A   [7:0]
        .B                      (param_w_h2_arr[W_WIDTH*4-1 :W_WIDTH*3]),
        .P                      (mult23                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U24(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r4[2]}}    ),//输入A   [7:0]
        .B                      (param_w_h2_arr[W_WIDTH*5-1 :W_WIDTH*4]),
        .P                      (mult24                 )//输出[25:0]   P
);

//第3行
mult_gen_0 mult_gen_U30(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r0[3]}}    ),//输入A   [7:0]
        .B                      (param_w_h3_arr[W_WIDTH-1 :0]),//输入B   
        .P                      (mult30                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U31(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r1[3]}}    ),//输入A   [7:0]
        .B                      (param_w_h3_arr[W_WIDTH*2-1 :W_WIDTH]),//
        .P                      (mult31                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U32(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r2[3]}}    ),//输入A   [7:0]
        .B                      (param_w_h1_arr[W_WIDTH*3-1 :W_WIDTH*2]),
        .P                      (mult32                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U33(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r3[3]}}    ),//输入A   [7:0]
        .B                      (param_w_h3_arr[W_WIDTH*4-1 :W_WIDTH*3]),
        .P                      (mult33                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U34(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r4[3]}}    ),//输入A   [7:0]
        .B                      (param_w_h3_arr[W_WIDTH*5-1 :W_WIDTH*4]),
        .P                      (mult34                 )//输出[25:0]   P
);


//第4行



mult_gen_0 mult_gen_U40(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r0[4]}}    ),//输入A   [7:0]
        .B                      (param_w_h4_arr[W_WIDTH-1 :0]),//输入B   
        .P                      (mult40                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U41(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r1[4]}}    ),//输入A   [7:0]
        .B                      (param_w_h4_arr[W_WIDTH*2-1 :W_WIDTH]),//
        .P                      (mult41                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U42(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r2[4]}}    ),//输入A   [7:0]
        .B                      (param_w_h4_arr[W_WIDTH*3-1 :W_WIDTH*2]),
        .P                      (mult42                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U43(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r3[4]}}    ),//输入A   [7:0]
        .B                      (param_w_h4_arr[W_WIDTH*4-1 :W_WIDTH*3]),
        .P                      (mult43                 )//输出[25:0]   P
);

mult_gen_0 mult_gen_U44(
        .CLK                    (sclk                   ),
        .A                      ({8{col_data_r4[4]}}    ),//输入A   [7:0]
        .B                      (param_w_h4_arr[W_WIDTH*5-1 :W_WIDTH*4]),
        .P                      (mult44                 )//输出[25:0]   P
);
///////////////////////////////////////////////////////////////////////////
//conv_cnt卷积计数器，统计30个卷积核计算完成
always@(posedge sclk or negedge s_rst_n)begin
        if(!s_rst_n)
            conv_cnt        <=      'd0;
        else if (conv_flag == 'd0)
            conv_cnt        <=      'd0;
        else if(conv_flag == 'd1 && data_rd_addr == 'd31 && row_cnt == 'd23)//滑动23行后
            conv_cnt        <=      conv_cnt + 'd1;//切换下一个核
end

//求和加上偏执计算结果
always@(posedge sclk or negedge s_rst_n)begin
        if (!s_rst_n)
            conv_rslt       <=      'd0;
        else if (data_rd_addr >= 'd7 && data_rd_addr <= 'd30)begin//这个时间段开始进行计算，并且输出结果
            conv_rslt       <=      mult00 + mult01 + mult02 + mult03 + mult04 +
                                    mult10 + mult11 + mult12 + mult13 + mult14 +
                                    mult20 + mult21 + mult22 + mult23 + mult24 +
                                    mult30 + mult31 + mult32 + mult33 + mult34 +
                                    mult40 + mult31 + mult42 + mult43 + mult44 + param_bias;
        end
end
//结果输出时序
always @(posedge sclk or negedge s_rst_n) begin
        if(!s_rst_n)
            conv_rslt_act_vld       <=      1'b0;
        else if (data_rd_addr >= 'd7 && data_rd_addr <= 'd30)
            conv_rslt_act_vld       <=      1'b1;
        else
            conv_rslt_act_vld       <=      1'b0;
end

assign  conv_rslt_act       =       (conv_rslt[31] == 1'b0) ? conv_rslt : 0;// ReLU激活 


endmodule
