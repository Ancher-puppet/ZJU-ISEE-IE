function [recovered_signal, num_errs, final_bits] = func_info_decoding(rx_bits)
% 输出：
% recovered_signal：Huffman解码+逆PCM得到的电平信号
% final_bits：信道解码得到的纠正信号
    %% 1. 帧同步与信道解码
    % 1.Barker-13 码模板
    header_template = [1; 1; 1; 1; 1; 0; 0; 1; 1; 0; 1; 0; 1];
    
    % 寻找帧头
    rx_bipolar = 2*rx_bits - 1;
    head_bipolar = 2*header_template - 1;
    [correlation, lags] = xcorr(rx_bipolar, head_bipolar);
    
    % 找到相关性最大位置
    corr_threshold = 10; 
    candidate_indices = find(correlation > corr_threshold);
    if isempty(candidate_indices)
        warning('帧同步失败：未找到有效帧头。');
        recovered_signal = zeros(100,1); num_errs = 0; final_bits=[]; return;
    end
    
    % 在候选点中，找到 lag 最接近 0 的
    valid_candidates = candidate_indices(lags(candidate_indices) >= 0);
    
    if isempty(valid_candidates)
        [~, best_idx_in_candidates] = min(abs(lags(candidate_indices)));
        max_idx = candidate_indices(best_idx_in_candidates);
    else
        [~, best_idx_in_candidates] = min(lags(valid_candidates));
        max_idx = valid_candidates(best_idx_in_candidates);
    end
    
    peak_lag = lags(max_idx);
    fprintf('   [调试] 帧同步峰值: %f, 位置Lag: %d\n', correlation(max_idx), peak_lag);
    
    % 计算起始索引
    start_idx = peak_lag + 1; 
    payload_start_idx = start_idx + length(header_template);
    
    % 边界检查
    if payload_start_idx > length(rx_bits) || start_idx < 1
        warning('帧同步失败：无法定位数据头。输出静音。');
        recovered_signal = zeros(100,1); 
        num_errs = 0; 
        return;
    end
    
    raw_payload = rx_bits(payload_start_idx : end);
    
    % 2.汉明解码
    n_blocks = floor(length(raw_payload) / 7);
    valid_len = n_blocks * 7;
    rx_payload_aligned = raw_payload(1 : valid_len);
    
    if isempty(rx_payload_aligned)
        warning('数据为空。'); recovered_signal = zeros(100,1); num_errs = 0; return;
    end

    % 生成校验矩阵 H
    H = [1 0 0 1 1 0 1; 0 1 0 1 0 1 1; 0 0 1 0 1 1 1];
    rx_blocks = reshape(rx_payload_aligned, 7, n_blocks)';
    
    % 计算伴随式 & 纠错
    S = mod(rx_blocks * H', 2);
    syndrome_idx = S * [4; 2; 1];
    col_vals = [4 2 1 6 5 3 7]; 
    
    rx_corrected = rx_blocks; 
    num_errs = 0;

    for i = 1:n_blocks
        syn = syndrome_idx(i);
        if syn ~= 0
            err_pos = find(col_vals == syn);
            if ~isempty(err_pos)
                rx_corrected(i, err_pos) = ~rx_corrected(i, err_pos);
                num_errs = num_errs + 1;
            end
        end
    end
    
    % 提取数据位
    decoded_msg = rx_corrected(:, 4:7); 
    total_stream = reshape(decoded_msg', [], 1);

    %% 2. 解析协议包：[模式位] + [数据长度] + [DictHeader] + [HuffPayload]
    current_idx = 1;
    
    % 1. 读取模式位
    if length(total_stream) < 17
         warning('数据包太短，无法解析头部。');
         recovered_signal = zeros(100,1); return;
    end
    
    mode_bit = total_stream(current_idx);
    current_idx = current_idx + 1;
    
    % 2. 读取数据长度
    len_bits = total_stream(current_idx : current_idx+15);
    data_len = bi2de(len_bits', 'left-msb'); 
    current_idx = current_idx + 16;
    symbols = 0:255;
    
    % 3. 重建字典
    if mode_bit == 0
        % 静态模式 (Static)
        fprintf('   [Huffman解码] 模式: Static\n');
        
        x_axis = linspace(-3, 3, 256);
        pdf_sim = exp(-x_axis.^2) + linspace(0, 1e-10, 256);        
        p = pdf_sim / sum(pdf_sim);
        dict = huffmandict(symbols, p);
        
    else
        % 自适应模式 (Adaptive)
        fprintf('   [Huffman解码] 模式: Adaptive\n');
        
        % 读取字典头 (256个计数值 * 8bit = 2048 bits)
        dict_len = 256 * 8;
        if current_idx + dict_len > length(total_stream)
             warning('数据包残缺，无法读取自适应字典。');
             recovered_signal = zeros(100,1); return;
        end
        
        dict_bits = total_stream(current_idx : current_idx + dict_len - 1);
        current_idx = current_idx + dict_len;
        
        % 重组计数
        dict_mat = reshape(dict_bits, 8, 256)';
        rx_counts = bi2de(dict_mat, 'left-msb'); 
        rx_counts(rx_counts==0) = 1; % 防止0概率
        
        p = rx_counts / sum(rx_counts);
        dict = huffmandict(symbols, p);
    end
    
    % 4. 提取 Huffman 数据
    if current_idx + data_len - 1 > length(total_stream)
        huff_bits = total_stream(current_idx : end);
    else
        huff_bits = total_stream(current_idx : current_idx + data_len - 1);
    end
    
    %% C. 信源解码与恢复
    % Huffman 解码
    dsig_indices = huffmandeco(huff_bits, dict);
    
    % PCM 反量化
    min_val = -1; max_val = 1; L = 256;
    delta = (max_val - min_val) / L;
    recovered_signal = dsig_indices * delta + min_val + delta/2;

    final_bits = total_stream;
end