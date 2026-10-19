function energies = my_goertzel(x, target_freqs, fs)
% 输入:
%   x:            输入的音频信号片段
%   target_freqs: 目标频率列表
%   fs:           采样率
% 输出:
%   energies:     对应每个目标频率的能量值 |X(k)|^2

    N = length(x);
    energies = zeros(size(target_freqs));
    
    for i = 1:length(target_freqs)
        f0 = target_freqs(i);
        
        % 1: 计算 DFT 索引 k = N * f / fs
        k = round(N * f0 / fs);
        
        % 2: 计算滤波器系数，2cos(2*pi*k/N) [cite: 165]
        w = 2 * pi * k / N;
        coeff = 2 * cos(w);
        
        % 3: 迭代计算 (IIR 滤波器) ---
        % 初始化状态
        vk_1 = 0; 
        vk_2 = 0; 
        
        % 差分方程 v_k(n) = coeff*v_k(n-1) - v_k(n-2) + x(n) 
        for n = 1:N
            val = x(n) + coeff * vk_1 - vk_2;
            % 更新
            vk_2 = vk_1;
            vk_1 = val;
        end
        
        % 4: 计算最终能量，为了避免复数运算，直接计算幅度平方 |X(k)|^2
        energy = vk_1^2 + vk_2^2 - coeff * vk_1 * vk_2;
        
        energies(i) = energy;
    end
end