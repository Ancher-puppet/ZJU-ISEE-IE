clear; close all; clc;

%% 1. 读取与预处理图像
filename = 'image.jpeg'; 

try
    img_original = imread(filename);
catch
    error('未找到图片');
end

% 转为灰度图
if size(img_original, 3) == 3
    img_gray = rgb2gray(img_original);
else
    img_gray = img_original;
end
% 归一化到 [0, 1]
img = im2double(img_gray);
figure('Name', '原始图像', 'NumberTitle', 'off');
imshow(img); title('待处理图像');

% 计算频谱
F = fftshift(fft2(img));
% 计算对数幅值以便显示
S = log(1 + abs(F));

% 显示频谱图
figure('Name', '频谱参数读取工具', 'NumberTitle', 'off');
imshow(S, []); % [] 表示自动拉伸显示范围
title('图像频谱图 (红圈代表归一化频率)');
hold on;
colormap jet; % 使用彩色热图，更容易看清能量分布
colorbar;

% 在图上画出频率刻度圆环
[rows, cols] = size(img);
center_r = floor(rows / 2) + 1;
center_c = floor(cols / 2) + 1;
max_radius = min(rows, cols) / 2; % 对应归一化频率 1.0 (Nyquist)

% 画出 0.1 到 0.9 的参考圆
freq_ticks = 0.0 : 0.02 : 0.7; 
for f = freq_ticks
    r = f * max_radius;
    % 画圆
    theta = 0 : 0.01 : 2*pi;
    x = center_c + r * cos(theta);
    y = center_r + r * sin(theta);
    plot(x, y, 'r--', 'LineWidth', 1);
    
    % 标注文字
    text(center_c + r, center_r, num2str(f), 'Color', 'white', ...
         'BackgroundColor', 'black', 'FontSize', 10);
end
hold off;

%% 2. 滤波器参数定义
% 阶数 N (6 < N < 32)
N = 20; 

% 频率参数 (归一化频率 0 ~ 1, 1对应Nyquist频率)，而指纹通常位于中频段
wc_low = 0.3;           % 低通截止频率
wc_band = [0.02 0.6];    % 带通频率范围 [下限 上限]

%% 3. 设计 FIR 滤波器 (窗函数法，使用Hamming窗)
% 低通滤波器
b_low = fir1(N, wc_low, 'low', hamming(N+1));

% 带通滤波器
b_band = fir1(N, wc_band, 'bandpass', hamming(N+1));

%% 4. 画出滤波器时域和频率响应
figure('Name', '滤波器特性分析', 'NumberTitle', 'off');

% 低通特性
subplot(2,2,1);
stem(0:N, b_low, 'filled'); title(['低通滤波器时域系数 (N=', num2str(N), ')']); grid on;
subplot(2,2,2);
[H_low, w] = freqz(b_low, 1, 512);
plot(w/pi, abs(H_low)); title('低通滤波器幅频响应'); xlabel('归一化频率 (\times\pi rad/sample)'); grid on;

% --- 带通特性 ---
subplot(2,2,3);
stem(0:N, b_band, 'filled'); title(['带通滤波器时域系数 (N=', num2str(N), ')']); grid on;
subplot(2,2,4);
[H_band, w] = freqz(b_band, 1, 512);
plot(w/pi, abs(H_band)); title('带通滤波器幅频响应'); xlabel('归一化频率 (\times\pi rad/sample)'); grid on;

%% 5. 生成对应的滤波器
% 应用低通
img_low_out = filter_row_col(img, b_low);

% 应用带通
img_band_out = filter_row_col(img, b_band);

%% 6. 结果观察与显示
% 二值化处理 (为了更清晰地看清指纹)
threshold_low = mean(img_low_out(:)); 
img_low_bin = img_low_out > threshold_low;

% 带通图去除了直流分量，均值接近0，大于0的部分即为脊线
img_band_bin = img_band_out > 0; 

figure('Name', '滤波及二值化结果', 'NumberTitle', 'off');
subplot(2,2,1); imshow(img_low_out, []); title('低通滤波灰度图');
subplot(2,2,2); imshow(img_band_out, []); title('带通滤波灰度图');
subplot(2,2,3); imshow(img_low_bin); title('低通二值化');
subplot(2,2,4); imshow(img_band_bin); title('带通二值化');
%% 7. 分析滤波器阶数 N 对结果的影响
% 我们选取不同的 N 值进行对比：N=6 (下限), N=16 (中间), N=32 (上限)
N_list = [6, 10, 16, 20, 24, 32];
figure('Name', '不同阶数 N 的带通滤波效果对比', 'NumberTitle', 'off');
layout_rows = 2;
layout_cols = 3;

for i = 1:length(N_list)
    curr_N = N_list(i);
    % 重新设计带通滤波器
    b_temp = fir1(curr_N, wc_band, 'bandpass', hamming(curr_N+1));
    
    % 滤波
    img_temp = filter_row_col(img, b_temp);
    
    % 显示
    subplot(layout_rows, layout_cols, i);
    imshow(img_temp,[]);
    title(['N = ', num2str(curr_N)]);
end
