function [final_loss, final_centroids, final_idx] = mykmeans(P, K, max_iter)
%MYKMEANS 对像素矩阵 P 执行 K-Means 算法
%   P: N x 3 像素数据矩阵
%   K: 聚类数量
%   max_iter: 最大迭代次数
%   ---
%   final_loss: 最终的 WCSS (loss) 值
%   final_center: K x 3 的聚类中心矩阵
%   final_idx: N x 1 的像素归属索引

    N = size(P, 1); % 像素总数

    % 初始化聚类中心
    rand_num = randperm(N, K);
    center = P(rand_num, :); % K x 3 矩阵

    for i = 1:max_iter
        % 固定 H，求解 Φ
        distances = pdist2(P, center, 'squaredeuclidean');
        [min_distances, idx] = min(distances, [], 2);
        
        % 计算Loss
        current_loss = sum(min_distances);
        
        % 固定 Φ，求解 H
        for k = 1:K
            belong_k = P(idx == k, :);
            if ~isempty(belong_k)
                center(k, :) = mean(belong_k, 1);
            end
        end
        
        % 收敛
        if i > 1 && current_loss == prev_loss
            break; 
        end
        prev_loss = current_loss;
    end
    
    % 返回最终结果
    final_loss = current_loss;
    final_centroids = center;
    final_idx = idx;
end

