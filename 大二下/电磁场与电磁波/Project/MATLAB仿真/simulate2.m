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

%入射角大于临界角
if eps1 > eps2  % 仅当n1>n2时存在临界角
    thetaC = asin(sqrt(eps2/eps1));  % 临界角（rad）
    theta1 = thetaC + 10*pi/180;     % 入射角大于临界角（+10°）
    sin_theta1 = sin(theta1);
    cos_theta1 = cos(theta1);
    kx1 = k1*sin_theta1;             % 切向波数（x分量，rad/m）
    kz1 = k1*cos_theta1;            % 介质1法向波数（z分量，rad/m）

    % 全反射时折射波为倏逝波（kz2为虚数，指数衰减）
    sin_theta2 = (k1/k2)*sin_theta1;  % 折射定律（此时sinθ2>1）
    kz2 = -1i*k2*sqrt(sin_theta2^2 - 1);  % 虚数法向波数 (rad/m)
    alpha = k2*sqrt(sin_theta2^2 - 1);

    % 反射系数（幅值1，相位变化）
    R_TM = (eps1*kz2-eps2*kz1)/(eps1*kz2+eps2*kz1);

    % 入射波+反射波（z<0，磁场为实数）
    Er_x = R_TM * Ei0 * cos_theta1 .* cos(w*t + (kx1*x + kz1*z));  % 反射波Ex分量（复数）
    Er_z = R_TM * Ei0 * sin_theta1 .* cos(w*t + (kx1*x + kz1*z));  % 反射波Ez分量（复数）
    Ei_total_x = real(Ei_x + Er_x);  % 取实部（关键修正：电场为实数）
    Ei_total_z = real(Ei_z + Er_z);  % 取实部

    Hr_y = -R_TM * (Ei0 / eta1) .* cos(w*t + (kx1*x + kz1*z));     % 反射磁场（复数）(相位差 180°）
    Hi_total_y = real(Hi_y + Hr_y);  % 取实部（关键修正：磁场为实数）

    % 透射波（z>0）
    Et_x = Ei0 * cos_theta1 .* exp(-alpha*z) .* cos(w*t - kx1*x);  % 倏逝波Ex分量（实数）
    Et_z = Ei0 * sin_theta1 .* exp(-alpha*z) .* cos(w*t - kx1*x);  % 倏逝波Ez分量（实数）
    Ht_y = (Ei0 / eta2) .* exp(-alpha*z) .* cos(w*t - kx1*x);       % 倏逝波磁场（实数）

    % 合成场（z<0为入射+反射波，z≥0为倏逝波）
    Ex2 = Ei_total_x .* (z < 0) + Et_x .* (z >= 0);
    Ez2 = Ei_total_z .* (z < 0) + Et_z .* (z >= 0);
    Hy2 = Hi_total_y .* (z < 0) + Ht_y .* (z >= 0);  % 磁场为实数
end

figure(2);
subplot(2,1,1);
quiver(x, z, Ex2, Ez2, 0.5);
title('情况2：全反射-电场分布');
xlabel('x (m)'); ylabel('z (m)');
axis tight;

subplot(2,1,2);
contour(x, z, Hy2, 20);
title('情况2：全反射-磁场分布');
xlabel('x (m)'); ylabel('z (m)');
axis tight;