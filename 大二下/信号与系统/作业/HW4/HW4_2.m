t_values=-5:1:5;
f=@(w,t1,t) 2/pi*(sin(w/2)).^2.*cos(w.*(t-t1))./(w.*sin(w));
% 注意！此时是矩阵内的元素进行运算 因此需要.参与

I=zeros(size(t_values));
for i=1:length(t_values)
    t=t_values(i);% 核心思想 依次对参数赋值
    current_f=@(w,t1)f(w,t1,t);
    I(i)=integral2(current_f,0,50,0,2);
end

plot(t_values,I);