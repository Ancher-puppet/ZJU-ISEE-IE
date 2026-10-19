%% 基于机器学习(KNN)的远程声控系统大作业仿真
% 特性：集成数据生成、特征提取、模型训练、信道传输与智能控制
% 作者：Gemini
clear; close all; clc;

%% === 第一部分：机器学习模型训练 (Machine Learning Training) ===
disp('正在生成训练数据集...');

% 1.1 生成模拟训练数据 (带随机噪声)
% 我们定义3类指令：1-Start (高频), 2-Stop (低频), 3-Wave (变频)
num_samples = 50; % 每类样本数
fs = 8000;
duration = 0.5;
t = linspace(0, duration, fs*duration);

features_train = [];
labels_train = [];

for i = 1:num_samples
    % --- 生成类别 1: Start (高频, 约1500Hz, 模拟尖锐指令) ---
    sig = sin(2*pi*(1500 + randn*50)*t) + 0.1*randn(size(t));
    feat = extract_features(sig, fs);
    features_train = [features_train; feat]; 
    labels_train = [labels_train; 1];
    
    % --- 生成类别 2: Stop (低频, 约500Hz, 模拟低沉指令) ---
    sig = sin(2*pi*(500 + randn*50)*t) + 0.1*randn(size(t));
    feat = extract_features(sig, fs);
    features_train = [features_train; feat]; 
    labels_train = [labels_train; 2];
    
    % --- 生成类别 3: Wave (调频信号, 模拟复杂语音) ---
    sig = chirp(t, 400, duration, 1000) + 0.1*randn(size(t));
    feat = extract_features(sig, fs);
    features_train = [features_train; feat]; 
    labels_train = [labels_train; 3];
end

disp('正在训练 KNN 分类器...');
% 1.2 训练 KNN 模型 (K-Nearest Neighbors)
% 使用 Statistics and Machine Learning Toolbox
try
    Mdl = fitcknn(features_train, labels_train, 'NumNeighbors', 5, 'Standardize', 1);
    disp('机器学习模型训练完成！准确率验证中...');
    cvmodel = crossval(Mdl);
    loss = kfoldLoss(cvmodel);
    disp(['模型交叉验证准确率: ' num2str((1-loss)*100) '%']);
catch
    error('请确保安装了 MATLAB Statistics and Machine Learning Toolbox');
end

%% === 第二部分：远程通信过程仿真 (Communication System) ===
disp('=============================================');
disp('      开始远程控制任务仿真');
disp('=============================================');

% 2.1 信号采集 (模拟用户发出了 "Start" 指令)
target_cmd_type = 1; % 1:Start, 2:Stop, 3:Wave
disp('用户发出语音指令...');
switch target_cmd_type
    case 1, input_sig = sin(2*pi*1500*t); true_label='启动';
    case 2, input_sig = sin(2*pi*500*t);  true_label='停止';
    case 3, input_sig = chirp(t, 400, duration, 1000); true_label='波动';
end

% 2.2 压缩 (A-law)
A = 87.6;
input_sig = input_sig / max(abs(input_sig)); % 归一化
y = sign(input_sig) .* (log(1 + A*abs(input_sig)) / log(1+A)); % 简化写法的A-law

% 2.3 信道传输 (加入噪声)
snr_db = 10; % 信噪比
rx_sig = awgn(y, snr_db, 'measured');

% 2.4 接收端解压
z = sign(rx_sig) .* ((1+A).^abs(rx_sig) - 1) / A;

%% === 第三部分：基于ML的识别与控制 (ML Recognition & Control) ===

% 3.1 特征提取 (对接收到的噪声信号)
feat_rx = extract_features(z, fs);

% 3.2 机器学习推理 (Inference)
predicted_label_idx = predict(Mdl, feat_rx);

cmd_map = {'启动', '停止', '波动'};
pred_cmd = cmd_map{predicted_label_idx};
disp(['接收端 ML 识别结果: [' pred_cmd ']']);

% 3.3 控制系统响应 (使用状态空间模型)
% 这是一个 质量-弹簧-阻尼系统
A_sys = [0 1; -10 -2]; B_sys = [0; 1]; C_sys = [1 0]; D_sys = 0;
sys = ss(A_sys, B_sys, C_sys, D_sys);

t_ctrl = 0:0.01:5;
u = zeros(size(t_ctrl));

if predicted_label_idx == 1      % 启动 -> 阶跃响应
    u(:) = 1; 
elseif predicted_label_idx == 2  % 停止 -> 归零
    u(:) = 0;
elseif predicted_label_idx == 3  % 波动 -> 正弦跟踪
    u = 0.5 * sin(2*pi*t_ctrl);
end

[y_out, ~, ~] = lsim(sys, u, t_ctrl);

%% === 第四部分：结果可视化 ===
figure('Position', [100, 100, 1200, 500]);

% 子图1：特征空间可视化 (展示 ML 是如何分类的)
subplot(1, 3, 1);
gscatter(features_train(:,1), features_train(:,2), labels_train, 'rbg', '.', 20);
hold on;
plot(feat_rx(1), feat_rx(2), 'ko', 'MarkerSize', 12, 'LineWidth', 2, 'DisplayName', '接收信号');
title('机器学习特征空间 (KNN)');
xlabel('特征1: 过零率 (ZCR)'); ylabel('特征2: 谱质心 (Centroid)');
legend('Start样本','Stop样本','Wave样本','当前测试信号','Location','best');
grid on;

% 子图2：时域波形对比
subplot(1, 3, 2);
plot(t(1:200), input_sig(1:200), 'b', 'LineWidth', 1.5); hold on;
plot(t(1:200), rx_sig(1:200), 'r--');
title(['信号传输 (SNR=' num2str(snr_db) 'dB)']);
legend('发送', '接收(含噪)'); grid on;

% 子图3：控制系统响应
subplot(1, 3, 3);
plot(t_ctrl, u, 'm--', 'LineWidth', 1); hold on;
plot(t_ctrl, y_out, 'b', 'LineWidth', 2);
title(['控制响应: ' pred_cmd]);
legend('控制输入', '系统输出');
grid on;
ylim([-1.5 1.5]);

%% === 辅助函数：特征提取 ===
function feat = extract_features(signal, fs)
    % 提取两个简单且鲁棒的音频特征
    
    % 1. 过零率 (Zero Crossing Rate) - 反映信号的频率特性
    zcr = mean(abs(diff(sign(signal)))) / 2;
    
    % 2. 谱质心 (Spectral Centroid) - 反映信号的"亮度"/中心频率
    L = length(signal);
    Y = fft(signal);
    P2 = abs(Y/L);
    P1 = P2(1:floor(L/2)+1);
    f = fs*(0:(floor(L/2)))/L;
    
    % 计算加权平均频率
    spectral_centroid = sum(f' .* P1) / (sum(P1) + eps);
    
    % 为了量级统一，对质心做对数处理或归一化
    feat = [zcr, spectral_centroid/1000]; 
end