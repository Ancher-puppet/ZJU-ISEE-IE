clear; clc; close all;

%% 1. 系统参数设置
Rb = 100;                   % 码元速率
fc = 20000;                 % 载波频率
fs = 200000;                % 采样频率
sps = fs / Rb;              % 采样点数/符号 = 2000
alpha = 0.3;                % 滚降系数
span = 6;                   % 滤波器长度 (符号数)

% 生成 SRRC 滤波器 (用于发送端成型 和 接收端参考波形)
filt_h = rcosdesign(alpha, span, sps, 'sqrt'); 

% 接收端的“本地参考波形” g_T(t)
center_idx = ceil(length(filt_h)/2);
idx_range = (center_idx - sps/2) : (center_idx + sps/2 - 1);
g_T = filt_h(idx_range); 

% 发送滤波器带来的延迟
tx_delay = (span * sps) / 2;

%% TASK 1: 序列波形仿真
fprintf('TASK 1: 相关接收机\n');
bits = [0 0 0 1 1 1 0 1 1 1 0 1];
N_bits = length(bits);

% --- 发送端 (保持标准 SRRC 发送，不变) ---
symbols = bits * 2 - 1;
symbols_up = upsample(symbols, sps);
tx_baseband = conv(symbols_up, filt_h, 'full'); % 发送端必须用卷积产生波形

t = (0:length(tx_baseband)-1)/fs;
carrier = cos(2*pi*fc*t);
tx_modulated = tx_baseband .* carrier;

snr_list = [-5, 5];

for i = 1:length(snr_list)
    curr_snr = snr_list(i);
    snr_channel = curr_snr - 10*log10(sps) + 3;
    rx_signal = awgn(tx_modulated, snr_channel, 'measured');
    
    % 1. 乘法器：去载波
    rx_baseband_raw = rx_signal .* carrier * 2; 
    
    decision_values = zeros(1, N_bits);
    
    % 循环处理每一个比特 (模拟积分清除的过程)
    for k = 1:N_bits
        start_index = tx_delay + (k-1)*sps - sps/2 + 1;
        end_index   = start_index + sps - 1;
        
        % 防止索引越界
        if end_index > length(rx_baseband_raw)
            break; 
        end
        % 取出这一段接收信号 r(t)
        r_segment = rx_baseband_raw(start_index : end_index);
        
        % 2. 乘法器 2：乘本地波形 g_T(t)
        multiplied_val = r_segment .* g_T;
        
        % 3. 积分器：积分 (0 到 T)
        % 对应框图里的积分符号。离散中 Sum 代替 Integral
        decision_values(k) = sum(multiplied_val); 
       
    end
    
    % 4. 判决
    rx_bits_out = decision_values > 0;
    [~, ber] = biterr(bits, rx_bits_out);
    
    fprintf('[Task 1] SNR=%d dB, BER=%.4f\n', curr_snr, ber);
    
    % 绘图验证
    if i == 2 % 只画 SNR=5dB 的
        figure('Name', 'Task 1 Correlation Receiver');
        subplot(3,1,1); plot(rx_baseband_raw); title('1. 去载波后的信号 (Raw Baseband)'); xlim([0, 25000]);
        subplot(3,1,2); plot(decision_values, 'o-'); title('3. 积分器输出值 (Z)'); grid on;
        subplot(3,1,3); stem(rx_bits_out, 'filled'); title('4. 判决结果'); ylim([-0.5 1.5]);
    end
end

%% TASK 2: 文本传输 (完全相同的架构)
fprintf('\n=== TASK 2: 文本传输 ===\n');
text_str = 'The book is suitable for electronic specialties...'; % (缩略)
ascii_vals = double(text_str);
bin_matrix = de2bi(ascii_vals, 8, 'left-msb');
bits_task2 = reshape(bin_matrix', 1, [])';
N_bits2 = length(bits_task2);

% 发送
symbols2 = bits_task2 * 2 - 1;
tx_bb2 = conv(upsample(symbols2, sps), filt_h, 'full');
t2 = (0:length(tx_bb2)-1)/fs;
carrier2 = cos(2*pi*fc*t2)';
tx_mod2 = tx_bb2 .* carrier2;

snr_list2 = [-10, -5, 0, 5, 10];
fid = fopen('BPSK_Correlation_Log.txt', 'w');

for i = 1:length(snr_list2)
    curr_snr = snr_list2(i);
    snr_chan = curr_snr - 10*log10(sps) + 3;
    rx_sig2 = awgn(tx_mod2, snr_chan, 'measured');
    
    % --- 接收端 (相关器架构) ---
    % 1. 乘载波
    rx_demod2 = rx_sig2 .* carrier2 * 2;
    
    rx_bits_out2 = zeros(N_bits2, 1);
    
    % 逐比特循环
    for k = 1:N_bits2
        s_idx = tx_delay + (k-1)*sps - sps/2 + 1;
        e_idx = s_idx + sps - 1;
        if e_idx > length(rx_demod2), break; end
        
        seg = rx_demod2(s_idx : e_idx);
        
        % 2. 乘本地参考波形 & 3. 积分
        % Z = sum( r(t) * g(t) )
        metric = sum(seg .* g_T'); % 注意 g_T 转置以匹配维度
        
        % 4. 判决
        rx_bits_out2(k) = metric > 0;
    end
    
    % 误码率
    [~, ber] = biterr(bits_task2, rx_bits_out2);
    fprintf('[Task 2] Eb/N0 = %d dB | BER = %.5f\n', curr_snr, ber);
    
    % 文本恢复
    try
        tmp = reshape(rx_bits_out2(1:floor(length(rx_bits_out2)/8)*8), 8, [])';
        txt_out = char(bi2de(tmp, 'left-msb')');
    catch
        txt_out = '#Error#';
    end
    fprintf(fid, 'SNR: %d dB, BER: %.5f\nText: %s\n\n', curr_snr, ber, txt_out);
end
fclose(fid);