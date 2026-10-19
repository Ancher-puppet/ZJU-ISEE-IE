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
filter_delay = (span * sps) / 2; % 发送滤波器延迟
total_filter_delay = span * sps;

%% TASK 1: 序列的波形绘制
fprintf(' TASK 1: 序列的波形绘制 \n');

bits_task1 = [0 0 0 1 1 1 0 1 1 1 0 1];
N_bits = length(bits_task1);

% a.基带成型滤波
% 映射为双极性码元
symbols = bits_task1 * 2 - 1; 
% 上采样
symbols_upsampled = upsample(symbols, sps);
tx_baseband = conv(symbols_upsampled, filt_h, 'full');

% b.BPSK 调制信号
t = (0:length(tx_baseband)-1)/fs;
carrier = cos(2*pi*fc*t);
tx_modulated = tx_baseband .* carrier;
% 调制信号频域图
figure('Name', sprintf('调制信号频域图'));
pwelch(tx_modulated,[],[],[],fs); title('调制信号频域图');

snr_list_task1 = [-5, 5];

for i = 1:length(snr_list_task1)

    % c.叠加噪声
    current_snr = snr_list_task1(i);
    % 补偿信道SNR，一方面是采样带来的，另一方面N0 是单边噪声功率密度
    snr_channel = current_snr - 10*log10(sps) + 3;
    rx_signal = awgn(tx_modulated, snr_channel, 'measured');
    
    % 相干解调
    rx_mixed = rx_signal .* carrier * 2;

    % 基函数匹配滤波器
    rx_filitered = conv(rx_mixed, filt_h, 'full');
    
    % d.抽样时刻
    % 最佳采样点 = 发送滤波器延迟 + 接收积分器延迟
    sample_start = total_filter_delay + 1;
    sample_idx = sample_start : sps : length(rx_filitered);
    if length(sample_idx) >= N_bits
        sample_idx = sample_idx(1:N_bits);
    end
    
    % e.检测判决
    decision_values = rx_filitered(sample_idx);
    rx_bits = decision_values > 0; 
    [~, ber] = biterr(bits_task1, rx_bits);

    disp(['Eb/N0 = ', num2str(current_snr), ' dB | 实际Channel SNR = ', num2str(snr_channel, '%.2f'), ' dB | BER = ', num2str(ber)]);
    
    % 绘图
    figure('Name', sprintf('Task 1 Waveforms (SNR = %d dB)', current_snr));
    subplot(5,1,1); plot(t, tx_baseband); title('(a) 发送端基带成型滤波输出 (Tx Baseband)'); xlim([0, t(end)]);
    subplot(5,1,2); plot(t, tx_modulated); title('(b) BPSK调制信号'); xlim([0, t(end)]);
    subplot(5,1,3); plot(t, rx_signal); title('(c) 叠加噪声后的信号'); xlim([0, t(end)]);
    
    subplot(5,1,4); plot(t, rx_filitered(1:length(t)), 'b'); hold on;
    stem(t(sample_idx), decision_values, 'r', 'filled'); 
    title('(d) 积分器输出判决变量'); xlim([0, t(end)]);
    
    subplot(5,1,5); stairs([rx_bits, rx_bits(end)], 'LineWidth', 1.5); 
    title(['(e) BPSK解调判决结果: ' num2str(rx_bits)]); ylim([-0.5 1.5]);
end

%% TASK 2: 文本传输
fprintf('\nTASK 2: 文本传输 \n');

% 1. 日志文件
log_filename = 'BPSK_Sample_Log.txt';
fid = fopen(log_filename, 'w'); 

% 2. 文本转比特
text_str = ['The book is suitable for electronic specialties of engineering school in Chinese general institutions ' ...
            'of higher learning as the textbook or reference for the junior and senior students and graduate ' ...
            'students, and can also be used as a reference book or a textbook in the advanced study classes for ' ...
            'the engineering and technical personnel engaged in communication engineering.'];

