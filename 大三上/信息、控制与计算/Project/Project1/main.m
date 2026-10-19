% 信号生成 -> 压缩传输 -> ML识别 -> 系统控制
clear; close all; clc;

%% 1. 系统参数配置
fs = 8000;          % 采样率
duration = 0.5;     % 指令时长
snr_db = 12;        % 信道信噪比

%% 2. 训练机器学习模型 (Machine Learning)
% 调用 func_train_ml.m
[knnModel, acc] = func_train_ml(fs, duration);
disp(' ');

%% 3. 模拟用户发出指令 (Signal Generation)
% 这里我们模拟用户说出了 "Start" (对应ID=1)
disp('>>> 步骤1: 用户发出语音指令 [启动]...');
t = linspace(0, duration, fs*duration);
% 生成一个与训练样本略有不同的测试信号
original_signal = sin(2*pi*1500*t) + 0.05*randn(size(t));

%% 4. 通信传输 (Communication)
% 调用 func_channel_trans.m
disp(['>>> 步骤2: 信号经 A-law 压缩并传输 (SNR=' num2str(snr_db) 'dB)...']);
[rx_signal, tx_signal] = func_channel_trans(original_signal, snr_db);

%% 5. 接收端处理与识别 (Recognition)
% 调用 func_extract_features.m
disp('>>> 步骤3: 接收端提取特征并进行智能识别...');
feat_rx = func_extract_features(rx_signal, fs);

% 使用训练好的模型进行预测
pred_label = predict(knnModel, feat_rx);

% 将数字标签转换为文字
cmd_str = '未知';
if pred_label == 1, cmd_str = '启动 (Start)'; end
if pred_label == 2, cmd_str = '停止 (Stop)'; end
if pred_label == 3, cmd_str = '波动 (Wave)'; end

disp(['    -> 识别结果: ' cmd_str]);

%% 6. 控制系统响应 (Control)
% 调用 func_control_sys.m
disp('>>> 步骤4: 驱动控制系统执行动作...');
[t_ctrl, u_ctrl, y_ctrl] = func_control_sys(pred_label);

%% 7. 结果可视化 (Visualization)
figure('Position', [100, 100, 1000, 700], 'Name', 'System Simulation Results');

% 图1: 信号对比
subplot(3,1,1);
plot(t(1:300), original_signal(1:300), 'b', 'LineWidth', 1.5); hold on;
plot(t(1:300), rx_signal(1:300), 'r--');
title(['通信传输对比 (局部波形, SNR=' num2str(snr_db) 'dB)']);
legend('原始语音', '接收语音(含噪)'); grid on;

% 图2: 特征识别可视化
subplot(3,1,2);
% 画出之前训练数据的背景分布不太容易，这里只画接收点
% 为了更好的效果，建议直接看 func_train_ml 生成的 Figure 1
bar([feat_rx(1), feat_rx(2)]);
xticklabels({'过零率', '谱质心'});
title(['接收信号特征提取 (识别结果: ' cmd_str ')']);
grid on;

% 图3: 控制响应
subplot(3,1,3);
yyaxis left
plot(t_ctrl, u_ctrl, 'm--', 'LineWidth', 1.5);
ylabel('控制输入 u(t)');
yyaxis right
plot(t_ctrl, y_ctrl, 'b-', 'LineWidth', 2);
ylabel('系统位移 y(t)');
title('控制系统最终响应');
legend('指令输入', '电机响应'); grid on;

disp('仿真结束。');