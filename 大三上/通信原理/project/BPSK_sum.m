clear; clc; close all;

%% 参数设置
Rb = 100;                   % 码元速率 100 bps
fc = 20000;                 % 载波频率 20 kHz
fs = 200000;                % 采样频率 200kHz
sps = fs / Rb;              % 每个码元的采样点数 = 2000
alpha = 0.3;                % 升余弦滚降系数
span = 6;                   % 滤波器截断长度

% 升余弦滤波器
filt_h = rcosdesign(alpha, span, sps, 'sqrt'); 

% 本地波形 g_T(t)
center_idx = ceil(length(filt_h)/2);
idx_range = (center_idx - sps/2) : (center_idx + sps/2 - 1);
g_T = filt_h(idx_range); 

% 发送滤波器带来的延迟
tx_delay = (span * sps) / 2;

%% TASK 1: 序列波形仿真
fprintf('TASK 1: 相关接收机\n');
bits_task1 = [0 0 0 1 1 1 0 1 1 1 0 1];
N_bits = length(bits_task1);

% a.基带成型滤波
symbols = bits_task1 * 2 - 1;
symbols_up = upsample(symbols, sps);
tx_baseband = conv(symbols_up, filt_h, 'full'); 

% b.BPSK 调制信号
t = (0:length(tx_baseband)-1)/fs;
carrier = cos(2*pi*fc*t);
tx_modulated = tx_baseband .* carrier;

snr_list_task1 = [-5, 5];

for i = 1:length(snr_list_task1)

    % c.叠加噪声
    current_snr = snr_list_task1(i);
    snr_channel = current_snr - 10*log10(sps) + 3;
    rx_signal = awgn(tx_modulated, snr_channel, 'measured');
    
    % 相干解调
    % 1. 乘法器：去载波
    rx_mixed = rx_signal .* carrier * 2; 
    
    decision_values = zeros(1, N_bits);
    for k = 1:N_bits
        start_index = tx_delay + (k-1)*sps - sps/2 + 1;
        end_index   = start_index + sps - 1;
        if end_index > length(rx_mixed)
            break; 
        end

        r_segment = rx_mixed(start_index : end_index);
        
        % 2. 乘法器：乘本地波形 g_T(t)
        multiplied_val = r_segment .* g_T;
        
        % 3. 积分器：积分 (0 到 T)
        % d.抽样时刻
        decision_values(k) = sum(multiplied_val); 
       
    end
    
    % e.检测判决
    rx_bits = decision_values > 0;
    [~, ber] = biterr(bits_task1, rx_bits);
    
    fprintf('[Task 1] SNR=%d dB, BER=%.4f\n', current_snr, ber);
    
    % 绘图
    figure('Name', sprintf('Task 1 Waveforms (SNR = %d dB)', current_snr));
    subplot(5,1,1); plot(t, tx_baseband, 'LineWidth', 1.2); title('(a) 发送端基带成型滤波输出 (Tx Baseband)'); 
    xlim([0, t(end)]); grid on;
    subplot(5,1,2); plot(t, tx_modulated); title('(b) BPSK调制信号'); 
    xlim([0, t(end)]); grid on;
    subplot(5,1,3); plot(t, rx_signal); title('(c) 叠加噪声后的信号'); 
    xlim([0, t(end)]); grid on;
    
    subplot(5,1,4); stem(1:N_bits, decision_values, 'r', 'filled', 'LineWidth', 1.2); 
    title('(d) 积分器输出判决变量'); xlim([0.5, N_bits+0.5]); 
    xticks(1:N_bits); 
    grid on;

    subplot(5,1,5); 
    stairs(0:N_bits, [rx_bits, rx_bits(end)], 'LineWidth', 1.5); 
    title(['(e) BPSK解调判决结果: ' num2str(rx_bits)]); 
    ylim([-0.2 1.2]); xlim([0, N_bits]); xticks(0:N_bits);
    grid on;
end

%% TASK 2: 文本传输
fprintf('\n TASK 2: 文本传输 \n');

