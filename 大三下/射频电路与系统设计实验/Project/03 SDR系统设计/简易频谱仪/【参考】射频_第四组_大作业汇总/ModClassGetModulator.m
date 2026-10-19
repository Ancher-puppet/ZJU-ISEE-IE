function modulator = ModClassGetModulator(modType, sps, fs)

switch modType
  case "BPSK"
    modulator = @(x)bpskModulator(x,sps);
  case "FM"
    modulator = @(x)fmModulator(x, fs);
  case "AM"
    modulator = @(x)amModulator(x, fs);
  case "ASK"
    modulator = @(x)askModulator(x, sps);
  case "FSK"
    modulator = @(x)fskModulator(x, sps, fs);
end
end

function y = bpskModulator(x,sps)
%bpskModulator BPSK modulator with pulse shaping
persistent filterCoeffs
if isempty(filterCoeffs)
  filterCoeffs = rcosdesign(0.35, 4, sps);
end
syms = pskmod(x,2);
y = filter(filterCoeffs, 1, upsample(syms,sps));
end

function y = fmModulator(x,fs)
%fmModulator Broadcast FM modulator
persistent mod
if isempty(mod)
  mod = comm.FMBroadcastModulator(...
    'AudioSampleRate', fs, ...
    'SampleRate', fs);
end
y = mod(x);
end

function y = amModulator(x,fs)
%amModulator Standard AM modulator (DSB-AM)
%   IF frequency is 50 kHz.
y = ammod(x,50e3,fs);
end

function y = askModulator(x,sps)
%askModulator 2-ASK modulator with pulse shaping
persistent filterCoeffs
if isempty(filterCoeffs)
  filterCoeffs = rcosdesign(0.35, 4, sps);
end
y = filter(filterCoeffs, 1, upsample(x, sps));
end

function y = fskModulator(x,sps,fs)
%fskModulator 2-FSK modulator, frequency separation 50kHz
persistent mod
if isempty(mod)
  mod = comm.FSKModulator('ModulationOrder', 2, ...
    'FrequencySeparation', 50e3, ...
    'SamplesPerSymbol', sps, ...
    'SampleRate', fs, ...
    'BitInput', false);
end
y = mod(x);
end
