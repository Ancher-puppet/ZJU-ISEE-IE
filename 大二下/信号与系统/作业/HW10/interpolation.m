tmin1=-4;tmax1=4;dt=0.01;
t=tmin1:dt:tmax1;
x=0.3*sin(2*pi*t)+0.4*cos(2.5*pi*t+pi/4)+0.3*cos(pi*t+pi/3);
figure(1);
plot(t,x);
ylabel("原信号");
axis([-4,4,-1.25,1.25]);

T1=0.25;
tmin=-500*T1;tmax=500*T1;
wc=pi/T1;
A=wc*T1/pi;
t1=tmin:T1:tmax;%共1001个样本点
xn1=0.3*sin(2*pi*t1)+0.4*cos(2.5*pi*t1+pi/4)+0.3*cos(pi*t1+pi/3);%信号采样值

n1=length(t);
for m1=1:n1
    y1=A*sinc(wc*(t(m1)-t1)/pi);
    y(m1)=xn1*y1';%实际在求和
end
figure(2);
subplot(2,1,1);
stem(t1,xn1);
ylabel("取样值");
axis([-4,4,-1.25,1.25]);

subplot(2,1,2);
plot(t,y);
ylabel("重建信号");
axis([-4,4,-1.25,1.25]);


T2=0.5;
tmin=-500*T2;tmax=500*T2;
wc=pi/T2;
A=wc*T2/pi;
t2=tmin:T2:tmax;%共1001个样本点
xn2=0.3*sin(2*pi*t2)+0.4*cos(2.5*pi*t2+pi/4)+0.3*cos(pi*t2+pi/3);%信号采样值

for m2=1:n1
    z1=A*sinc(wc*(t(m2)-t2)/pi);
    z(m2)=xn2*z1';%实际在求和
end
figure(3);
subplot(3,1,1);
stem(t2,xn2);
ylabel("取样值");
axis([-4,4,-1.25,1.25]);

subplot(3,1,2);
plot(t,z);
ylabel("重建信号");
axis([-4,4,-1.25,1.25]);

