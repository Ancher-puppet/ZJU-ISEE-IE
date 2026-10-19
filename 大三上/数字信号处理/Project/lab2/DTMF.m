%% DTMF 信号合成
clear; clc; close all;

%% 参数设置与初始化
student_ID = ''; 
fs = 8000;              % 采样率
duration = 0.2;         % 每个按键音持续时间 (秒)
silence_dur = 0.1;      % 按键之间的静音间隔 (秒)

% DTMF 频率表定义
freqs_low = [697, 770, 852, 941];      % 行频率 (低频)
freqs_high = [1209, 1336, 1477, 1633]; % 列频率 (高频)
dtmf_keys = ['1', '2', '3', 'A';
             '4', '5', '6', 'B';
             '7', '8', '9', 'C';
             '*', '0', '#', 'D'];

%% 合成学号对应的语音信号并播放
disp(['正在生成学号 [', student_ID, '] 的 DTMF 信号...']);

full_signal = [];
samples_per_tone = round(duration * fs);
samples_silence = round(silence_dur * fs);
t = (0:samples_per_tone-1) / fs;

for i = 1:length(student_ID)
    key = student_ID(i);
    [r, c] = find(dtmf_keys == key); 
    
    if ~isempty(r)
        f_l = freqs_low(r);
        f_h = freqs_high(c);
        
        tone = sin(2*pi*f_l*t) + sin(2*pi*f_h*t);
        
        full_signal = [full_signal, tone, zeros(1, samples_silence)];
    else
        warning(['跳过非法字符: ', key]);
    end
end

% 标准化幅度防止爆音
full_signal = full_signal / max(abs(full_signal));

sound(full_signal, fs);
disp('播放完毕。');

audiowrite('my_student_id.wav', full_signal, fs);

%% 时域波形图
t_axis = (0:length(full_signal)-1) / fs;
figure('Name', 'DTMF 信号分析', 'Color', 'white', 'Position', [100, 100, 1000, 700]);

plot(t_axis, full_signal, 'b');
title(['学号 ', student_ID, ' 的 DTMF 时域波形']);
xlabel('时间 (s)'); 
ylabel('幅度');
grid on;
xlim([0, max(t_axis)]); 
text(0.05, 0.8, '按键音 + 静音间隔', 'FontSize', 10, 'BackgroundColor', 'w');
