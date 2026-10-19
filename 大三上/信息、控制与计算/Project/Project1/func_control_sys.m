function [t_out, u_out, y_out] = func_control_sys(cmd_idx)
% FUNC_CONTROL_SYS 模拟被控对象的响应
% 输入: cmd_idx - 识别出的指令ID (1:Start, 2:Stop, 3:Wave)
% 输出: 时间序列, 控制输入, 系统位移输出

    % 定义一个二阶物理系统 (例如: 弹簧-阻尼-质量系统)
    % 状态方程: x_dot = Ax + Bu, y = Cx + Du
    m = 1; k = 10; c = 2;
    A = [0 1; -k/m -c/m];
    B = [0; 1/m];
    C = [1 0];
    D = 0;
    
    sys = ss(A, B, C, D);
    
    % 定义仿真时间
    t_out = 0:0.01:5;
    u_out = zeros(size(t_out));
    
    % 根据指令生成控制信号 u(t)
    switch cmd_idx
        case 1 % 启动 -> 阶跃信号
            u_out(:) = 1; 
        case 2 % 停止 -> 零输入
            u_out(:) = 0;
        case 3 % 波动 -> 正弦输入
            u_out = 0.5 * sin(2*pi * 1.5 * t_out);
        otherwise
            u_out(:) = 0;
    end
    
    % 线性系统仿真
    y_out = lsim(sys, u_out, t_out);
end