function C = conv_New(A,B)
% 列表法做卷积。
C = zeros(1,length(A) + length(B)-1);
for i = 1:length(A) 
    C = C + [zeros(1,i-1),A(i)*B, zeros(1,length(A)-i)];%列表法
end
    