function [label, confidence, features] = classifyFiveClassByFeatures(rx, fs)
%CLASSIFYFIVECLASSBYFEATURES Rule-based five-class ID from received IQ only.
%   The thresholds are calibrated from live Pluto captures in this project.

features = extractFiveClassFeatures(rx, fs);

if features.ampCv > 0.55 || features.phaseJumpFrac > 0.25
    label = "AM";
    confidence = boundedConfidence(features.ampCv, 0.55, 0.95);
elseif features.ampCv < 0.05 && features.freqStd > 900
    label = "FSK";
    confidence = boundedConfidence(features.freqStd, 900, 1900);
elseif features.ampCv < 0.30 && features.freqStd > 180
    label = "FM";
    confidence = boundedConfidence(features.freqStd, 180, 700);
elseif features.freqStd >= 112 || features.freqIqr >= 145
    label = "ASK";
    confidence = boundedConfidence(max(features.freqStd, features.freqIqr), 112, 180);
else
    label = "BPSK";
    confidence = boundedConfidence(112 - features.freqStd, 0, 35);
end

label = categorical(label, ["AM","FM","ASK","FSK","BPSK"]);
confidence = max(0.55, min(0.995, confidence));
end

function c = boundedConfidence(x, low, high)
if high <= low
    c = 0.75;
else
    c = 0.65 + 0.33 * ((x - low) / (high - low));
end
c = max(0.55, min(0.995, c));
end
