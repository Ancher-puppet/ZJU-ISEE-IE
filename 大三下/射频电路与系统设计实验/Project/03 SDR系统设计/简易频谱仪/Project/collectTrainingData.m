%% collectTrainingData.m
% 用 Pluto SDR 回环采集 5 种调制信号的 OTA 训练数据
% 硬件连接: Pluto TX → SMA线 → 30dB衰减器 → Pluto RX
%
% 采集参数可调:
%   - framesPerClass: 每类采集帧数
%   - spf:            每帧采样点数
%   - fc:             中心频率 (Hz)，避开广播频段
%   - txGain / rxGain: 收发增益

clear; clc; close all;

%% ===================== 参数配置 =====================
framesPerClass = 1500;      % 每类采集帧数
spf            = 1024;      % 每帧采样点数
sps            = 8;         % 数字调制的每符号采样率
fs             = 200e3;     % 基带采样率 (Hz)
fc             = 433e6;     % RF 中心频率 (Hz)
txGain         = -5;        % TX 增益 (dB)，回环下保持低增益
rxGain         = 10;        % RX 增益 (dB)
flushFrames    = 10;        % 每次重配后丢弃的帧数

modTypes = ["AM", "FM", "ASK", "FSK", "BPSK"];

% 可视化：创建实时预览窗口
figPreview = figure('Name', '采集实时预览', 'NumberTitle', 'off', ...
    'Position', [50 400 900 350]);
axTime = subplot(1,2,1); title(axTime, 'I/Q 时域波形'); xlabel('采样点'); ylabel('幅度');
hold(axTime, 'on'); grid(axTime, 'on');
hI = plot(axTime, nan(spf,1), 'b', 'LineWidth', 1.0, 'DisplayName', 'I');
hQ = plot(axTime, nan(spf,1), 'r', 'LineWidth', 1.0, 'DisplayName', 'Q');
legend(axTime, 'show');

axSpec = subplot(1,2,2); title(axSpec, '功率谱'); xlabel('频率 (kHz)'); ylabel('dB');
hold(axSpec, 'on'); grid(axSpec, 'on');
hSpec = plot(axSpec, nan(spf/2,1), 'k', 'LineWidth', 1.2);

% 数据存储
numClasses = length(modTypes);
X_all = cell(numClasses, 1);   % 用 cell 数组避免跨类标签污染
Y_all = cell(numClasses, 1);   % 每类存一个 [N×5] one-hot 矩阵

%% ===================== 初始化 Pluto =====================
fprintf('=== 初始化 Pluto SDR ===\n');
radioID = char(resolvePlutoRadioID());
fprintf('Pluto Radio ID: %s\n', radioID);

txRadio = sdrtx('Pluto', ...
    'RadioID', radioID, ...
    'CenterFrequency', fc, ...
    'BasebandSampleRate', fs, ...
    'Gain', txGain);

rxRadio = sdrrx('Pluto', ...
    'RadioID', radioID, ...
    'CenterFrequency', fc, ...
    'BasebandSampleRate', fs, ...
    'Gain', rxGain, ...
    'OutputDataType', 'single', ...
    'SamplesPerFrame', spf);

