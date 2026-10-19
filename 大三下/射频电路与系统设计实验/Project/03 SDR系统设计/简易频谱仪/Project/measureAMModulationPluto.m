function [modIndex, imdDbc, details] = measureAMModulationPluto(varargin)
%MEASUREAMMODULATIONPLUTO Measure AM modulation index and distortion over Pluto.

cfg = parseInputs(varargin{:});
radioID = resolvePlutoRadioID();

txRadio = [];
rxRadio = [];
cleanupObj = onCleanup(@()cleanupRadios(txRadio, rxRadio));

%% 生成 AM 基带波形
txSampleCount = choosePeriodicSampleCount( ...
    cfg.SampleRate, [cfg.IFFrequency cfg.ModulationFrequency], ...
    cfg.SamplesPerFrame, cfg.MaxTxSamples);
t = (0:txSampleCount-1)' / cfg.SampleRate;
n_if = (0:txSampleCount-1)';

txWaveform = cfg.TxAmplitude * (1 + cfg.TargetModulationIndex * cos(2*pi*cfg.ModulationFrequency*t));

% 数字 IF 上变频：避开 Pluto AC 耦合
txWaveform = txWaveform .* exp(1j * 2*pi*cfg.IFFrequency / cfg.SampleRate * n_if);

%% Pluto 发射
txRadio = sdrtx("Pluto");
txRadio.RadioID = char(radioID);
txRadio.CenterFrequency = cfg.CarrierFrequency;
txRadio.BasebandSampleRate = cfg.SampleRate;
txRadio.Gain = cfg.TxGain;
transmitRepeat(txRadio, complex(txWaveform));
pause(cfg.SettleTime);

%% Pluto 接收（固定增益，关闭 AGC）
rxRadio = sdrrx("Pluto", ...
    "RadioID", char(radioID), ...
    "CenterFrequency", cfg.CarrierFrequency, ...
    "BasebandSampleRate", cfg.SampleRate, ...
    "GainSource", "Manual", ...
    "Gain", cfg.RxGain, ...
    "OutputDataType", "single", ...
    "SamplesPerFrame", cfg.SamplesPerFrame);

for k = 1:cfg.FlushFrames, rxRadio(); end

%% 逐帧采集与分析
numFrames = cfg.AverageFrames;
modValues = zeros(numFrames, 1);
imdValues = zeros(numFrames, 1);
sidebandModValues = zeros(numFrames, 1);
actualFmValues = zeros(numFrames, 1);
rxPower = zeros(numFrames, 1);

