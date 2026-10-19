t=0:0.001:1;
y=t.^3;
subplot(5,1,1);
plot(t,y);
axis([-1 2 -1.5 1.5])

x = 0:0.001:1;
y1 = zeros(size(x));
for i=1:1000
    y1(i)=1;
end
subplot(5,1,2)
plot(x, y1);
axis([-1 2 -1.5 1.5])

y2 = zeros(size(x));
for i=1:1000
    y2(i)=x(i)-0.5;
end
subplot(5,1,3)
plot(x, y2);
axis([-1 2 -1.5 1.5])

y3 = zeros(size(x));
for i=1:1000
    y3(i)=x(i)^2-x(i)-5/6;
end
subplot(5,1,4)
plot(x, y3);
axis([-1 2 -1.5 1.5])

y4 = zeros(size(x));
for i=1:1000
    y4(i)=1/4+9/10*(x(i)-0.5)-87/362*(x(i)^2-x(i)-5/6);
end
subplot(5,1,5)
plot(x, y4);
axis([-1 2 -1.5 1.5])
