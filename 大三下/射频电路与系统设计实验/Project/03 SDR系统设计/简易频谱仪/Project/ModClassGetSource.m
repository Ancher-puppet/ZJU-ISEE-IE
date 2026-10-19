function src = ModClassGetSource(modType, sps, spf, fs)

switch modType
  case {"BPSK","ASK","FSK"}
    M = 2;
    src = @()randi([0 M-1],spf/sps,1);
  case {"FM","AM"}
    src = @()getAudio(spf,fs);
end
end

function x = getAudio(spf,fs)
%getAudio Audio source for analog modulation types

persistent audioSrc audioRC

if isempty(audioSrc)
  audioSrc = dsp.AudioFileReader('audio_mix_441.wav',...
    'SamplesPerFrame',spf,'PlayCount',inf);
  audioRC = dsp.SampleRateConverter('Bandwidth',30e3,...
    'InputSampleRate',audioSrc.SampleRate,...
    'OutputSampleRate',fs);
  [~,decimFactor] = getRateChangeFactors(audioRC);
  audioSrc.SamplesPerFrame = ceil(spf / fs * audioSrc.SampleRate / decimFactor) * decimFactor;
end

x = audioRC(audioSrc());
x = x(1:spf,1);
end
