function [Mdl, validationAccuracy] = func_train_ml(fs, duration)
% FUNC_TRAIN_ML 生成训练数据并训练 KNN 分类器
% 输入: fs - 采样率, duration - 样本时长
% 输出: Mdl - 训练好的模型, validationAccuracy - 验证准确率

    disp('[ML] 正在生成训练数据集...');
    num_samples = 50; % 每类样本数量
    t = linspace(0, duration, fs*duration);
    
    train_data = [];
    train_labels = [];
    
    for i = 1:num_samples
        % 类别1: Start (高频正弦 + 噪声) 
        sig = sin(2*pi*(1500 + randn*50)*t) + 0.1*randn(size(t));
        feat = func_extract_features(sig, fs);
        train_data = [train_data; feat];
        train_labels = [train_labels; 1];
        
        % 类别2: Stop (低频正弦 + 噪声) 
        sig = sin(2*pi*(500 + randn*50)*t) + 0.1*randn(size(t));
        feat = func_extract_features(sig, fs);
        train_data = [train_data; feat];
        train_labels = [train_labels; 2];
        
        % 类别3: Wave (Chirp扫频信号 + 噪声) 
        sig = chirp(t, 400, duration, 1000) + 0.1*randn(size(t));
        feat = func_extract_features(sig, fs);
        train_data = [train_data; feat];
        train_labels = [train_labels; 3];
    end
    
    disp('[ML] 正在训练 KNN 模型...');
    % 使用 fitcknn 训练 K-最近邻分类器
    Mdl = fitcknn(train_data, train_labels, 'NumNeighbors', 5, 'Standardize', 1);
    
    % 交叉验证计算准确率
    cvmodel = crossval(Mdl);
    validationAccuracy = (1 - kfoldLoss(cvmodel)) * 100;
    disp(['[ML] 模型训练完成。交叉验证准确率: ' num2str(validationAccuracy) '%']);
    
    % 绘制特征空间图 (用于报告素材)
    figure('Name', 'ML Feature Space');
    gscatter(train_data(:,1), train_data(:,2), train_labels, 'rbg', '.', 20);
    title('机器学习特征分类空间');
    xlabel('特征1: 过零率 (ZCR)'); ylabel('特征2: 归一化谱质心');
    legend('Start', 'Stop', 'Wave'); grid on;
end