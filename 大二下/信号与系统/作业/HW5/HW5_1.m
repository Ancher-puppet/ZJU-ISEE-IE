t=0:0.001:1;
y=sin(pi*t);
subplot(6,1,1);
plot(t,y);
axis([-1 2 -1.5 1.5])

x = -1:0.001:2;
y1 = zeros(size(x));
for i=1000:2000
    y1(i)=1;
end
subplot(6,1,2)
plot(x, y1);
axis([-1 2 -1.5 1.5])

y2 = zeros(size(x));
for i=1000:2000
    if i<=1500
        y2(i)=1;
    else 
        y2(i)=-1;
    end
end
subplot(6,1,3)
plot(x, y2);
axis([-1 2 -1.5 1.5])

y3 = zeros(size(x));
for i=1000:1500
    if i<=1250
        y3(i)=1;
    else 
        y3(i)=-1;
    end
end
subplot(6,1,4)
plot(x, y3);
axis([-1 2 -1.5 1.5])

y4 = zeros(size(x));
for i=1500:2000
    if i<=1750
        y4(i)=1;
    else 
        y4(i)=-1;
    end
end
subplot(6,1,5)
plot(x, y4);
axis([-1 2 -1.5 1.5])

y5=2/pi*y1+0*y2+(2-2*2^0.5)/pi*y3+(2*2^0.5-2)/pi*y4;
subplot(6,1,6)
plot(x, y5);
axis([-1 2 -1.5 1.5])
