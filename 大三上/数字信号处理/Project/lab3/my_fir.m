function h = my_fir(N, wc, type, win_type)
% MY_FIR_ADVANCED  支持多种窗函数的 FIR 设计
%   h = my_fir(N, wc, type, win_type)
%   输入:
%       win_type : 'rect', 'hamming', 'hanning', 'blackman'

    % 1. 基础参数
    tau = N / 2;
    n = 0 : N;
    h_d = zeros(1, length(n));
    
    % 2. 生成窗函数 w(n)
    switch lower(win_type)
        case 'rect'
            win = ones(1, length(n));
            
        case 'hamming'
            win = 0.54 - 0.46 * cos(2 * pi * n / N);
            
        case 'hanning'
            win = 0.5 - 0.5 * cos(2 * pi * n / N);
            
        case 'blackman'
            win = 0.42 - 0.5 * cos(2*pi*n/N) + 0.08 * cos(4*pi*n/N);
            
        otherwise
            error('未知的窗函数类型');
    end
    
    % 3. 计算理想脉冲响应 h_d(n)
    switch type
        case 'low'
            omega_c = wc * pi;
            for i = 1:length(n)
                if abs(n(i) - tau) < 1e-10
                    h_d(i) = omega_c / pi;
                else
                    h_d(i) = sin(omega_c * (n(i) - tau)) / (pi * (n(i) - tau));
                end
            end
            
        case 'bandpass'
            omega_L = wc(1) * pi;
            omega_H = wc(2) * pi;
            for i = 1:length(n)
                if abs(n(i) - tau) < 1e-10
                    h_d(i) = (omega_H - omega_L) / pi;
                else
                    val_H = sin(omega_H * (n(i) - tau)) / (pi * (n(i) - tau));
                    val_L = sin(omega_L * (n(i) - tau)) / (pi * (n(i) - tau));
                    h_d(i) = val_H - val_L;
                end
            end
    end
    
    % 4. 加窗
    h = h_d .* win;
end