%% 远程声控系统
clear; close all; clc;

%% 1. 参数与模型初始化
fs = 8000; 
SNR_System = 100;
disp('远程声控系统');

% 训练模型
voice_model_file = 'my_model.mat';
if ~exist(voice_model_file, 'file')
    disp('>>> [语音模型] 缺失，开始训练...');
    run('train_model.m');
end

% 加载模型
data_voice = load(voice_model_file); 
voiceKnnModel = data_voice.knnModel; 
cmd_names = data_voice.cmd_names;
disp('>>> [语音模型] 加载成功 (用于实时录音)。');

%% 2. 获取信号并处理
recObj = audiorecorder(fs, 16, 1);

fprintf('------------------------------------------------\n');
disp('【选择输入模式】');
disp('   1. 实时录音 (Record)');
disp('   2. 模拟信号: 启动 (Go)');
disp('   3. 模拟信号: 停止 (Stop)');
disp('   4. 模拟信号: 波动 (Wave)');

choice = input('>>> 请输入选项 (1/2/3/4): ', 's');

% 1: 获取信号
current_title = '';
t = linspace(0, 1, fs)';
active_model = []; % 初始化

switch choice
    case '1' % 录音模式
        disp('   >>> 正在录音 (1秒)... 请说话...');
        recordblocking(recObj, 1.0);
        raw_sig = getaudiodata(recObj);
        current_title = '实时录音信号';
        active_model = voiceKnnModel; 
        
    case {'2', '3', '4'} % 仿真模式
        if choice == '2', filename = 'go.m4a'; target_name = 'Go'; end
        if choice == '3', filename = 'stop.m4a'; target_name = 'Stop'; end
        if choice == '4', filename = 'wave.m4a'; target_name = 'Wave'; end
        
        [file_sig, fs_file] = audioread(filename);

        % 立体声转单声道
        if size(file_sig, 2) > 1
            file_sig = mean(file_sig, 2); 
        end

        % 重采样到 8000Hz
        if fs_file ~= fs
            file_sig = resample(file_sig, fs, fs_file);
        end

        % 去掉录音开头和结尾可能存在的长静音
        frame_len = 0.02 * fs; 
        energy = smooth(abs(file_sig), 100);
        [~, max_idx] = max(energy);
        half_len = floor(0.5 * fs);
        start_idx = max(1, max_idx - half_len);
        end_idx = min(length(file_sig), max_idx + half_len - 1);
        raw_sig = file_sig(start_idx:end_idx);
        
        % 补零
        if length(raw_sig) < fs
            padding = zeros(fs - length(raw_sig), 1);
            raw_sig = [raw_sig; padding];
        else
            raw_sig = raw_sig(1:fs); 
        end
        
        current_title = ['仿真信号: ' target_name ' (来自文件)'];
        active_model = voiceKnnModel; 
        
    otherwise
        disp('输入无效。');
end

% 归一化范围为-1到1
if max(abs(raw_sig)) > 0
    raw_sig = raw_sig / max(abs(raw_sig));
end

%% 3.流程处理:编码 -> 传输 -> 解码
% 通信系统
[tx_bits, quantized_sig, tx_ref] = func_info_coding(raw_sig,'xtatic');
[rx_bits, debug_data] = func_mod_channel(tx_bits, SNR_System);
[restored_sig, num_corrected, rx_corrected_bits] = func_info_decoding(rx_bits);

if length(restored_sig) > length(raw_sig)
    restored_sig = restored_sig(1:length(raw_sig));
elseif length(restored_sig) < length(raw_sig)
    restored_sig = [restored_sig; zeros(length(raw_sig)-length(restored_sig), 1)];
end

% 特征识别
feat_rx = func_extract_features(restored_sig, fs);
pred_idx = predict(active_model, feat_rx);
cmd_str = cmd_names{pred_idx};

% 控制响应
[t_ctrl, y_ctrl, y_est] = func_control(pred_idx);

% 信道误码率，tx_bits为发送的包信号，rx_bits为接收的包信号，只考虑信道的影响
% 两个数据长度应该一样，均为64518
len_tx_raw = length(tx_bits);
len_rx_raw = length(rx_bits);
L_raw = min(len_tx_raw, len_rx_raw);
[~, ber_val] = biterr(tx_bits(1:L_raw), rx_bits(1:L_raw));

