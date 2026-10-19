clc; clear; close all;

% 参数
window_size = 2048;             % FFT窗口长度
step = window_size * 0.75;      % 帧移
nfft = window_size;             % FFT点数
smooth_window = 3;              % 平滑窗口
freq_range = [0, 2000];         % 频率范围
num_bands = 20;                 % 频率段数
y_imit = 0.1;                   % Y轴上限
pause_time = 0.01;              % 动画暂停时间
frame_skip = 1;                 % 帧跳过

% 读取音频文件
[x, fs] = audioread('GEM.mp3');
x = mean(x, 2);
% 音频信号 stft
figure(1);
[stft, t, f] = mystft(x, fs, window_size, step, nfft);
imagesc(t, f, abs(stft));
xlabel('时间(s)'); ylabel('频率(Hz)');
axis([0,length(x)/fs,-2000,2000]);
title(['STFT时频图（窗口大小=', num2str(window_size), '）']);
colorbar;

% 计算频率段范围
band_width = (freq_range(2) - freq_range(1)) / num_bands;
freq_bands = zeros(num_bands, 2);
for i = 1:num_bands
    freq_bands(i, 1) = freq_range(1) + (i - 1)*band_width;
    freq_bands(i, 2) = freq_range(1) + i*band_width;
end

% 创建音频播放器
player = audioplayer(x, fs);
play(player);

fig = figure('Name', '音乐时频可视化', 'Color', 'white', 'Position', [100, 100, 800, 600]);
ax = axes('Parent', fig);
bars = bar(ax, zeros(num_bands, 1), 'FaceColor', [0.2, 0.5, 0.8], 'BarWidth', 0.9);
hold on;

% 设置坐标轴范围
xlabel('频率段（Hz）', 'FontSize', 10);
ylabel('频谱幅度', 'FontSize', 10);
title_text = sprintf('实时频谱显示 (Y轴上限: %.2f, 刷新间隔: %.2fs)', y_imit, pause_time);
title(title_text, 'FontSize', 12);

ylim([0, y_imit]);

band_labels = arrayfun(@(i) sprintf('%.0f-%.0f Hz', freq_bands(i, 1), freq_bands(i, 2)), 1:num_bands, 'UniformOutput', false);
xticks(1:num_bands);
xticklabels(band_labels);
xtickangle(45);
xlim([0.5, num_bands + 0.5]);
grid on;

% 计算总帧数和实际需要处理的帧数
num_total_frames = floor((length(x) - window_size) / step) + 1;
num_processed_frames = ceil(num_total_frames / frame_skip);
estimated_process_time = 0;

% 主循环
frame_counter = 0;
processed_frames = 0;

% 音频播放开始时间
start_time = tic;

while isplaying(player) || toc(start_time) < (length(x)/fs)
    current_time = toc(start_time);
    expected_frame = floor(current_time * fs / step);

    if expected_frame >= frame_counter * frame_skip
        frame_counter = frame_counter + 1;
        n = (frame_counter - 1) * frame_skip;

        if n >= num_total_frames
            break;
        end

        frame_start = 1 + n * step;
        frame_end = n * step + window_size;

        if frame_end > length(x)
            break;
        end

        frame = x(frame_start:frame_end);
        frame = frame(:);

        % 计算FFT
        X = fft(frame, nfft);
        mag = abs(X) / nfft;
        freq_axis = fs * (0:nfft / 2) / nfft;
        mag = mag(1:nfft / 2 + 1);

        % 平滑处理
        if length(mag) >= smooth_window
            mag_smooth = smoothdata(mag, 'movmean', smooth_window);
        else
            mag_smooth = mag;
        end

        % 分频段计算
        band_amplitudes = zeros(num_bands, 1);
        for i = 1:num_bands
            idx = (freq_axis >= freq_bands(i, 1)) & (freq_axis <= freq_bands(i, 2));
            if any(idx)
                band_amplitudes(i) = mean(mag_smooth(idx));
            else
                band_amplitudes(i) = 0;
            end
        end

        % 截断超出范围的数据
        band_amplitudes(band_amplitudes > y_imit) = y_imit;

        % 更新图形
        if ishandle(bars)
            set(bars, 'YData', band_amplitudes);
            drawnow limitrate;
        else
            break;
        end

        processed_frames = processed_frames + 1;
    end
    pause(0.01);
end

if ishandle(fig)
    hold off;
    title(ax, '频谱分析完成', 'FontSize', 12);
end

if ishandle(player) && isplaying(player)
    stop(player);
end

disp(['处理完成 - 共处理 ', num2str(processed_frames), ' 帧']);