function [rx_bits, debug_data] = func_mod_channel(tx_bits, snr_db)
% FUNC_MOD_CHANNEL 

    %% 1. 参数
    Rb = 10000; Fc = 40000; Fs = 160000; sps = Fs / Rb;
    
    %% 2. 调制
    bipolar_msg = 2*tx_bits - 1;
    tx_baseband = repelem(bipolar_msg, sps);
    
    t = (0:length(tx_baseband)-1)' / Fs; 
    carrier = cos(2*pi*Fc*t);
    tx_passband = tx_baseband .* carrier;
    
    %% 3. AWGN 信道
    sig_power = 0.5; % 余弦波振幅1时功率0.5
    noise_power = sig_power / (10^(snr_db/10));
    noise = sqrt(noise_power) * randn(size(tx_passband));
    rx_passband = tx_passband + noise;
    
    %% 4. 相干解调
    rx_mixed = rx_passband .* carrier * 2; 
    [b, a] = butter(5, (1.5 * Rb) / (Fs/2)); 
    rx_filtered = filtfilt(b, a, rx_mixed);% 零相位滤波器，不会带来抽样的时延
    
    %% 5. 抽样判决
    sample_indices = round(sps/2 : sps : length(rx_filtered));
    rx_sampled = rx_filtered(sample_indices);
    
    rx_bits = zeros(size(tx_bits));
    rx_bits(rx_sampled > 0) = 1; 
    
    debug_data.tx_passband = tx_passband;     % 发送波形
    debug_data.rx_passband = rx_passband;     % 接收波形
    debug_data.rx_constellation = rx_sampled; % 星座图采样点
end