clear; close all; clc;

%% 1. 读取与预处理图像,得到频域图确定参数
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

% 计算频谱
F = fftshift(fft2(img));
% 计算对数幅值以便显示
S = log(1 + abs(F));

% 显示频谱图
figure('Name', '频谱参数读取工具', 'NumberTitle', 'off');
imshow(S, []); 
title('图像频谱图 (红圈代表归一化频率)');
hold on;
colormap jet; 
colorbar;

% 频率刻度圆环
[rows, cols] = size(img);
center_r = floor(rows / 2) + 1;
center_c = floor(cols / 2) + 1;
max_radius = min(rows, cols) / 2; 

freq_ticks = 0.0 : 0.02 : 0.7; 
for f = freq_ticks
    r = f * max_radius;

    theta = 0 : 0.01 : 2*pi;
    x = center_c + r * cos(theta);
    y = center_r + r * sin(theta);
    plot(x, y, 'r--', 'LineWidth', 1);
    
    text(center_c + r, center_r, num2str(f), 'Color', 'white', ...
         'BackgroundColor', 'black', 'FontSize', 10);
end
hold off;

%% 2. 滤波器参数定义
N = 24; 
wc_low = 0.3;           
wc_band = [0.1 0.2]; 

%% 3. 设计 FIR 滤波器
% 设计低通滤波器系数
b_low = my_fir(N, wc_low, 'low', 'hamming');
% 设计带通滤波器系数
b_band = my_fir(N, wc_band, 'bandpass', 'hamming');

%% 4. 显示滤波器特性 
subplot(2,2,1);
stem(0:N, b_low, 'filled'); title(['低通滤波器时域系数 (N=', num2str(N), ')']); grid on;
subplot(2,2,2);
[H_low, w] = freqz(b_low, 1, 512);
plot(w/pi, abs(H_low)); title('低通滤波器幅频响应'); xlabel('归一化频率 (\times\pi rad/sample)'); grid on;

% 带通特性
subplot(2,2,3);
stem(0:N, b_band, 'filled'); title(['带通滤波器时域系数 (N=', num2str(N), ')']); grid on;
subplot(2,2,4);
[H_band, w] = freqz(b_band, 1, 512);
plot(w/pi, abs(H_band)); title('带通滤波器幅频响应'); xlabel('归一化频率 (\times\pi rad/sample)'); grid on;

%% 5. 混合滤波实验

% --- 实验 A: 行滤波用低通 -> 列滤波用带通 ---
[img_final_A, img_mid_A] = filter_row_col(img, b_low, b_band);

% --- 实验 B: 行滤波用带通 -> 列滤波用低通 ---
[img_final_B, img_mid_B] = filter_row_col(img, b_band, b_low);

%% 6. 结果观察与显示

% Low -> Band
figure('Name', '实验A: 行(低通) -> 列(带通)', 'NumberTitle', 'off');
subplot(1, 3, 1); 
imshow(img, []); title('原始图像');
subplot(1, 3, 2); 
imshow(img_mid_A, []); title('中间图像: 行滤波(低通)');
xlabel('水平方向变模糊');
subplot(1, 3, 3); 
imshow(img_final_A, []); title('最终图像: 列滤波(带通)');
xlabel('指纹纹理被提取');

% Band -> Low
figure('Name', '实验B: 行(带通) -> 列(低通)', 'NumberTitle', 'off');
subplot(1, 3, 1); 
imshow(img, []); title('原始图像');
subplot(1, 3, 2); 
imshow(img_mid_B, []); title('中间图像: 行滤波(带通)');
xlabel('水平方向边缘被提取');
subplot(1, 3, 3); 
imshow(img_final_B, []); title('最终图像: 列滤波(低通)');
xlabel('垂直方向变模糊');

%% 7. 分析滤波器阶数 N 对结果的影响
N_list = [6 ,10 ,16 ,20, 24, 30, 36];
layout_rows = 2;
layout_cols = ceil(length(N_list)/layout_rows);
figure('Name', '阶数 N 的影响 (行低通列带通)', 'NumberTitle', 'off');

for i = 1:length(N_list)
    curr_N = N_list(i);
    % 设计低通滤波器系数
    b_low_temp = my_fir(curr_N, wc_low, 'low', 'hamming');
    % 设计带通滤波器系数
    b_band_temp = my_fir(curr_N, wc_band, 'bandpass', 'hamming');
    
    % 调用函数
    [img_N_out, ~] = filter_row_col(img, b_low_temp, b_band_temp);
    subplot(layout_rows, layout_cols, i);
    imshow(img_N_out, []);
    title(['N = ', num2str(curr_N)]);
end

figure('Name', '阶数 N 的影响 (行带通列低通)', 'NumberTitle', 'off');
for i = 1:length(N_list)
    curr_N = N_list(i);
    % 设计低通滤波器系数
    b_low_temp = my_fir(curr_N, wc_low, 'low', 'hamming');
    % 设计带通滤波器系数
    b_band_temp = my_fir(curr_N, wc_band, 'bandpass', 'hamming');
    
    % 调用函数
    [img_N_out, ~] = filter_row_col(img, b_band_temp, b_low_temp);
    subplot(layout_rows, layout_cols, i);
    imshow(img_N_out, []);
    title(['N = ', num2str(curr_N)]);
end

%% 8. 分析低通截止频率对结果的影响
N_fix = 24; 
wc_list = [0.05, 0.15, 0.25, 0.3, 0.35, 0.5]; 

% 固定带通滤波器
wc_band_fixed = [0.1, 0.3]; 
b_band_fixed = my_fir(N_fix, wc_band_fixed, 'bandpass', 'hamming');

figure('Name', '低通截止频率(wc)对结果的影响', 'NumberTitle', 'off');
num_plots = length(wc_list);
cols_plot = 3;
rows_plot = ceil(num_plots / cols_plot);

for i = 1:num_plots
    curr_wc = wc_list(i);
    b_temp_low = my_fir(N_fix, curr_wc, 'low', 'hamming');
    [img_out_wc, ~] = filter_row_col(img, b_temp_low, b_band_fixed);
    
    % 3. 绘图
    subplot(rows_plot, cols_plot, i);
    imshow(img_out_wc, []);
    title(['wc_{low} = ', num2str(curr_wc)]);
end

%% 9. 分析带通带宽对结果的影响
N_fix = 24; 

% 固定低通滤波器
wc_low_fixed = 0.3; 
b_low_fixed = my_fir(N_fix, wc_low_fixed, 'low', 'hamming');

wc_center = 0.15; 
bw_list = [0.02, 0.05, 0.10, 0.15]; 

figure('Name', '带通带宽(Bandwidth)对结果的影响', 'NumberTitle', 'off');

num_plots = length(bw_list);
cols_plot = 2;
rows_plot = ceil(num_plots / cols_plot);

for i = 1:num_plots
    curr_bw = bw_list(i);
    
    wc_start = wc_center - curr_bw / 2;
    wc_end   = wc_center + curr_bw / 2;
    wc_range = [wc_start, wc_end];
    
    b_temp_band = my_fir(N_fix, wc_range, 'bandpass', 'hamming');
    [img_out_bw, ~] = filter_row_col(img, b_temp_band , b_low_fixed);
    
    % --- 3. 绘图 ---
    subplot(rows_plot, cols_plot, i);
    imshow(img_out_bw, []);
    % 标题显示当前带宽和实际频率范围
    title(['BW=', num2str(curr_bw), ' [', num2str(wc_start), '~', num2str(wc_end), ']']);
end