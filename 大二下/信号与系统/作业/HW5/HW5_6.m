t=-2:0.01:2;
y=1/2*t;
subplot(4,1,1);
plot(t,y);
axis([-2.5 2.5 -1.5 1.5])

xn1=zeros(size(t));
for i=1:400
    for k=1:10
        xn1(i)=xn1(i)+2/pi*(-1)^(k+1)/k*sin(k*pi/2*t(i));
    end
end
subplot(4,1,2);
plot(t,xn1);
axis([-2.5 2.5 -1.5 1.5])

xn2=zeros(size(t));
for i=1:400
    for k=1:100
        xn2(i)=xn2(i)+2/pi*(-1)^(k+1)/k*sin(k*pi/2*t(i));
    end
end
subplot(4,1,3);
plot(t,xn2);
axis([-2.5 2.5 -1.5 1.5])

xn3=zeros(size(t));
for i=1:400
    for k=1:1000
        xn3(i)=xn3(i)+2/pi*(-1)^(k+1)/k*sin(k*pi/2*t(i));
    end
end
subplot(4,1,4);
plot(t,xn3);
axis([-2.5 2.5 -1.5 1.5])
