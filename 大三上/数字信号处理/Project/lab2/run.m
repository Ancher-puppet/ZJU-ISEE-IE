%% 产生16点输入序列
clc;
clear;
close all;

% 学号
student_id = [3, 2, 3, 0, 1, 0, 2, 4, 6, 0];
N = 16;
x = zeros(N, 1); 
x(1:10) = student_id;
fprintf('16点输入序列 x:\n');
disp(x');

%% 运行16点基4-FFT
X = studentname(x);
fprintf('来自 studentname.m 的16点频谱序列 X:\n');
disp(X);

%% 验证结果
% 用MATLAB内置的 fft 函数进行对比
X_matlab = fft(x);
diff = max(abs(X - X_matlab));
fprintf('student.m与MATLAB内置 fft() 的最大绝对误差: %e\n', diff);

%% stem(X) 显示频谱图形
% "stem(X)" 同时绘制复数的实部和虚部

% 绘制实部和虚部
figure;
k = 0:15; % 频率索引
stem(k, real(X), 'b', 'filled', 'DisplayName', '实部 Real(X)');
hold on;
stem(k, imag(X), 'r', 'filled', 'DisplayName', '虚部 Imag(X)');
hold off;

title('16点频谱 X (studentname.m)');
xlabel('频率索引 k');
ylabel('值');
grid on;
xticks(k);

% 幅度谱
figure;
stem(k, abs(X), 'filled');
title('16点频谱幅度 |X(k)| (studentname.m)');
xlabel('频率索引 k');
ylabel('幅度');
grid on;
xticks(k);