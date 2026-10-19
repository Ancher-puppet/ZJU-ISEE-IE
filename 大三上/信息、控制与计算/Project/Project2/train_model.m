% 功能：录制语音 -> 提取特征 -> 训练 KNN
clear; close all; clc;

%% 1. 配置参数
fs = 8000;          % 采样率
duration = 1.0;     % 录音时长
model_filename = 'my_model.mat'; % 模型名

disp('[训练模式]--->录入语音样本...');

% 初始化录音
recObj = audiorecorder(fs, 16, 1);

%% 2. 采集数据
train_data = [];
train_labels = [];
cmd_names = {'启动 (Go)', '停止 (Stop)', '波动 (Wave)'};
num_train_samples = 3; % 每条指令录 3 次

for k = 1:3
    fprintf('\n>>> 准备录制指令: [%s] \n', cmd_names{k});
    for i = 1:num_train_samples
        input(sprintf('按回车开始第 %d/%d 次录音...', i, num_train_samples));
        disp('   [正在录音...]');
        recordblocking(recObj, duration);
        disp('   [录音结束]');
        
        % 获取并处理
        sig = getaudiodata(recObj);
        
        % 特征提取函数
        feat = func_extract_features(sig, fs);
        
        train_data = [train_data; feat];
        train_labels = [train_labels; k];
        
        % 命令录音图像
        plot(sig); title(['刚刚录入: ' cmd_names{k}]); drawnow;
    end
end

%% 3. 训练模型
fprintf('\n>>> 正在训练 KNN 模型...\n');
try
    % 训练 KNN (k=1)
    knnModel = fitcknn(train_data, train_labels, 'NumNeighbors', 1);
    
    % 保存模型到 .mat 文件
    save(model_filename, 'knnModel', 'fs', 'cmd_names');
    
    disp('---------------------------------------------------');
    disp(['>>> 模型已保存为: ' model_filename]);
    
catch ME
    error('训练失败，错误信息: %s', ME.message);
end