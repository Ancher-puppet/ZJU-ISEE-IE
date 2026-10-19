function [img_out, img_mid] = filter_row_col(img_in, h_row, h_col)
% FILTER_ROW_COL 对图像进行行滤波和列滤波
% 输入:
%   img_in: 输入图像
%   h_row:  用于行方向的滤波器系数 (Row Filter)
%   h_col:  用于列方向的滤波器系数 (Column Filter)
% 输出:
%   img_out: 最终滤波图像 (行滤波 -> 列滤波)
%   img_mid: 中间图像 (仅行滤波后的结果)

    [rows, cols] = size(img_in);
    img_mid = zeros(rows, cols);
    img_out = zeros(rows, cols);
    
    % 1. 行滤波 (Row Filtering)
    % 遍历每一行，与 h_row 进行卷积
    for r = 1:rows
        row_data = img_in(r, :);
        % 'same' 保证输出大小与输入一致
        img_mid(r, :) = conv(row_data, h_row, 'same');
    end
    
    % 2. 列滤波 (Column Filtering)
    % 对中间图像 img_mid 的每一列，与 h_col 进行卷积
    for c = 1:cols
        col_data = img_mid(:, c);
        img_out(:, c) = conv(col_data, h_col, 'same');
    end
end