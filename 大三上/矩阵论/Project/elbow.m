%% 肘部法 (Elbow Method) K-Means 分析
%  运行 K-Means (K=2 到 K_max)
%  绘制 Loss vs. K 曲线
%  使用 Kneedle 思路自动寻找最佳 K

clear;
clc;
close all;

%% --- 参数设置 ---
image_filename = 'ikun.png';
K_max = 20;           % 要测试的最大 K 值
max_iter_kmeans = 100; % 每次 K-Means 运行的最大迭代次数

%% --- 数据加载与预处理 ---
fprintf('加载和预处理图像: %s\n', image_filename);
original_image_uint8 = imread(image_filename);
original_image_double = im2double(original_image_uint8); 
[m, n, p] = size(original_image_double);
N = m * n;
P = reshape(original_image_double, N, p);

%% --- 1. 运行多次 K-Means ---
K_range = 2:K_max;
final_loss_values = zeros(length(K_range), 1);

fprintf('开始 K-Means 循环 (K=2 到 %d)...\n', K_max);
for i = 1:length(K_range) 
    k = K_range(i);
    disp(['正在运行 K = ' num2str(k)]); 
    [final_loss_values(i), ~, ~] = mykmeans(P, k, max_iter_kmeans);
end
fprintf('K-Means 循环完成。\n');

%% --- 2. 绘制原始 Loss vs. K 曲线 ---
figure;
plot(K_range, final_loss_values, 'bo-', 'LineWidth', 2);
title('K-Means 肘部法曲线 (原始数据)', 'FontSize', 14);
xlabel('聚类数量 (K)', 'FontSize', 12);
ylabel('最终 Loss (WCSS)', 'FontSize', 12);
grid on;

%% --- 3. Kneedle 算法实现 (基于连线距离) ---
% 数据进行归一化，避免尺度不同问题

% 归一化
x_norm = (K_range - min(K_range)) / (max(K_range) - min(K_range));
y_norm = (final_loss_values - min(final_loss_values)) / (max(final_loss_values) - min(final_loss_values));

% 归一化后, "收尾连线"  是从点 (0, 1) 到点 (1, 0)
% 这条线的方程是: y = -x + 1, 或者 x + y - 1 = 0

distances = abs(x_norm' + y_norm - 1) / sqrt(2);

% 找到距离最大的点 
[max_dist, max_idx] = max(distances);
optimal_K = K_range(max_idx);

fprintf('\n--- 肘部法分析结果 ---\n');
fprintf('"肘部" 点位于 K = %d\n', optimal_K);

%% --- 4. 可视化 Kneedle 结果 ---
figure;
plot(x_norm, y_norm, 'bo-', 'LineWidth', 2, 'DisplayName', '归一化的 Loss');
hold on;
plot([0 1], [1 0], 'r--', 'LineWidth', 1.5, 'DisplayName', '收尾连线');
% 绘制肘部点
plot(x_norm(max_idx), y_norm(max_idx), 'kp', 'MarkerSize', 18, 'LineWidth', 3, 'DisplayName', '检测到的肘部');
% 绘制肘部点到直线的距离
plot([x_norm(max_idx), (x_norm(max_idx) + y_norm(max_idx))/2], [y_norm(max_idx), (x_norm(max_idx) + y_norm(max_idx))/2], 'g-', 'DisplayName', '最大距离');
hold off;

title('Kneedle 肘部法 (归一化数据)', 'FontSize', 14);
xlabel('归一化的 K 值', 'FontSize', 12);
ylabel('归一化的 Loss (WCSS)', 'FontSize', 12);
legend('show', 'Location', 'best');
grid on;