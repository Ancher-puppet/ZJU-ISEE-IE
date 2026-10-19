function feat = func_extract_features(sig, fs)
% 输入: sig (信号向量), fs (采样率)
% 输出: feat (1x3 向量)
    sig = sig(:);
    % 1. 预处理，去掉开头结尾极小的静音
    sig = sig - mean(sig);
    threshold = 0.05 * max(abs(sig));
    active_idx = find(abs(sig) > threshold);
    if ~isempty(active_idx)
        sig = sig(active_idx(1):active_idx(end));
    end
    
    % 补零防止报错
    if length(sig) < 100
        feat = [0, 0, 0]; 
        return; 
    end

    % 特征 1: 过零率
    zcr = mean(abs(diff(sign(sig)))) / 2;
    
    % 频谱
    L = length(sig);
    Y = abs(fft(sig)); 
    P1 = Y(1:floor(L/2)+1); 
    f = fs * (0:floor(L/2)) / L;
    total_energy = sum(P1) + eps;

    % 特征 2: 归一化谱质心
    centroid = sum(f' .* P1) / total_energy;
    norm_centroid = centroid / (fs/2);
    
    % 特征 3: 高频能量占比
    % 'Stop' 的 's' 音通常在 2000Hz 以上有大量能量，'Go' 的能量主要集中在 1000Hz 以下
    high_freq_idx = f > 2000; 
    high_energy = sum(P1(high_freq_idx));
    high_freq_ratio = high_energy / total_energy;
    
    % 输出特征
    feat = [zcr, norm_centroid, high_freq_ratio];
end