function [rx_signal, tx_signal] = func_channel_trans(raw_signal, snr_db)
% FUNC_CHANNEL_TRANS 模拟完整的通信链路 (含 A-law 压缩 + BPSK 调制解调)
% 输入: raw_signal - 原始语音, snr_db - 信噪比
% 输出: rx_signal - 接收解压信号, tx_signal - 发送出的调制信号

    %% 1. 信源编码：A-law 压缩 (Companding)
    A = 87.6; 
    % 归一化防止过载
    max_val = max(abs(raw_signal));
    if max_val == 0, max_val = 1; end
    x = raw_signal / max_val; 
    
    % A-law 压缩公式
    y = zeros(size(x));
    idx = abs(x) < (1/A);
    y(idx) = A * abs(x(idx)) / (1 + log(A));
    y(~idx) = (1 + log(A*abs(x(~idx)))) / (1 + log(A));
    companded_sig = sign(x) .* y;
    
    %% 2. 调制：BPSK (Binary Phase Shift Keying)
    % 注意：标准的 BPSK 通常处理二进制比特流。
    % 但为了模拟模拟语音传输，这里我们用 BPSK 的思想：
    % 将幅度映射到载波幅度或直接作为基带信号传输（模拟 BPSK 符号流）
    % 为了符合大作业"调制"的要求，我们把信号乘以高频载波
    
    fs = 8000;             % 采样率
    fc = 3000;             % 载波频率 3kHz (需小于 fs/2)
    t = (0:length(x)-1) / fs;
    
    % 抑制载波双边带调制 (DSB-SC) - 模拟 BPSK 的频谱搬移效果
    % 原始信号 x(t) 搬移到 carrier
    carrier = cos(2*pi*fc*t);
    modulated_sig = companded_sig .* carrier;
    
    tx_signal = modulated_sig; % 这就是发送到信道的信号
    
    %% 3. 信道传输：AWGN (加性高斯白噪声)
    % 信号经过噪声信道
    noisy_sig = awgn(tx_signal, snr_db, 'measured');
    
    %% 4. 解调：相干解调 (Coherent Demodulation)
    % 乘以同频同相的载波
    demod_temp = noisy_sig .* carrier;
    
    % 低通滤波 (Low Pass Filter) 去除倍频分量
    % 设计一个简单的巴特沃斯低通滤波器，截止频率 2000Hz
    [b, a] = butter(5, 2000/(fs/2)); 
    demodulated_sig = filtfilt(b, a, demod_temp);
    
    % 幅度修正 (乘以2是因为相干解调会有 1/2 的衰减)
    demodulated_sig = demodulated_sig * 2;
    
    %% 5. 信源解码：A-law 解压 (Expansion)
    % 防止噪声导致的幅度越界
    demodulated_sig(demodulated_sig > 1) = 1;
    demodulated_sig(demodulated_sig < -1) = -1;
    
    z = zeros(size(demodulated_sig));
    y_rx = abs(demodulated_sig);
    idx_rx = y_rx < (1/(1+log(A)));
    
    z(idx_rx) = y_rx(idx_rx) * (1+log(A)) / A;
    z(~idx_rx) = (exp(y_rx(~idx_rx)*(1+log(A)) - 1)) / A;
    
    rx_signal = sign(demodulated_sig) .* z;
    
    % 恢复原始幅度量级
    rx_signal = rx_signal * max_val;
end