% 最终误码率，tx_ref是无检错码的包数据，rx_corrected_bits为检错后的包数据舍弃检错码
% tx_ref长度为36860(无Hamming较短),rx_corrected_bits长度为32036
len_tx = length(tx_ref);
len_rx = length(rx_corrected_bits);
L_final = min(len_tx, len_rx); 
[~, ber_final] = biterr(tx_ref(1:L_final), rx_corrected_bits(1:L_final));

if len_tx ~= len_rx
    fprintf('   [警告] 长度不匹配: 发送 %d bits vs 接收 %d bits \n', len_tx, len_rx);
end

fprintf('   >>> 信道状态(未纠错): 误码率 %.4f | 汉明码成功纠正了 %d 个错误\n', ber_val, num_corrected);
fprintf('   >>> 最终误码率:  %.4f (纠错后残留错误)\n', ber_final);
%% 4.绘图
% 图1：信号分析
figure(1); set(gcf, 'Name', 'Fig1: 信号分析', 'Color', 'w', 'Position', [50, 400, 500, 400]);
subplot(2,1,1); plot(raw_sig); title([current_title ' - 时域']); grid on; axis tight;
L = length(raw_sig); f_axis = fs*(0:(L/2))/L; Y = abs(fft(raw_sig)); P1 = Y(1:L/2+1);
subplot(2,1,2); plot(f_axis, P1, 'k'); title('频谱分析'); xlabel('Hz'); grid on;

% 图2：量化分析
figure(2); set(gcf, 'Name', 'Fig2: 量化与传输对比', 'Color', 'w', 'Position', [560, 100, 600, 700]);
% 发送端 (TX)
subplot(3,1,1);
plot(raw_sig, 'b', 'LineWidth', 1); hold on;
plot(quantized_sig, 'r--', 'LineWidth', 1); hold off;
title('【发送端】原始信号 vs 量化信号'); 
legend('原始模拟信号', '发送的量化信号'); grid on; axis tight;

% 传输对比 (TX vs RX)
subplot(3,1,2);
plot(quantized_sig, 'r', 'LineWidth', 2); hold on; 
plot(restored_sig, 'g--', 'LineWidth', 1.5); hold off;
title('【传输效果】发送的量化信号 vs 接收的恢复信号'); 
subtitle(['误码率 BER = ' num2str(ber_val) ]);
legend('发送(TX)', '接收(RX)'); grid on; axis tight;

% 细节放大
subplot(3,1,3);
[~, peak_idx] = max(abs(raw_sig)); 
win_size = 50; 
idx_start = max(1, peak_idx - win_size);
idx_end = min(length(raw_sig), peak_idx + win_size);
zoom_range = idx_start : idx_end;
stairs(zoom_range, quantized_sig(zoom_range), 'r-', 'LineWidth', 1.5); hold on;
plot(zoom_range, raw_sig(zoom_range), 'b.-', 'LineWidth', 1, 'MarkerSize', 6); 
plot(zoom_range, restored_sig(zoom_range), 'go', 'LineWidth', 1, 'MarkerSize', 8); hold off;
title(['【细节放大】信号峰值处 (索引 ' num2str(idx_start) '-' num2str(idx_end) ') - 阶梯效应']); 
legend('发送量化(阶梯)', '原始模拟(平滑)', '接收恢复(采样)'); grid on; axis tight;

% 图3：星座图
figure(3); set(gcf, 'Name', 'Fig3: 星座图', 'Color', 'w', 'Position', [50, 50, 400, 300]);
scatter(real(debug_data.rx_constellation), imag(debug_data.rx_constellation), 10, 'b', 'filled');
title(['星座图 (BER=' num2str(ber_val) ')']); grid on;

% 图4：结果
figure(4); set(gcf, 'Name', 'Fig4: 控制与观测', 'Color', 'w');

subplot(1,3,1); 
bar(feat_rx); xticklabels({'过零率', '谱质心', '高频比'});
title(['特征 (判定: ' cmd_str ')']); grid on;

subplot(1,3,2); 
plot(t_ctrl, y_ctrl, 'b', 'LineWidth', 2); hold on;
plot(t_ctrl, y_est, 'r--', 'LineWidth', 1.5); hold off;
title('观测器控制效果'); 
xlabel('时间 (s)'); ylabel('位移');
legend('真实系统输出', '观测器估计值'); 
grid on;

subplot(1,3,3); % 把原来的 1,2 改为 1,3 布局
error_curve = y_ctrl - y_est;
plot(t_ctrl, error_curve, 'k', 'LineWidth', 1);
title('观测器估计误差 (y - y_{est})');
grid on; xlabel('Time (s)');