t=0:0.001:1;
y=t.^4;
subplot(6,1,1);
plot(t,y);
axis([-1 2 -1.5 1.5])

x = 0:0.001:1;
y1 = zeros(size(x));
for i=1:1000
    y1(i)=1;
end
subplot(6,1,2)
plot(x, y1);
axis([-1 2 -1.5 1.5])

y2 = zeros(size(x));
for i=1:1000
    y2(i)=2*x(i)-1;
end
subplot(6,1,3)
plot(x, y2);
axis([-1 2 -1.5 1.5])

y3 = zeros(size(x));
for i=1:1000
    y3(i)=6*x(i)^2-6*x(i)+1;
end
subplot(6,1,4)
plot(x, y3);
axis([-1 2 -1.5 1.5])

y4 = zeros(size(x));
for i=1:1000
    y4(i)=20*x(i).^3-30*x(i).^2+12*x(i)-1;
end
subplot(6,1,5)
plot(x, y4);
axis([-1 2 -1.5 1.5])

y5=1/5*y1+2/5*y2+2/7*y3+1/10*y4;
subplot(6,1,6)
plot(x, y5);
axis([-1 2 -1.5 1.5])