fid = fopen('BPSK_SUM_Log.txt', 'w');

% 文本
text_str = ['The book is suitable for electronic specialties of engineering school in Chinese general institutions ' ...
            'of higher learning as the textbook or reference for the junior and senior students and graduate ' ...
            'students, and can also be used as a reference book or a textbook in the advanced study classes for ' ...
            'the engineering and technical personnel engaged in communication engineering.'];
ascii_vals = double(text_str);
bin_matrix = de2bi(ascii_vals, 8, 'left-msb');
tx_bits_task2 = reshape(bin_matrix', 1, [])';
N_bits_task2 = length(tx_bits_task2);

fprintf('正在写入文件: %s ...\n', 'BPSK_SUM_Log.txt');
fprintf(fid, '原始发送文本:\r\n%s\r\n\r\n', text_str);
fprintf(fid, '发送总比特数: %d bits\r\n', N_bits_task2);
fprintf(fid, '------------------------------------------------------\r\n');

% 发送端调制
symbols_2 = tx_bits_task2 * 2 - 1;
tx_baseband_2 = conv(upsample(symbols_2, sps), filt_h, 'full');

t2 = (0:length(tx_baseband_2)-1)/fs;
carrier2 = cos(2*pi*fc*t2)';
tx_mod2 = tx_baseband_2 .* carrier2;


snr_list2 = [-10, -5, 0, 5, 10];
ber_sim_record = zeros(size(snr_list2)); 

for i = 1:length(snr_list2)
    current_snr = snr_list2(i);
    snr_chan = current_snr - 10*log10(sps) + 3;
    rx_signal_2 = awgn(tx_mod2, snr_chan, 'measured');
    
    % 接收端解调
    % 1. 乘载波
    rx_mixed_2 = rx_signal_2 .* carrier2 * 2;
    rx_bits_out2 = zeros(N_bits_task2, 1);
    

    for k = 1:N_bits_task2
        start_idx = tx_delay + (k-1)*sps - sps/2 + 1;
        end_idx = start_idx + sps - 1;
        
        if end_idx > length(rx_mixed_2), break; end
        
        seg = rx_mixed_2(start_idx : end_idx);
        
        % 2. 乘本地参考波形 & 3. 积分
        metric = sum(seg .* g_T'); 
        
        % 4. 判决
        rx_bits_out2(k) = metric > 0;
    end
    
    % 计算误码率
    [~, ber] = biterr(tx_bits_task2, rx_bits_out2);
    ber_sim_record(i) = ber; 
    
    fprintf('[Task 2] Eb/N0 = %d dB | BER = %.5f\n', current_snr, ber);
    
    % 文本恢复
    try
        n_bytes = floor(length(rx_bits_out2) / 8);
        valid_len = n_bytes * 8;
        bits_reshaped = reshape(rx_bits_out2(1:valid_len), 8, [])';
        txt_out = char(bi2de(bits_reshaped, 'left-msb')');
    catch
        txt_out = '#Error#';
    end
    fprintf(fid, 'SNR: %d dB, BER: %.5f\nText: %s\n\n', current_snr, ber, txt_out);
end
fclose(fid);

%% 绘图部分
figure('Name', 'BPSK BER Performance');

% 1. 计算理论曲线，Pe = Q(sqrt(2 * Eb/N0))
fine_snr = linspace(min(snr_list2), max(snr_list2), 100); 
theory_ber = qfunc(sqrt(2 * 10.^(fine_snr/10)));

% 2. 理论曲线 
semilogy(fine_snr, theory_ber, 'k-', 'LineWidth', 1.5); hold on;

% 3. 实际仿真值
semilogy(snr_list2, ber_sim_record, 'bo--', 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', 'b');

grid on;
title('BPSK System BER Performance: Theory vs Simulation');
xlabel('E_b/N_0 (dB)');
ylabel('Bit Error Rate (BER)');
legend('Theoretical Value (理论值)', 'Simulation Value (仿真值)', 'Location', 'SouthWest');
axis([min(snr_list2) max(snr_list2) 1e-6 1]);
