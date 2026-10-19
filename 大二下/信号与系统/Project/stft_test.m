clc;clear;
fs = 4410;
t = 0:1/fs:4-1/fs; 
N = length(t);
f1 = 10; f2 = 20; f3 = 30; f4 = 40;

%stft的问题背景1 fft 得到的频域图无法反映时间变化
x1 = zeros(size(t));
x1(t <= 1) = 10*sin(2*pi*f1*t(t <= 1));
x1(t > 1 & t <= 2) = 20*sin(2*pi*f2*t(t > 1 & t <= 2));
x1(t > 2 & t <= 3) = 30*sin(2*pi*f3*t(t > 2 & t <= 3));
x1(t > 3) = 40*sin(2*pi*f4*t(t > 3));

x2 = flip(x1);

X1=fft(x1);
X1=fftshift(X1);
X2=fft(x2);
X2=fftshift(X2);
freq = (-N/2:N/2-1)*(fs/N);
magX1 = abs(X1)/N;
magX2 = abs(X2)/N;


figure(1);
subplot(2,2,1);
plot(t, x1);
subplot(2,2,2);
plot(t, x2);
subplot(2,2,3); 
plot(freq, magX1); title('信号 x1 频域幅度谱'); xlim([0 100]);
subplot(2,2,4); 
plot(freq, magX2); title('信号 x2 频域幅度谱'); xlim([0 100]);

load('signal1.mat');
load('signal2.mat');
t=t(1:14000); 
N = length(t);
x1=z;
x2=zz;
X1=fft(x1);
X1=fftshift(X1);
X2=fft(x2);
X2=fftshift(X2);
freq = (-N/2:N/2-1)*(fs/N);
magX1 = abs(X1)/N;
magX2 = abs(X2)/N;


figure(2);
subplot(2,2,1);
plot(t, x1);
subplot(2,2,2);
plot(t, x2);
subplot(2,2,3); 
plot(freq, magX1); title('信号 x1 频域幅度谱'); xlim([0 100]);
subplot(2,2,4); 
plot(freq, magX2); title('信号 x2 频域幅度谱'); xlim([0 100]);

%stft的问题背景2 fft 得到的频域图无法反映短时突变信号（由于积分在全局）
x3 = 2 * cos(2 * 10 * t) + 4 * sin(2 * 30 * t) + 6 * cos(2 * 60 *t);
X3 = fftshift(fft(x3));
magX3=abs(X3)/N;
sharp=zeros(1,N);
sharp(4001:5000) = 10 * cos(2 * 90 * linspace(0,1,1000));
x4 = x3 + sharp;
X4 = fftshift(fft(x4));
magX4=abs(X4)/N;
figure(3);
subplot(2,2,1);
plot(t, x3);
subplot(2,2,2);
plot(t, x4);
subplot(2,2,3); 
plot(freq, magX3); title('信号 x3 频域幅度谱'); xlim([0 100]);
subplot(2,2,4); 
plot(freq, magX4); title('信号 x4 频域幅度谱'); xlim([0 100]);

% stft调用参数设置
window_size = 512;
step = window_size/4;  % 25%重叠
nfft = window_size;
% 绘制时频图-可以区分时域
figure(4);
subplot(2,1,1);
[stft, t, f] = mystft(x1, fs, window_size, step, nfft);
imagesc(t, f, abs(stft));  % 转置时频矩阵以匹配横纵轴
xlabel('时间(s)'); ylabel('频率(Hz)');
axis([0,N/fs,-300,300]);
title(['STFT时频图（窗口大小=', num2str(window_size), '）']);
colorbar;

subplot(2,1,2);
[stft, t, f] = mystft(x2, fs, window_size, step, nfft);
imagesc(t, f, abs(stft));  % 转置时频矩阵以匹配横纵轴
xlabel('时间(s)'); ylabel('频率(Hz)');
axis([0,N/fs,-300,300]);
title(['STFT时频图（窗口大小=', num2str(window_size), '）']);
colorbar;

% 探究 stft 不同窗口的影响
figure(5);
for m=6:1:11
    window_size = 2^m;
    step = window_size/4;  % 25%重叠
    nfft = window_size;

    subplot(3,2,m-5);
    [stft, t, f] = mystft(x1, fs, window_size, step, nfft);
    imagesc(t, f, abs(stft));  % 转置时频矩阵以匹配横纵轴
    xlabel('时间(s)'); ylabel('频率(Hz)');
    axis([0,N/fs,-300,300]);
    title(['STFT时频图（窗口大小=', num2str(window_size), '）']);
    colorbar;
end
