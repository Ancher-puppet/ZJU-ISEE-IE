%% trainModulationCNN.m
% 训练一个 CNN 用于五种调制信号 (AM/FM/ASK/FSK/BPSK) 分类
% 输入: modulationTrainingData.mat (由 collectTrainingData.m 生成)
% 输出: trainedModulationClassificationNetwork.mat
%
% 网络架构说明:
%   - 2D CNN，将 I/Q 两路作为两个通道输入
%   - 三层卷积 + BatchNorm + ReLU + Dropout
%   - 全局平均池化 → 全连接 → Softmax

clear; clc; close all;

%% ===================== 1. 加载数据 =====================
fprintf('=== 加载训练数据 ===\n');
dataFile = 'modulationTrainingData.mat';
if ~isfile(dataFile)
    error('未找到 %s，请先运行 collectTrainingData.m 采集数据', dataFile);
end
load(dataFile, 'X_flat', 'Y_flat', 'modTypes', 'spf', 'fs');

totalFrames = size(X_flat, 1);
numClasses  = size(Y_flat, 2);
fprintf('总帧数: %d, 类别数: %d\n', totalFrames, numClasses);
for i = 1:numClasses
    fprintf('  %s: %d 帧\n', modTypes(i), sum(Y_flat(:, i)));
end

%% ===================== 2. 数据预处理 =====================
% 将数据转换为 imageInputLayer 需要的 4-D 格式: [H W C N]
% H=1 (单行), W=spf (采样点), C=2 (I/Q 通道), N=帧数
fprintf('\n=== 数据预处理 ===\n');

% 转为 4-D: [1 x spf x 2 x N]
X_4d = zeros(1, spf, 2, totalFrames, 'single');
for i = 1:totalFrames
    X_4d(1, :, 1, i) = single(X_flat(i, :, 1));  % I 通道
    X_4d(1, :, 2, i) = single(X_flat(i, :, 2));  % Q 通道
end

% 标签：从 one-hot 转为 categorical
[~, labelIdx] = max(Y_flat, [], 2);
Y_cat = categorical(labelIdx, 1:numClasses, cellstr(modTypes));

fprintf('输入数据尺寸: [%d x %d x %d x %d]\n', size(X_4d));
fprintf('类别分布:\n');
summary(Y_cat);

%% ===================== 3. 划分训练/验证/测试集 =====================
fprintf('\n=== 划分数据集 ===\n');

% 设置随机种子保证可复现
rng(42);

% 按类别分层抽样
trainFrac = 0.7;
valFrac   = 0.15;
testFrac  = 0.15;

trainIdx = []; valIdx = []; testIdx = [];
for c = 1:numClasses
    classIdx = find(labelIdx == c);
    n = length(classIdx);
    perm = randperm(n);

    nTrain = round(n * trainFrac);
    nVal   = round(n * valFrac);

    trainIdx = [trainIdx; classIdx(perm(1:nTrain))];
    valIdx   = [valIdx;   classIdx(perm(nTrain+1 : nTrain+nVal))];
    testIdx  = [testIdx;  classIdx(perm(nTrain+nVal+1 : end))];
end

X_train = X_4d(:, :, :, trainIdx);
Y_train = Y_cat(trainIdx);
X_val   = X_4d(:, :, :, valIdx);
Y_val   = Y_cat(valIdx);
X_test  = X_4d(:, :, :, testIdx);
Y_test  = Y_cat(testIdx);

fprintf('训练集: %d, 验证集: %d, 测试集: %d\n', ...
    length(trainIdx), length(valIdx), length(testIdx));

%% ===================== 4. 数据增强 =====================
% 使用 augmentedImageDatastore 不方便处理 1×N 的图像
% 这里用自定义训练循环的预处理，或在网络中加 noise 层
% 更简单的做法：对训练集做离线增强

fprintf('\n=== 数据增强 ===\n');
nOrig = length(trainIdx);
nVariants = 3;             % 每帧生成 3 个变体: 原始 + 加噪 + 相位旋转
nTotalAug = nOrig * nVariants;

% 预分配增强数据: [1 × spf × 2 × nTotalAug]
X_aug = zeros(1, spf, 2, nTotalAug, 'single');
Y_aug = repmat(Y_train, nVariants, 1);

for i = 1:nOrig
    iq = squeeze(X_4d(1, :, :, trainIdx(i)));  % [spf × 2]
    iq_complex = complex(iq(:, 1), iq(:, 2));

    % (1) 原始帧
    idx1 = i;
    X_aug(1, :, 1, idx1) = iq(:, 1);
    X_aug(1, :, 2, idx1) = iq(:, 2);

    % (2) 加高斯噪声 (随机 SNR 15~30 dB)
    snr_dB = 15 + 15 * rand();
    noisePwr = 10^(-snr_dB / 10);
    noise_iq = sqrt(noisePwr/2) * (randn(spf, 1) + 1j*randn(spf, 1));
    iq_noisy = iq_complex + noise_iq;
    iq_noisy = iq_noisy / sqrt(mean(abs(iq_noisy).^2));
    idx2 = nOrig + i;
    X_aug(1, :, 1, idx2) = real(iq_noisy);
    X_aug(1, :, 2, idx2) = imag(iq_noisy);

    % (3) 随机相位旋转 (0~2π)
    phase = 2 * pi * rand();
    iq_rotated = iq_complex * exp(1j * phase);
    idx3 = 2 * nOrig + i;
    X_aug(1, :, 1, idx3) = real(iq_rotated);
    X_aug(1, :, 2, idx3) = imag(iq_rotated);
end

% 直接使用增强数据（已包含原始帧），不再拼接 X_4d
X_train_aug = X_aug;
Y_train_aug = Y_aug;

