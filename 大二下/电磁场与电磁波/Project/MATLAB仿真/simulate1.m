% 基础参数设置
miu0 = 4*pi*1e-7;        % 真空磁导率
eps0 = 1e-9/(36*pi);     % 真空介电常数
miu1 = miu0;             % 介质1磁导率（非磁性介质）
eps1 = 4*eps0;           % 介质1介电常数（n1=√(eps1/eps0)=2）
miu2 = miu0;             % 介质2磁导率
eps2 = eps0;             % 介质2介电常数（n2=√(eps2/eps0)=1）
Ei0 = 5;                 % 入射电场振幅（V/m）
w = 2*pi*1e8;            % 角频率（ω=2πf, f=100MHz）
t = 0;                   % 固定时间观察瞬时场（可修改t观察动态）

k1 = w*sqrt(miu1*eps1);  % 介质1波数
k2 = w*sqrt(miu2*eps2);  % 介质2波数
eta1 = sqrt(miu1/eps1);  % 介质1波阻抗（η=√(μ/ε)）
eta2 = sqrt(miu2/eps2);  % 介质2波阻抗

[x, z] = meshgrid(-20:0.5:20, -20:0.5:20);

%入射角为布鲁斯特角时
thetaB = atan(sqrt(eps2/eps1));
% 入射波参数（z<0，介质1）
sin_theta1 = sin(thetaB);
cos_theta1 = cos(thetaB);
kx1 = k1*sin_theta1;  % 切向波数（x分量）
kz1 = k1*cos_theta1;  % 法向波数（z分量）

Ei_x = Ei0*cos_theta1 * cos(w*t - (kx1*x + kz1*z));  % Ex分量（切向）
Ei_z = Ei0*sin_theta1 * cos(w*t - (kx1*x + kz1*z));  % Ez分量（法向）
Hi_y = Ei0/eta1 * cos(w*t - (kx1*x + kz1*z));         % Hy分量（磁场，垂直入射面）

% 折射波参数（z>0，介质2，布儒斯特角时R_TM=0）
sin_theta2 = (k1/k2)*sin_theta1;  % 折射定律（k1 sinθ1 = k2 sinθ2）
cos_theta2 = sqrt(1 - sin_theta2^2);
kx2 = k2*sin_theta2;  % 切向波数
kz2 = k2*cos_theta2;  % 法向波数
Et_x = Ei0*cos_theta2 * cos(w*t - (kx2*x + kz2*z));  % 折射波z分量为负（向z>0传播）
Et_z = Ei0*sin_theta2 * cos(w*t - (kx2*x + kz2*z));
Ht_y = Ei0/eta2 * cos(w*t - (kx2*x + kz2*z));

Ex1 = Ei_x.*(z<0) + Et_x.*(z>=0);
Ez1 = Ei_z.*(z<0) + Et_z.*(z>=0);
Hy1 = Hi_y.*(z<0) + Ht_y.*(z>=0);

subplot(2,1,1);
quiver(x, z, Ex1, Ez1, 0.5);
title('情况1：布儒斯特角入射-电场分布');
xlabel('x (m)'); ylabel('z (m)');
axis tight;

subplot(2,1,2);
contour(x, z, Hy1, 20);
title('情况1：布儒斯特角入射-磁场分布');
xlabel('x (m)'); ylabel('z (m)');
axis tight;
