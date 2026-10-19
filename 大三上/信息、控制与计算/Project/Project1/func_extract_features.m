function features = func_extract_features(signal, fs)
% FUNC_EXTRACT_FEATURES 提取音频信号的关键特征
% 输入: signal - 音频信号向量, fs - 采样率
% 输出: features - [过零率, 谱质心] 的行向量

    % 1. 预处理：去直流与归一化
    signal = signal - mean(signal);
    if max(abs(signal)) > 0
        signal = signal / max(abs(signal));
    end

    % 2. 特征一：过零率 (Zero Crossing Rate)
    % 反映信号频率特性的简单指标
    zcr = mean(abs(diff(sign(signal)))) / 2;

    % 3. 特征二：谱质心 (Spectral Centroid)
    % 反映声音的"明亮"程度或频率分布中心
    L = length(signal);
    Y = fft(signal);
    P2 = abs(Y/L);
    P1 = P2(1:floor(L/2)+1); % 单边频谱
    f = fs*(0:(floor(L/2)))/L; % 频率轴
    
    % 计算加权平均频率 (防止分母为0加 eps)
    centroid = sum(f' .* P1) / (sum(P1) + eps);
    
    % 为了让两个特征数量级接近，对质心做归一化处理(除以采样率的一半)
    features = [zcr, centroid / (fs/2)];
end