fprintf('增强后训练集: %d 帧 (原始 %d × %d 变体)\n', ...
    size(X_train_aug, 4), nOrig, nVariants);

%% ===================== 5. 构建 CNN 网络 =====================
fprintf('\n=== 构建 CNN 网络 ===\n');

% 网络架构 (基于 O'Shea 调制识别 CNN 的精简版)
% 输入: [1 × 1024 × 2] — I/Q 双通道
layers = [
    imageInputLayer([1 spf 2], 'Name', 'input', 'Normalization', 'none')

    % ---- 卷积块 1 ----
    convolution2dLayer([1 3], 32, ...
        'Padding', 'same', ...
        'WeightsInitializer', 'he', ...
        'Name', 'conv1')
    batchNormalizationLayer('Name', 'bn1')
    reluLayer('Name', 'relu1')
    dropoutLayer(0.3, 'Name', 'drop1')

    % ---- 卷积块 2 ----
    convolution2dLayer([1 3], 64, ...
        'Padding', 'same', ...
        'WeightsInitializer', 'he', ...
        'Name', 'conv2')
    batchNormalizationLayer('Name', 'bn2')
    reluLayer('Name', 'relu2')
    maxPooling2dLayer([1 2], 'Stride', [1 2], 'Name', 'pool2')
    dropoutLayer(0.3, 'Name', 'drop2')

    % ---- 卷积块 3 ----
    convolution2dLayer([1 3], 64, ...
        'Padding', 'same', ...
        'WeightsInitializer', 'he', ...
        'Name', 'conv3')
    batchNormalizationLayer('Name', 'bn3')
    reluLayer('Name', 'relu3')
    maxPooling2dLayer([1 2], 'Stride', [1 2], 'Name', 'pool3')
    dropoutLayer(0.3, 'Name', 'drop3')

    % ---- 卷积块 4 ----
    convolution2dLayer([1 3], 96, ...
        'Padding', 'same', ...
        'WeightsInitializer', 'he', ...
        'Name', 'conv4')
    batchNormalizationLayer('Name', 'bn4')
    reluLayer('Name', 'relu4')

    % ---- 全局池化 + 分类 ----
    globalAveragePooling2dLayer('Name', 'gap')
    fullyConnectedLayer(64, 'Name', 'fc1')
    reluLayer('Name', 'relu_fc')
    dropoutLayer(0.5, 'Name', 'drop_fc')
    fullyConnectedLayer(numClasses, 'Name', 'fc_out')
    softmaxLayer('Name', 'softmax')
    classificationLayer('Name', 'output')
];

% 显示网络结构（文本概览）
fprintf('网络层数: %d\n', numel(layers));
fprintf('输入: [1 × %d × 2] (I/Q 双通道)\n', spf);
fprintf('输出: %d 类 (%s)\n', numClasses, strjoin(cellstr(modTypes), ', '));
disp(layers);

%% ===================== 6. 配置训练选项 =====================
fprintf('\n=== 配置训练参数 ===\n');

% 根据数据量选择合适参数
miniBatchSize = 64;
maxEpochs     = 50;
initialLR     = 0.001;
validationFreq = floor(size(X_train_aug, 4) / miniBatchSize);

options = trainingOptions('adam', ...
    'InitialLearnRate', initialLR, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.5, ...
    'LearnRateDropPeriod', 15, ...
    'MaxEpochs', maxEpochs, ...
    'MiniBatchSize', miniBatchSize, ...
    'ValidationData', {X_val, Y_val}, ...
    'ValidationFrequency', validationFreq, ...
    'Shuffle', 'every-epoch', ...
    'Plots', 'training-progress', ...
    'Verbose', true, ...
    'VerboseFrequency', validationFreq, ...
    'L2Regularization', 1e-4);

%% ===================== 7. 训练网络 =====================
fprintf('\n=== 开始训练 ===\n');
fprintf('训练样本: %d, 验证样本: %d\n', size(X_train_aug, 4), size(X_val, 4));

trainedNet_mine = trainNetwork(X_train_aug, Y_train_aug, layers, options);

%% ===================== 8. 评估模型 =====================
fprintf('\n=== 模型评估 ===\n');

% 测试集准确率
Y_pred = classify(trainedNet_mine, X_test);
testAcc = mean(Y_pred == Y_test) * 100;
fprintf('测试集准确率: %.2f%%\n', testAcc);

% 混淆矩阵
figure('Name', '混淆矩阵', 'Position', [100 100 500 450]);
cm = confusionchart(Y_test, Y_pred);
cm.Title = sprintf('测试集混淆矩阵 (准确率: %.1f%%)', testAcc);
cm.RowSummary = 'row-normalized';
cm.ColumnSummary = 'column-normalized';

% 各类别详细指标
fprintf('\n各类别准确率:\n');
for c = 1:numClasses
    classMask = Y_test == categorical(modTypes(c));
    classAcc = mean(Y_pred(classMask) == Y_test(classMask)) * 100;
    fprintf('  %s: %.1f%% (%d/%d)\n', ...
        modTypes(c), classAcc, ...
        sum(Y_pred(classMask) == Y_test(classMask)), sum(classMask));
end

%% ===================== 9. 保存模型 =====================
fprintf('\n=== 保存模型 ===\n');
save('trainedModulationClassificationNetwork.mat', 'trainedNet_mine', ...
    'modTypes', 'spf', 'fs');
fprintf('模型已保存到 trainedModulationClassificationNetwork.mat\n');
fprintf('  - 网络变量名: trainedNet_mine\n');
fprintf('  - 输入格式: [1 × %d × 2] (I/Q 两通道)\n', spf);
fprintf('  - 类别: %s\n', strjoin(cellstr(modTypes), ', '));
