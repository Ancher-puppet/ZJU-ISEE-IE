%% 使用 Goertzel 算法解码 DTMF 信号
clear; clc; close all;

%% 参数设置
% 标准频率表
std_rows = [697, 770, 852, 941];       % 低频
std_cols = [1209, 1336, 1477, 1633];   % 高频
target_freqs = [std_rows, std_cols];   % 将8个目标频率放在一起

% 对应的按键字符
dtmf_chars = ['1', '2', '3', 'A';
              '4', '5', '6', 'B';
              '7', '8', '9', 'C';
              '*', '0', '#', 'D'];

%% 读取音频文件
filename = 'my_student_id_phone.wav'; 
if ~isfile(filename)
    error(['找不到文件 ', filename, '，请检查路径。']);
end
[x, fs] = audioread(filename);
if size(x, 2) > 1, x = mean(x, 2); end % 转单声道

%% 信号分割 (端点检测)
frame_len = round(0.02 * fs); 
energy = envelope(x, frame_len, 'rms'); 
threshold = 0.2 * max(energy); 
is_voice = energy > threshold;

diff_gate = diff([0; is_voice; 0]); 
starts = find(diff_gate == 1);
ends = find(diff_gate == -1) - 1;
num_digits = length(starts);

disp(['检测到 ', num2str(num_digits), ' 个按键音。正在使用 Goertzel 算法解码...']);

%% 循环处理: Goertzel 解码
figure('Name', 'Goertzel 能量分布', 'Color', 'white', 'Position', [100, 50, 1200, 600]);
cols = 2; 
rows = ceil(num_digits / cols);
decoded_string = '';

for k = 1:num_digits
    % 提取信号片段
    len = ends(k) - starts(k);
    idx_s = starts(k) + round(len * 0.15); 
    idx_e = ends(k) - round(len * 0.15);
    segment = x(idx_s:idx_e); 
    
    N = length(segment);
    
    % Goertzel 算法
    energies = my_goertzel(segment, target_freqs, fs);
    
    % 寻找最大能量对应的频率
    energy_low = energies(1:4); 
    energy_high = energies(5:8); 
    
    [max_L, idx_L] = max(energy_low); 
    [max_H, idx_H] = max(energy_high);
    
    % 查表解码
    current_char = dtmf_chars(idx_L, idx_H);
    decoded_string = [decoded_string, current_char];
    
    % 绘图
    subplot(rows, cols, k);
    stem(target_freqs, energies, 'filled', 'LineWidth', 1.5, 'MarkerSize', 6);
    
    grid on;
    xlim([500, 1800]);
    xticks(target_freqs); 
    xtickangle(45);
    ylabel('Goertzel 能量');
    xlabel('频率 (Hz)');
    
    title(['片段 ', num2str(k), ' : 识别为 [ ', current_char, ' ]'], ...
          'FontSize', 12, 'FontWeight', 'bold');
      
    text(1600, max(energies)*0.8, current_char, ...
        'FontSize', 24, 'Color', 'red', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'BackgroundColor', 'yellow', 'EdgeColor', 'red');
end

%% 输出结果
disp(['最终解码学号: ', decoded_string]);
sgtitle(['Goertzel 算法解码结果: ', decoded_string]);