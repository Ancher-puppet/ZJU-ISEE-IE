function X = studentname(x)
% 计算16点输入序列 x 的基4-FFT (DIT, Decimation-In-Time)
% 输入:
%   x - 16x1 的列向量
% 输出:
%   X - 16x1 的FFT结果 (自然顺序)

N = 16; % 序列长度
M = 2;  % 算法的级数

% 16点列向量
if length(x) ~= N
    error('输入序列 x 必须是16点。');
end
if ~iscolumn(x)
    x = x(:); % 转换为列向量
end

% 基4-变址:倒位
x_scrambled = zeros(N, 1);
for n = 0:N-1
    n1 = floor(n / 4); 
    n0 = mod(n, 4); % 将位置转为四进制
    k = 4*n0 + n1; % 倒位
    x_scrambled(k + 1) = x(n + 1); % MATLAB 索引从1开始
end

% X 初始化为复数
X = complex(x_scrambled);

% 第 1 级蝶形运算
% N/4 = 4 组 4点DFT
W4 = [1, -1j, -1, 1j];

for i = 0:3 
    % 计算当前组的基地址索引
    base_idx = i*4; 
    x0 = X(base_idx + 1);
    x1 = X(base_idx + 2);
    x2 = X(base_idx + 3);
    x3 = X(base_idx + 4);
    
    % 执行 4 点 DFT (基-4 蝶形)
    X(base_idx + 1) = x0 + x1       + x2       + x3;
    X(base_idx + 2) = x0 + W4(2)*x1 + W4(3)*x2 + W4(4)*x3; 
    X(base_idx + 3) = x0 + W4(3)*x1 + W4(1)*x2 + W4(3)*x3; 
    X(base_idx + 4) = x0 + W4(4)*x1 + W4(3)*x2 + W4(2)*x3; 
end

% 第 2 级蝶形运算
% 旋转因子集合
W16 = exp(-1j * 2 * pi * (0:N-1) / N);

% 存储第1级的结果
temp_X = X;

for k0 = 0:3
    
    % 旋转因子 W16^p
    p1 = k0;
    p2 = k0 * 2;
    p3 = k0 * 3;
    
    % 从4个组中取出输入, 并乘旋转因子
    x0 = temp_X(1 + k0);                 % * W16(1)：0，0，0，0
    x1 = temp_X(5 + k0) * W16(p1 + 1);   % * W16^(k0)：0，1，2，3
    x2 = temp_X(9 + k0) * W16(p2 + 1);   % * W16^(2*k0)：0，2，4，6
    x3 = temp_X(13 + k0) * W16(p3 + 1);  % * W16^(3*k0)：0，3，6，9
    
    % 4点DFT
    X(k0 + 1)  = x0 + x1       + x2       + x3;
    X(k0 + 5)  = x0 + W4(2)*x1 + W4(3)*x2 + W4(4)*x3;
    X(k0 + 9)  = x0 + W4(3)*x1 + W4(1)*x2 + W4(3)*x3;
    X(k0 + 13) = x0 + W4(4)*x1 + W4(3)*x2 + W4(2)*x3;
end

end