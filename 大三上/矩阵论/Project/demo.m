%% 基于 K-Means 的图像颜色量化 主脚本
%
% 流程：加载图像 -> 预处理 -> K-Means聚类 -> 重建图像 -> 显示结果

clear;
clc;
close all;

%% --- 参数设置 ---
image_filename = 'ikun.png';    % 输入图像文件名
K = 16;                          % 想要量化到的颜色数量 (聚类数)
max_iter = 30;                 % K-Means 的最大迭代次数

%% --- 数据加载与预处理 ---
fprintf('加载图像: %s\n', image_filename);
try
    original_image_uint8 = imread(image_filename);
catch
    error('无法读取图像文件。请确保 %s 在当前目录下，或者提供正确路径。', image_filename);
end

imshow(original_image_uint8);
title("I am IKUN", "FontSize", 20);

% 检查是否为彩色图像
if size(original_image_uint8, 3) ~= 3
    error('输入图像必须是彩色 RGB 图像。');
end

fprintf('图像预处理...\n');

% 将图像像素值从 uint8 (0-255) 转换为 double (0.0-1.0)
original_image_double = im2double(original_image_uint8); 

% 获取图像尺寸
[m, n, p] = size(original_image_double); % p 应该是 3 (RGB)
N = m * n; % 像素总数

% 将图像数据 reshape 为 N x 3 的矩阵 P
% P 的每一行代表一个像素的 RGB 向量。
P = reshape(original_image_double, N, p);
fprintf('图像尺寸: %d x %d (%d 像素)\n', m, n, N);

%% --- 编写并调用 K-Means 算法 ---
fprintf('运行 K-Means 算法 (K=%d)...\n', K);

% Write your own algorithm here.

% 初始化中心
rand_num = randperm(N, K);
center = P(rand_num, :);

loss_history = zeros(max_iter, 1);

% 迭代
for i = 1:max_iter
    % 固定 H，求解 Φ
    % 计算所有点到所有聚类中心的距离
    distances = pdist2(P, center, 'squaredeuclidean');
    % 最近的聚类中心
    [min_distances, idx] = min(distances, [], 2);% idx存储每个像素点所属类
    % Loss 
    loss_history(i) = sum(min_distances);

    %固定 Φ，求解 H
    %重新算每个类所有点的均值并作为新的参考点
    for k = 1:K
        belong_k = P(idx == k, :);% 找到所有属于第 k 簇的像素点
        
        % 计算均值作为新的聚类中心
        if ~isempty(belong_k) % 确保第k类中有点
            center(k, :) = mean(belong_k, 1);
        end
    end
   
    % 是否收敛
    if i > 1 && loss_history(i) == loss_history(i-1)
        fprintf('算法在第 %d 次迭代收敛。\n', i);
        loss_history(i+1:end) = loss_history(i);
        break;
    end
end
fprintf('K-Means 算法完成。\n');
%% --- 图像重建 ---
fprintf('重建量化后的图像...\n');
% 创建量化后的数据矩阵(N x 3), 并reshape回原始尺寸(m x n x 3)

% Write your own code here.

% 创建新的像素矩阵 (N x 3)
new_P = center(idx, :);

% Reshape 回原始图像尺寸 (m x n x 3)
new_image_double = reshape(new_P, m, n, p);

% 将 double 类型 (0.0-1.0) 的图像转换回 uint8 (0-255) 以便显示和保存
% im2uint8 会自动处理乘以 255 和四舍五入

% Write your own code here.

new_image_uint8 = im2uint8(new_image_double);

fprintf('图像重建完成。\n');

%% --- 显示结果与分析 ---

% 显示原始图像和量化后的图像
% 分析超参数对结果的影响

% Write your own code here.

% 显示原始图像和量化后的图像
figure;
subplot(1, 2, 1);
imshow(original_image_uint8);
title('原始图像 (Original)', 'FontSize', 14);

subplot(1, 2, 2);
imshow(new_image_uint8);
title(sprintf('K-Means 量化图像 (K = %d)', K), 'FontSize', 14);

% 绘制 loss 随迭代次数的变化曲线 
figure;
plot(1:max_iter, loss_history, 'LineWidth', 2);
title(sprintf('Loss 随迭代次数的变化 (K = %d)', K), 'FontSize', 14);
xlabel('迭代次数 (Iteration)', 'FontSize', 12);
ylabel('Loss (组内距离平方和 WCSS)', 'FontSize', 12);
grid on;
if i < max_iter
    xlim([1 i]); % 如果提前收敛，只显示到收敛的迭代次数
end