%% ===================== 逐类采集 =====================
for c = 1:numClasses
    modType = modTypes(c);
    fprintf('\n=== [%d/%d] 采集调制类型: %s ===\n', c, numClasses, modType);

    % 清除 persistent System object，避免输入尺寸锁定冲突
    clear ModClassGetSource ModClassGetModulator;

    % 生成调制信号
    dataSrc   = ModClassGetSource(modType, sps, spf, fs);
    modulator = ModClassGetModulator(modType, sps, fs);

    % 生成长波形（串联多个随机帧），避免 transmitRepeat 时每帧采到相同内容
    numLongFrames = 500;  % 长波形包含的帧数（>framesPerClass/3 确保多样性）
    longWaveform = [];
    for fi = 1:numLongFrames
        x_i = dataSrc();
        y_i = modulator(x_i);
        if length(y_i) >= spf
            y_i = y_i(1:spf);
        else
            y_i(end+1:spf) = 0;
        end
        longWaveform = [longWaveform; y_i]; %#ok<AGROW>
    end

    % 归一化到 0.8 满幅，防止 DAC 削波
    maxVal = max(max(abs(real(longWaveform))), max(abs(imag(longWaveform))));
    if maxVal > 0
        longWaveform = longWaveform * 0.8 / maxVal;
    end

    fprintf('  长波形: %d 采样点 (%d帧), max|real|=%.3f, max|imag|=%.3f\n', ...
        length(longWaveform), numLongFrames, ...
        max(abs(real(longWaveform))), max(abs(imag(longWaveform))));

    % 数字中频上变频：搬移到 20kHz 避让 SDR 硬件的 AC 耦合/DC Block
    f_if = 20e3;  % 20kHz 中频
    t_if = (0:length(longWaveform)-1)' / fs;
    longWaveform = longWaveform .* exp(1j * 2 * pi * f_if * t_if);

    % 发射长波形（循环发射，每帧采到不同偏移）
    transmitRepeat(txRadio, complex(longWaveform));
    pause(0.1);  % 等待发射稳定

    % 清缓存
    for k = 1:flushFrames
        rxRadio();
    end

    % 采集 framesPerClass 帧
    validFrames = 0;
    attempts = 0;
    maxAttempts = framesPerClass * 2;  % 防止无限循环

    fprintf('  正在采集 %d 帧...\n', framesPerClass);
    tic;

    % 本类的临时存储
    X_class = zeros(spf, 2, framesPerClass);  % [samples x (I,Q) x frame]
    Y_class = zeros(framesPerClass, numClasses);

    while validFrames < framesPerClass && attempts < maxAttempts
        attempts = attempts + 1;
        rx = rxRadio();

        % 去直流
        rx = rx - mean(rx);

        % 基本质量检查：信号功率不能太低
        pwr = mean(abs(rx).^2);
        if pwr < 1e-6
            continue;  % 信号太弱，跳过
        end

        % 功率归一化
        rx = rx / sqrt(pwr);

        validFrames = validFrames + 1;
        X_class(:, 1, validFrames) = real(rx);   % I 路
        X_class(:, 2, validFrames) = imag(rx);   % Q 路
        Y_class(validFrames, c) = 1;

        % 实时预览：每 100 帧刷新一次波形和频谱
        if mod(validFrames, 100) == 0 || validFrames == 1
            % 时域 I/Q
            set(hI, 'YData', real(rx));
            set(hQ, 'YData', imag(rx));
            ylim(axTime, [-1 1] * max(1.2, max(abs(rx)) * 1.3));
            title(axTime, sprintf('%s — I/Q 时域 (帧 #%d)', modType, validFrames));

            % 功率谱
            win = hann(spf, 'periodic');
            spec = abs(fftshift(fft(rx .* win))).^2;
            spec_dB = 10*log10(spec + eps);
            freq_kHz = (-spf/2 : spf/2-1)' * fs/1e3 / spf;
            set(hSpec, 'XData', freq_kHz, 'YData', spec_dB);
            xlim(axSpec, [freq_kHz(1) freq_kHz(end)]);
            ylim(axSpec, [max(spec_dB)-50, max(spec_dB)+5]);
            title(axSpec, sprintf('%s — 功率谱 (帧 #%d)', modType, validFrames));
            drawnow limitrate;

            fprintf('    进度: %d/%d (%.1f秒)\n', validFrames, framesPerClass, toc);
        end
    end

    % 停止发射
    release(txRadio);
    fprintf('  完成: 采集了 %d 帧, 耗时 %.1f 秒\n', validFrames, toc);

    % 存入 cell 数组（仅有效帧）
    X_all{c} = X_class(:, :, 1:validFrames);
    Y_all{c} = Y_class(1:validFrames, :);

    % 重新初始化 TX（release 后需要重建）
    if c < numClasses
        txRadio = sdrtx('Pluto', ...
            'RadioID', radioID, ...
            'CenterFrequency', fc, ...
            'BasebandSampleRate', fs, ...
            'Gain', txGain);
    end
