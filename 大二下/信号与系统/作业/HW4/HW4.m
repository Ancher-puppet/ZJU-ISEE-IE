t=-20:1:20;
%t 的范围
f=@(w) 2/pi*(sin(w/2)).^2.*cos(w.*t)./(w.*sin(w));
% 被积函数
I=integral(f,0,50,'ArrayValued',true);
%将该标志设为 true 或 1，以指示 fun 是接受标量输入并返回向量、矩阵或 N 维数组输出的函数。
plot(t,I);



