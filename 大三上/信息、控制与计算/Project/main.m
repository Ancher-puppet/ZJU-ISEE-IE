clear; close all; clc;

%% 1. 加载模型
model_file = 'my_model.mat';
need_train = false;

disp('智能语音控制系统');

% 检查模型
if exist(model_file, 'file')
    fprintf('检测到模型文件: %s\n', model_file);
    user_choice = input('>>> 是否使用已存在模型? [Y=是 / N=否]: ', 's');
    
    if strcmpi(user_choice, 'n')
        need_train = true; % 重新训练
    else
        % 加载模型
        disp('>>> 正在加载模型...');
        load(model_file);
        disp('>>> 模型加载成功！');
    end
else
    disp('>>> 未检测到模型文件，需要进行训练');
    need_train = true;
end

if need_train
    run('train_model.m'); 
end

%% 2. 录音
if ~exist('fs', 'var'), fs = 8000; end 
duration = 1.0;
recObj = audiorecorder(fs, 16, 1);
SNR_dB = 20; % 信噪比

%% 3. 控制循环
disp('===================================================');
disp('系统就绪，开始语音控制系统');
disp('===================================================');

while true
    prompt = input('>>> 按回车开始语音指令 (输入 q 退出): ', 's');
    if strcmpi(prompt, 'q'), break; end
    
    % 1.语音采集
    disp('[采集] 正在听取指令...');
    recordblocking(recObj, duration);
    raw_sig = getaudiodata(recObj);
    disp('采集完成。');
    
    % 2.编码
    [tx_bits, q_params] = func_info_coding(raw_sig);
    
    % 3.信道传输
    rx_bits = func_mod_channel(tx_bits, SNR_dB);
    
    % 4.解码
    restored_sig = func_info_decoding(rx_bits, q_params);
    
    % 5.识别
    feat_rx = func_extract_features(restored_sig, fs);
    pred_label = predict(knnModel, feat_rx);
    
    cmd_str = cmd_names{pred_label};
    fprintf('   ==> 识别结果: [%s]\n', cmd_str);
    
    % 6.响应
    [t_ctrl, y_ctrl] = func_control_ode(pred_label);
    
    % 图像绘制
    figure(1); set(gcf, 'Position', [100, 100, 800, 600]);
    
    subplot(3,1,1);
    plot(raw_sig, 'b'); hold on; plot(restored_sig, 'r:');
    title('信号对比: 原始 vs 恢复'); legend('Tx', 'Rx');
    
    subplot(3,1,2);
    bar(feat_rx); xticklabels({'过零率', '谱质心', '高频能量占比'});
    title(['识别特征 (判定为: ' cmd_str ')']);
    
    subplot(3,1,3);
    plot(t_ctrl, y_ctrl, 'k-', 'LineWidth', 2);
    title(['控制系统响应']); xlabel('时间(s)'); ylabel('位移');
    grid on;
    
    drawnow;
end

disp('程序已退出。');