ascii_vals = double(text_str);
bin_matrix = de2bi(ascii_vals, 8, 'left-msb');
tx_bits_task2 = reshape(bin_matrix', 1, [])';
N_bits_task2 = length(tx_bits_task2);

fprintf('正在写入文件: %s ...\n', log_filename);
fprintf(fid, '原始发送文本:\r\n%s\r\n\r\n', text_str);
fprintf(fid, '发送总比特数: %d bits\r\n', N_bits_task2);
fprintf(fid, '------------------------------------------------------\r\n');

% 3. 发送端调制
symbols_2 = tx_bits_task2 * 2 - 1;
symbols_up_2 = upsample(symbols_2, sps);
tx_baseband_2 = conv(symbols_up_2, filt_h, 'full');

t2 = (0 : length(tx_baseband_2)-1) / fs;
carrier_2 = cos(2 * pi * fc * t2)';
tx_modulated_2 = tx_baseband_2 .* carrier_2;

snr_list_task2 = [-10, -5, 0, 5, 10];
ber_sim_record = zeros(size(snr_list_task2)); 

% 4. 解调并记录
for i = 1:length(snr_list_task2)
    curr_snr = snr_list_task2(i);
    curr_channel_snr = curr_snr - 10*log10(sps) + 3;
    rx_signal_2 = awgn(tx_modulated_2, curr_channel_snr, 'measured');

    rx_mixed_2 = rx_signal_2 .* carrier_2 *2;
    rx_filtered_2 = conv(rx_mixed_2, filt_h, 'full');
    
    % 采样时刻
    sample_start_2 = total_filter_delay + 1;
    sample_idx_2 = sample_start_2 : sps : (sample_start_2 + (N_bits_task2-1)*sps);

    valid_idx = sample_idx_2 <= length(rx_filtered_2);
    sample_idx_2 = sample_idx_2(valid_idx);
    
    decisions_2 = rx_filtered_2(sample_idx_2);
    rx_bits_out = double(decisions_2 > 0);
    
    % 误码率
    len_comp = min(length(tx_bits_task2), length(rx_bits_out));
    error_count = sum(abs(tx_bits_task2(1:len_comp) - rx_bits_out(1:len_comp)));
    ber = error_count / len_comp;
    ber_sim_record(i) = ber; 
    
    % 恢复文本
    try
        bits_reshaped = reshape(rx_bits_out(1:floor(len_comp/8)*8), 8, [])';
        rx_ascii = bi2de(bits_reshaped, 'left-msb');
        rx_text = char(rx_ascii');
    catch
        rx_text = '#结构错误#';
    end
    

    fprintf('[Eb/N0 = %d dB] 实际Channel SNR: %.2f dB | BER: %.4f\n', curr_snr, curr_channel_snr, ber);  
    fprintf(fid, '[Eb/N0 = %d dB] 实际Channel SNR: %.2f dB | BER: %.6f\r\n%s\r\n\r\n', curr_snr, curr_channel_snr, ber, rx_text);
    fprintf(fid, '误码率 (BER): %.6f\r\n', ber);
    fprintf(fid, '解调完整文本:\r\n%s\r\n', rx_text); 
    fprintf(fid, '------------------------------------------------------\r\n\r\n');
end
% 5. 关闭文件
fclose(fid);

%% 绘图部分
figure('Name', 'BPSK Matched Filter BER Performance');

% 1. 计算理论BER: Pe = Q(sqrt(2 * Eb/N0))
fine_snr = linspace(min(snr_list_task2), max(snr_list_task2), 100);
theory_ber = qfunc(sqrt(2 * 10.^(fine_snr/10)));

% 2. 理论曲线
semilogy(fine_snr, theory_ber, 'k-', 'LineWidth', 1.5); hold on;

% 3. 绘制实际仿真值 (蓝色圆点虚线)
semilogy(snr_list_task2, ber_sim_record, 'bo--', 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', 'b');

grid on;
title('BPSK System (Matched Filter) BER Performance');
xlabel('E_b/N_0 (dB)');
ylabel('Bit Error Rate (BER)');
legend('Theoretical Value (理论值)', 'Simulation Value (仿真值)', 'Location', 'SouthWest');
axis([min(snr_list_task2) max(snr_list_task2) 1e-6 1]); 