for k = 1:numFrames
    rxIf = rxRadio();
    % 数字下变频：IF → DC
    rx = rxIf .* exp(-1j * 2*pi*cfg.IFFrequency / cfg.SampleRate * (0:length(rxIf)-1)');
    rxPower(k) = mean(abs(rx).^2);
    [modValues(k), sidebandModValues(k), imdValues(k), actualFmValues(k)] = ...
        analyzeAMEnvelope(rx, cfg.SampleRate, cfg.ModulationFrequency);

    % 诊断绘图：仅第 1 帧
    if cfg.PlotDiagnostics && k == 1
        plotAMDiagnostics(rx, rxIf, modValues(k), actualFmValues(k), cfg);
    end
end

%% 统计与校准
rawModIndex = median(modValues, "omitnan");
estimatedCal = cfg.TargetModulationIndex / max(rawModIndex, eps);
if ~isnan(cfg.CalibrationFactor)
    modIndex = rawModIndex * cfg.CalibrationFactor;
else
    modIndex = rawModIndex;
end
imdDbc = median(imdValues, "omitnan");

%% 输出
details = struct(...
    'radioID', radioID, ...
    'cfg', cfg, ...
    'txSampleCount', txSampleCount, ...
    'rawModulationIndex', rawModIndex, ...
    'estimatedCalibration', estimatedCal, ...
    'frameModulationIndex', modValues, ...
    'frameSidebandModulationIndex', sidebandModValues, ...
    'frameImdDbc', imdValues, ...
    'frameActualFm', actualFmValues, ...
    'framePower', rxPower);
end

%% ========================================================================
function [modIndex, sidebandModIndex, imdDbc, actualFm] = analyzeAMEnvelope(rx, fs, fm)
rx = rx(:);
N = numel(rx);
n = (0:N-1)' / fs;

% 包络提取。平滑窗口必须短于调制周期，否则高 fm 会被直接滤小。
env = extractAMEnvelope(rx, fs, fm);
envAc = env - mean(env);

% FFT 寻峰 + 二次插值细调（频率精度从 6Hz → <0.1Hz）
spec = abs(fft(envAc .* hann(N, "periodic")));
spec = spec(1:floor(N/2));
freq = (0:length(spec)-1)' * fs / N;
searchRange = freq >= fm * 0.85 & freq <= fm * 1.15;
if any(searchRange)
    [~, peakIdx] = max(spec(searchRange));
    freqsInRange = freq(searchRange);
    peakBin = find(searchRange, 1) - 1 + peakIdx;

    if peakBin > 1 && peakBin < length(spec)
        A_left  = spec(peakBin - 1);
        A_peak  = spec(peakBin);
        A_right = spec(peakBin + 1);
        delta = (A_left - A_right) / (2*(A_left - 2*A_peak + A_right));
        delta = max(min(delta, 0.5), -0.5);
        actualFm = (peakBin - 1 + delta) * fs / N;
    else
        actualFm = freqsInRange(peakIdx);
    end
else
    actualFm = fm;
end

% 用实测频率重做最小二乘拟合（频率自适应，消除频偏导致的残差泄漏）
coef = [ones(N,1), cos(2*pi*actualFm*n), sin(2*pi*actualFm*n)] \ double(env);
modIndex = hypot(coef(2), coef(3)) / max(abs(coef(1)), eps);

% 方法 A: 相干解调（用实测频率）
carrierCoeff = mean(rx);
USB = mean(rx .* exp(-1j*2*pi*actualFm*n));
LSB = mean(rx .* exp( 1j*2*pi*actualFm*n));
sidebandModIndex = (abs(USB) + abs(LSB)) / max(abs(carrierCoeff), eps);

% IMD: 包络频谱中最大杂散相对于基频的 dBc
fundMask = abs(freq - actualFm) <= max(40, 2*fs/N);
fundAmp = max(spec(fundMask));
searchMask = freq >= max(0, 2*actualFm - 80) & ...
             freq <= min(10*actualFm + 80, fs/2) & ~fundMask;

if isempty(fundAmp) || fundAmp <= 0 || ~any(searchMask)
    imdDbc = -Inf;
else
    imdDbc = 20*log10((max(spec(searchMask)) + eps) / (fundAmp + eps));
end
end

%% ========================================================================
function cfg = parseInputs(varargin)
p = inputParser;
p.addParameter("CarrierFrequency",      433e6,  @(x) isscalar(x) && x > 0);
p.addParameter("ModulationFrequency",   1e3,    @(x) isscalar(x) && x > 0);
p.addParameter("TargetModulationIndex", 0.5,    @(x) isscalar(x) && x > 0 && x < 1);
p.addParameter("SampleRate",            200e3,  @(x) isscalar(x) && x > 0);
p.addParameter("SamplesPerFrame",       32768,  @(x) isscalar(x) && x > 0);
p.addParameter("AverageFrames",         20,     @(x) isscalar(x) && x > 0);
p.addParameter("FlushFrames",           10,     @(x) isscalar(x) && x >= 0);
p.addParameter("SettleTime",            0.2,    @(x) isscalar(x) && x >= 0);
p.addParameter("TxGain",               0,      @(x) isscalar(x));
p.addParameter("RxGain",               50,      @(x) isscalar(x));
p.addParameter("TxAmplitude",          0.4,    @(x) isscalar(x) && x > 0 && x <= 1);
p.addParameter("CalibrationFactor",    NaN,     @(x) isscalar(x));
p.addParameter("IFFrequency",          20e3,    @(x) isscalar(x) && x >= 0);
p.addParameter("MaxTxSamples",         262144,  @(x) isscalar(x) && x > 0);
p.addParameter("PlotDiagnostics",      false,   @(x) isscalar(x) && islogical(x));
p.parse(varargin{:});
cfg = p.Results;
end

%% ========================================================================
function sampleCount = choosePeriodicSampleCount(fs, tones, minSamples, maxSamples)
% transmitRepeat 会循环同一段缓冲区；缓冲区长度要让所有数字频率首尾连续。
sampleCount = round(minSamples);
basePeriod = 1;

for tone = tones(:)'
    if tone <= 0
        continue;
    end
    [~, den] = rat(tone / fs, 1e-12);
    basePeriod = lcm(basePeriod, den);
    if basePeriod > maxSamples
        warning("AMMeasure:LongTxPeriod", ...
            "当前频率组合需要 %d 点循环缓冲区，超过 MaxTxSamples=%d；保留默认帧长，可能出现循环跳变。", ...
            basePeriod, maxSamples);
        return;
    end
end

sampleCount = basePeriod * ceil(sampleCount / basePeriod);
end

%% ========================================================================
function env = extractAMEnvelope(rx, fs, fm)
rawEnv = abs(rx(:));
smoothLen = max(1, round(fs / 20000));
if fm > 0
    smoothLen = min(smoothLen, max(1, floor(fs / (20 * fm))));
end

if smoothLen > 1
    env = movmean(rawEnv, smoothLen);
else
    env = rawEnv;
end
end

%% ========================================================================
function cleanupRadios(txRadio, rxRadio)
radios = {rxRadio, txRadio};
for r = 1:numel(radios)
    if ~isempty(radios{r})
        try release(radios{r}); catch, end
    end
end
end

%% ========================================================================
function plotAMDiagnostics(rx, rxIf, mMeasured, actualFm, cfg)
% 诊断绘图：对比接收包络与理想拟合包络，判断畸变形态
%   波谷被填平 → LO泄漏/底噪        波峰被削平 → 射频压缩/截幅

N = numel(rx);
t = (0:N-1)' / cfg.SampleRate;
env = extractAMEnvelope(rx, cfg.SampleRate, cfg.ModulationFrequency);

% 重建理想包络（用实测频率 actualFm，带初相位补偿）
coef = [ones(N,1), cos(2*pi*actualFm*t), sin(2*pi*actualFm*t)] \ double(env);
dc = coef(1);
phase = atan2(-coef(3), coef(2));
idealEnv = dc + mMeasured * dc * cos(2*pi*actualFm*t + phase);

% 显示范围：取中间 5 个调制周期
T_mod = 1 / actualFm;
tCenter = t(round(N/2));
idx = find(t >= tCenter - 2.5*T_mod & t <= tCenter + 2.5*T_mod);

figure('Name', sprintf('AM 畸变诊断 (m=%.3f, fm=%.2fHz)', mMeasured, actualFm), ...
       'NumberTitle', 'off', 'Position', [100 100 1050 720]);

subplot(3,2,[1 2]);
plot(t(idx)*1e3, env(idx), 'b', 'LineWidth', 1.5); hold on;
plot(t(idx)*1e3, idealEnv(idx), 'r--', 'LineWidth', 1.5);
xlabel('时间 (ms)'); ylabel('包络幅度');
title(sprintf('实测包络 vs 理想拟合 (f_m=%.2fHz, m=%.3f)', actualFm, mMeasured));
legend('实测 env', '理想拟合', 'Location', 'best'); grid on;

subplot(3,2,3);
residual = env(idx) - idealEnv(idx);
plot(t(idx)*1e3, residual, 'k', 'LineWidth', 1); hold on;
yline(0, 'k--');
xlabel('时间 (ms)'); ylabel('残差');
title('包络残差 = 实测 - 理想');
grid on;

subplot(3,2,4);
envAc2 = env - dc;
spec = abs(fft(envAc2 .* hann(N, "periodic")));
freq = (0:floor(N/2)-1)' * cfg.SampleRate / N;
plot(freq, 20*log10(spec(1:floor(N/2)) + eps), 'b', 'LineWidth', 1);
hold on;
xline(actualFm, 'r--', sprintf('%.2f Hz', actualFm));
xlim([0 min(10*actualFm, cfg.SampleRate/2)]);
xlabel('频率 (Hz)'); ylabel('幅度 (dBFS)');
title('包络频谱 (红线 = 实测 fm)');
grid on;

subplot(3,2,[5 6]);
plotCarrierSpectrum(rxIf, cfg, actualFm);

drawnow;
end

%% ========================================================================
function plotCarrierSpectrum(rxIf, cfg, actualFm)
% 下变频前的接收 IQ 频谱：载波应在 +IFFrequency 附近。
rxIf = rxIf(:) - mean(rxIf);
N = numel(rxIf);
win = hann(N, "periodic");
spec = fftshift(abs(fft(rxIf .* win)));
freq = (-floor(N/2):ceil(N/2)-1)' * cfg.SampleRate / N;

plot(freq/1e3, 20*log10(spec + eps), 'b', 'LineWidth', 1);
hold on;
xline(cfg.IFFrequency/1e3, 'r--', sprintf('载波 %.1f kHz', cfg.IFFrequency/1e3));
xline((cfg.IFFrequency + actualFm)/1e3, 'm--', '+边带');
xline((cfg.IFFrequency - actualFm)/1e3, 'm--', '-边带');

rfCarrierMHz = (cfg.CarrierFrequency + cfg.IFFrequency) / 1e6;
xlim(([cfg.IFFrequency - 6*actualFm, cfg.IFFrequency + 6*actualFm]) / 1e3);
xlabel('基带频率 (kHz)');
ylabel('幅度 (dBFS)');
title(sprintf('接收 IQ 频谱: 载波约 %.6f MHz', rfCarrierMHz));
legend('IQ 频谱', '载波', '边带', 'Location', 'best');
grid on;
end
