function [img_out, img_mid] = filter_row_col(img_in, h_row, h_col)
% 输入:
%   img_in: 输入图像
%   h_row:  用于行方向的滤波器系数
%   h_col:  用于列方向的滤波器系数
% 输出:
%   img_out: 最终滤波图像
%   img_mid: 中间图像

    [rows, cols] = size(img_in);
    img_mid = zeros(rows, cols);
    img_out = zeros(rows, cols);
    
    % 1. 行滤波
    for r = 1:rows
        row_data = img_in(r, :);
        img_mid(r, :) = conv(row_data, h_row, 'same');
    end
    
    % 2. 列滤波
    for c = 1:cols
        col_data = img_mid(:, c);
        img_out(:, c) = conv(col_data, h_col, 'same');
    end
end