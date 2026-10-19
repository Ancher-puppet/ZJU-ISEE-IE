function [t_out, y_real_hist, y_est_hist] = func_control(cmd_idx)
% 输入: cmd_idx (指令ID)
% 输出: y_real_hist: 真实系统的位移;y_est_hist:  观测器估计的位移

    %% 1. 定义物理对象 (Mass-Spring-Damper)
    m = 1;      % 质量
    k = 15;     % 弹簧系数
    c = 2.5;    % 阻尼系数
    
    % 状态矩阵
    A = [0      1; 
        -k/m  -c/m];
    B = [0; 
         1/m];
    C = [1 0];  % 只能观测到位置(x1)，看不见速度(x2)
    D = 0;
    
    %% 2. 检查能控性和能观性
    if rank(ctrb(A,B)) < length(A)
        error('系统不可控 (Uncontrollable)');
    end
    if rank(obsv(A,C)) < length(A)
        error('系统不可观 (Unobservable) ');
    end

    %% 3. 设计控制器 K 和 观测器 L
    % 状态反馈增益 K
    desired_poles_ctrl = [-2, -3];
    K = place(A, B, desired_poles_ctrl);
    
    % 观测器增益 L 
    desired_poles_obs = [-10, -12];
    L = place(A', C', desired_poles_obs)'; 
    
    % 前馈增益
    s = size(A,1);
    Z = [zeros([1,s]) 1];
    N = inv([A,B;C,D])*Z';
    Nx = N(1:s); % 稳态状态
    Nu = N(1+s); % 稳态输入
    N_bar = Nu + K*Nx;

    %% 4. 仿真初始化
    dt = 0.001; 
    T_final = 4.0;   
    steps = floor(T_final / dt);
    
    x_real = [0; 0]; 
    x_hat = [0.5; 0]; 
    
    y_real_hist = zeros(steps, 1);
    y_est_hist  = zeros(steps, 1);
    t_out       = (0:steps-1)' * dt;
    
    %% 5. 仿真循环 
    for i = 1:steps
        t = i * dt;
        switch cmd_idx
            case 1 % Start: 阶跃信号
                r = 1.0; 
            case 2 % Stop: 归零
                r = 0.0;
            case 3 % Wave: 正弦波动
                r = 0.5 * sin(2*pi * 1.5 * t);
            otherwise
                r = 0;
        end
        
        % 测量
        y = C * x_real;
        
        % 控制器计算输入u
        u = -K * x_hat + N_bar * r;
        
        % 物理系统更新
        dx_real = A * x_real + B * u;
        x_real = x_real + dx_real * dt; 
        
        % 观测器更新
        y_est = C * x_hat; 
        dx_hat = A * x_hat + B * u + L * (y - y_est);
        x_hat = x_hat + dx_hat * dt; 
        
        y_real_hist(i) = y;
        y_est_hist(i)  = y_est;
    end
end