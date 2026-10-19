function [stft, t, f] = mystft(x, fs, window_size, step, nfft)
    % Input：
    % x 输入的一维信号
    % fs 采样率
    % window_size 窗函数的长度
    % step 移动长度
    % nfft fft points

    % Output：
    % stft 二维矩阵，包含频域和时域信息
    % f 频域
    % t 时域

    N = length(x);
    % 帧数 即窗口数目
    num_frames = floor((N - window_size)/step) + 1;
    stft = zeros(nfft, num_frames); 

    % 矩形窗（无需额外生成，直接截取帧）
    for n = 0:num_frames-1
        frame = x(1 + n*step : n*step + window_size);
        frame = frame(:); %转为列向量
        % 调用 fft 进行傅里叶变换
        X = fft(frame, window_size);
        X = fftshift(X);
        stft(:, n+1) = X(1:nfft);
    end
    t = (window_size/2:step:window_size/2+(num_frames-1)*step)/fs;
    f = (-nfft/2:nfft/2-1)*(fs/nfft);
end