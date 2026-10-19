function [encoded_stream, quantized_sig, raw_bits_padded] = func_info_coding(signal, mode_type)
% 输出：
% 结构为：[模式位] + [长度] + [字典头] + [Huffman编码数据]
% encoded_stream (tx_bits):加汉明码校验位，发送的数据
% raw_bits_padded (tx_ref):没有加汉明码校验位的原始数据，只进行了补0为7的倍数

    if nargin < 2
        mode_type = 'static'; % 默认静态
    end

    %% 1. PCM 量化
    min_val = -1; max_val = 1; L = 256;
    delta = (max_val - min_val) / L;
    
    q_indices = floor((signal - min_val) / delta);
    q_indices(q_indices < 0) = 0; 
    q_indices(q_indices > L-1) = L-1;
    quantized_sig = q_indices * delta + min_val + delta/2;

    symbols = 0:255;

    %% 2. 生成字典与头部信息
    dict_header_bits = []; % 初始化为空
    
    if strcmp(mode_type, 'static')
        % 模式0: 静态高斯字典
        fprintf('   [Huffman编码] 模式: Static (通用高斯模型)\n');
        mode_bit = 0; 
        
        % 构造高斯分布
        x_axis = linspace(-3, 3, 256);
        pdf_sim = exp(-x_axis.^2) + linspace(0, 1e-10, 256); 
        p = pdf_sim / sum(pdf_sim);
        dict = huffmandict(symbols, p);

    else
        % 模式1: 自适应字典
        fprintf('   [Huffman编码] 模式: Adaptive (统计当前信号)\n');
        mode_bit = 1; % 标志位
        
        % 统计频次
        raw_counts = histcounts(q_indices, -0.5:255.5);
        raw_counts = raw_counts + 1;
        
        % 归一化并生成字典头
        max_c = max(raw_counts);
        norm_counts = round(raw_counts / max_c * 255);
        norm_counts(norm_counts == 0) = 1; 
        
        p = norm_counts / sum(norm_counts); 
        dict = huffmandict(symbols, p);
        
        % 生成字典头
        dict_header_mat = decimalToBinaryVector(norm_counts, 8);
        dict_header_bits = reshape(dict_header_mat', [], 1);
    end
    
    %% 3. Huffman 编码
    huff_bits = huffmanenco(q_indices, dict);

    % 计算压缩效率
    original_bits_len = length(q_indices) * 8;
    compressed_bits_len = length(huff_bits);
    fprintf('   [信源编码] 原始: %d bits -> Huffman: %d bits (压缩率: %.2f%%)\n', ...
        original_bits_len, compressed_bits_len, (1-compressed_bits_len/original_bits_len)*100);
    
    %% 4. 构建数据包
    % 结构: [模式] + [数据长度] + [dict] + [payload]
    
    % 模式标志
    header_mode = mode_bit; 
    % 有效数据长度
    len_val = length(huff_bits);
    header_len = decimalToBinaryVector(len_val, 16)';
    % 拼接
    raw_bits = [header_mode; header_len; dict_header_bits; huff_bits];
    
    %% 5. 信道编码 (汉明码 7,4)
    n_pads = mod(4 - mod(length(raw_bits), 4), 4);
    if n_pads == 4, n_pads = 0; end  
    raw_bits_padded = [raw_bits; zeros(n_pads, 1)];
    msg_blocks = reshape(raw_bits_padded, 4, [])';
    % 生成矩阵 G
    G = [1 1 0 1 0 0 0; 1 0 1 0 1 0 0; 0 1 1 0 0 1 0; 1 1 1 0 0 0 1];
    
    code_blocks = mod(msg_blocks * G, 2);
    payload_stream = reshape(code_blocks', [], 1);
    
    %% 6. 添加帧同步头
    barker_code = [1; 1; 1; 1; 1; 0; 0; 1; 1; 0; 1; 0; 1];
    % 最终输出
    encoded_stream = [barker_code; payload_stream];
    
    preamble = zeros(32, 1);
    encoded_stream = [preamble; barker_code; payload_stream];
    
    fprintf('   [帧结构] 添加前导保护(32bit) + 同步头(13bit) + 数据(%dbit)\n', length(payload_stream));
end