end

%% ===================== 保存数据 =====================
release(rxRadio);
% txRadio 已在最后一次循环中 release

fprintf('\n=== 数据采集完成 ===\n');

% 将 cell 数组合并展平为 [totalFrames x spf x 2]
X_flat = [];
Y_flat = [];
for c = 1:numClasses
    Xc = X_all{c};       % [spf x 2 x nFrames]
    nFrames_c = size(Xc, 3);
    X_flat = [X_flat; permute(Xc, [3, 1, 2])];   % append as [nFrames x spf x 2]
    Y_flat = [Y_flat; Y_all{c}];
    fprintf('  %s: %d 帧\n', modTypes(c), nFrames_c);
end

fprintf('总帧数: %d\n', size(X_flat, 1));
for c = 1:numClasses
    fprintf('  %s: %d 帧\n', modTypes(c), sum(Y_flat(:, c)));
end

save('modulationTrainingData.mat', 'X_flat', 'Y_flat', 'modTypes', 'spf', 'fs');
fprintf('数据已保存到 modulationTrainingData.mat\n');

%% ===================== 可视化汇总 =====================
fprintf('\n=== 绘制五类调制信号汇总 ===\n');
figSummary = figure('Name', '五类调制信号采集汇总', 'NumberTitle', 'off', ...
    'Position', [80 80 1400 800]);

for c = 1:numClasses
    % 取该类中间位置的一帧（避免边界效应）
    Xc = X_all{c};
    nFrames_c = size(Xc, 3);
    midFrame = round(nFrames_c / 2);
    iq = squeeze(Xc(:, :, midFrame));          % [spf × 2]
    rx_cplx = complex(iq(:, 1), iq(:, 2));

    % -- 时域 I/Q --
    subplot(5, 3, 3*c - 2);
    plot(1:spf, real(rx_cplx), 'b', 'LineWidth', 1.0); hold on;
    plot(1:spf, imag(rx_cplx), 'r', 'LineWidth', 1.0); hold off;
    ymax = max(abs([real(rx_cplx); imag(rx_cplx)])) * 1.3;
    ylim([-ymax ymax]); grid on;
    title(sprintf('%s — I/Q 时域波形', modTypes(c)));
    xlabel('采样点'); ylabel('幅度');
    legend('I', 'Q', 'Location', 'best');

    % -- 功率谱 --
    subplot(5, 3, 3*c - 1);
    win = hann(spf, 'periodic');
    spec = abs(fftshift(fft(rx_cplx .* win))).^2;
    spec_dB = 10*log10(spec + eps);
    freq_kHz = (-spf/2 : spf/2-1)' * fs/1e3 / spf;
    plot(freq_kHz, spec_dB, 'k', 'LineWidth', 1.0); grid on;
    xlim([freq_kHz(1) freq_kHz(end)]);
    ylim([max(spec_dB)-50, max(spec_dB)+5]);
    title(sprintf('%s — 功率谱密度', modTypes(c)));
    xlabel('频率 (kHz)'); ylabel('功率 (dB)');

    % -- 星座图 --
    subplot(5, 3, 3*c);
    plot(real(rx_cplx), imag(rx_cplx), '.', 'MarkerSize', 4, 'Color', [0 0.45 0.74]);
    axis equal; grid on;
    lim = max(abs([real(rx_cplx); imag(rx_cplx)])) * 1.2;
    xlim([-lim lim]); ylim([-lim lim]);
    title(sprintf('%s — I/Q 星座图', modTypes(c)));
    xlabel('I'); ylabel('Q');
end
sgtitle('五种调制信号 OTA 采集数据可视化 (Pluto 回环)', 'FontSize', 14, 'FontWeight', 'bold');

% 保存汇总图
saveDir = fileparts(mfilename('fullpath'));
imgFile = fullfile(saveDir, 'modulationSummary.png');
exportgraphics(figSummary, imgFile, 'Resolution', 200);
fprintf('汇总图已保存到: %s\n', imgFile);
