clear;
close all;
clc;

%% 读取图片
img=imread('finger.png'); 
subplot(3,3,1);
imshow(img,[]);
title('1.原始指纹图像');

%% 对图片直接fft2
img=im2double(img); %im2double带归一化
F=fftshift(fft2(img));
mag=abs(F); 
log_mag=log(1+mag); %log便于观察
subplot(3,3,2);
imshow(mag,[]); 
title('2.平移后的幅度谱');
subplot(3,3,3);
imshow(log_mag,[]); 
title('3.平移后的对数幅度谱');

%% 转为有效灰度图后fft2
gray=rgb2gray(img); %rgb2gray对rgb权重求和
gray=im2double(gray); %gray符合fft2的二维输入要求
F_gray=fftshift(fft2(gray)); 
gray_mag=abs(F_gray); 
gray_logmag=log(1+gray_mag); %log便于观察
subplot(3,3,4);
imshow(gray_mag,[]); 
title('4.平移后的幅度谱');
subplot(3,3,5);
imshow(gray_logmag,[]); 
title('5.平移后的对数幅度谱');

%% 未去直流，直接寻找幅度最大点
[M, N] = size(gray_mag); 
[max_mag, linear_idx_nodc] = max(gray_logmag(:)); 
[peak_row, peak_col] = ind2sub([M, N], linear_idx_nodc); 

u = peak_col - (N / 2 + 1);
v = peak_row - (M / 2 + 1);

fx = u / N;
fy = v / M;

freq_mag = sqrt(fx^2 + fy^2);
period = 1 / freq_mag; 
width = period / 2;

subplot(3, 3, 6);
imshow(gray_logmag, []);
hold on; 
plot(peak_col, peak_row, 'r+', 'MarkerSize', 20, 'LineWidth', 2);
title('6. 找到的频率峰值');
hold off;

fprintf('未去直流估计的峰值坐标：(%d, %d)\n', peak_col, peak_row);
fprintf('未去直流估计的脊线周期：%.2f 像素\n', period);
fprintf('未去直流估计的平均脊线宽度：%.2f 像素\n', width);
fprintf('\n');

%% 去直流，直接寻找幅度最大点
center_x=floor(N/2) + 1;
center_y=floor(M/2) + 1;
search = 5; % 将中心小区域置零
gray_logmag_nodc = gray_logmag;
gray_logmag_nodc(center_y-search:center_y+search, ...
                 center_x-search:center_x+search) = 0;

[max_mag_nodc, linear_idx_nodc] = max(gray_logmag_nodc(:)); 
[peak_row_nodc, peak_col_nodc] = ind2sub([M, N], linear_idx_nodc); 

u_nodc = peak_col_nodc - (N / 2 + 1); %注意图像水平垂直与矩阵行列的关系！！
v_nodc = peak_row_nodc - (M / 2 + 1);

fx_nodc = u_nodc / N;
fy_nodc = v_nodc / M;

freq_mag_nodc = sqrt(fx_nodc^2 + fy_nodc^2);
period_nodc = 1 / freq_mag_nodc; 
width_nodc = period_nodc / 2;

subplot(3, 3, 7);
imshow(gray_logmag, []);
hold on; 
plot(peak_col_nodc, peak_row_nodc, 'r+', 'MarkerSize', 20, 'LineWidth', 2);
title('7. 去直流后找到的频率峰值');
hold off;

fprintf('去直流估计的峰值坐标：(%d, %d)\n', peak_col_nodc, peak_row_nodc);
fprintf('去直流估计的脊线周期：%.2f 像素\n', period_nodc);
fprintf('去直流估计的平均脊线宽度：%.2f 像素\n', width_nodc);