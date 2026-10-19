function features = extractFiveClassFeatures(rx, fs)
%EXTRACTFIVECLASSFEATURES Compact IQ features for five-class modulation ID.

rx = rx(:);
rawMean = mean(rx);
rawPower = mean(abs(rx).^2) + eps;
dcRatio = abs(rawMean) / sqrt(rawPower);
rawAmp = abs(rx);
rawAmpCv = std(rawAmp) / (mean(rawAmp) + eps);

rx = rx - rawMean;
powerValue = mean(abs(rx).^2);
if powerValue > 0
    rx = rx ./ sqrt(powerValue);
end

amp = abs(rx);
ampMean = mean(amp) + eps;
ampStd = std(amp);
ampCv = ampStd / ampMean;
ampRange = prctile(amp, 95) - prctile(amp, 5);
ampLowFrac = mean(amp < 0.35 * median(amp + eps));

phase = unwrap(angle(rx + eps));
instFreq = diff(phase) * fs / (2*pi);
instFreq = instFreq - median(instFreq);
instFreq = trimOutliers(instFreq, 2.5);
freqStd = std(instFreq);
freqIqr = iqr(instFreq);
freqAbsMean = mean(abs(instFreq));

phaseStep = abs(angle(rx(2:end) .* conj(rx(1:end-1))));
phaseJumpFrac = mean(phaseStep > (0.65*pi));

highAmpMask = amp > prctile(amp, 65);
highAmpPhase = angle(rx(highAmpMask) + eps);
if isempty(highAmpPhase)
    phaseR1High = 0;
    phaseR2High = 0;
else
    phaseR1High = abs(mean(exp(1j * highAmpPhase)));
    phaseR2High = abs(mean(exp(1j * 2 * highAmpPhase)));
end
phaseBimodality = max(0, phaseR2High - phaseR1High);

nfft = 2048;
window = hann(min(numel(rx), nfft), "periodic");
x = rx(1:numel(window)) .* window;
spec = abs(fftshift(fft(x, nfft))).^2;
spec = spec / (sum(spec) + eps);
sortedSpec = sort(spec, "descend");
peakConcentration = sum(sortedSpec(1:min(12,numel(sortedSpec))));
spectralEntropy = -sum(spec .* log2(spec + eps)) / log2(numel(spec));

features = struct();
features.dcRatio = dcRatio;
features.rawAmpCv = rawAmpCv;
features.ampCv = ampCv;
features.ampRange = ampRange;
features.ampLowFrac = ampLowFrac;
features.freqStd = freqStd;
features.freqIqr = freqIqr;
features.freqAbsMean = freqAbsMean;
features.phaseJumpFrac = phaseJumpFrac;
features.phaseR1High = phaseR1High;
features.phaseR2High = phaseR2High;
features.phaseBimodality = phaseBimodality;
features.peakConcentration = peakConcentration;
features.spectralEntropy = spectralEntropy;
end

function y = trimOutliers(x, nSigma)
if isempty(x)
    y = x;
    return;
end
center = median(x);
spread = mad(x, 1) * 1.4826 + eps;
keep = abs(x - center) <= nSigma * spread;
y = x(keep);
if isempty(y)
    y = x;
end
end
