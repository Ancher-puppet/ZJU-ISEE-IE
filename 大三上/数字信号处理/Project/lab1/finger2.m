clc;clear all;
img = imread('fingerprint.png'); 
img = im2double(img); 
subplot(1, 2, 1);
imshow(img);
title('原始指纹图像');

F = fftshift(fft2(img)); 
mag = abs(F);   

subplot(1, 2, 2);
imshow(mag); 
title('平移后的幅度谱');

[M, N] = size(mag); 
[max_mag, linear_idx] = max(mag(:)); 
[peak_row, peak_col] = ind2sub([M, N], linear_idx); 

u = peak_col - (N / 2 + 1);
v = peak_row - (M / 2 + 1);

fx = u / N;
fy = v / M;

freq_mag = sqrt(fx^2 + fy^2);
period = 1 / freq_mag; 
width = period / 2;  

fprintf('估计的脊线周期：%.2f 像素\n', period);
fprintf('估计的平均脊线宽度：%.2f 像素\n', width);