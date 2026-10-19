% 基础参数设置（保持不变）
miu0 = 4*pi*1e-7;
eps0 = 1e-9/(36*pi);
miu1 = miu0; eps1 = 4*eps0;
miu2 = miu0; eps2 = eps0;
Ei0 = 5; w = 2*pi*1e8;
[x, z] = meshgrid(-5:0.2:5, -5:0.2:5);  % 网格范围

% 布鲁斯特角参数（计算不变）
thetaB = atan(sqrt(eps2/eps1));
sin_theta1 = sin(thetaB); cos_theta1 = cos(thetaB);
k1 = w*sqrt(miu1*eps1); k2 = w*sqrt(miu2*eps2);
kx1 = k1*sin_theta1; kz1 = k1*cos_theta1;
sin_theta2 = (k1/k2)*sin_theta1; cos_theta2 = sqrt(1-sin_theta2.^2);
kx2 = k2*sin_theta2; kz2 = k2*cos_theta2;
eta1 = sqrt(miu1/eps1); eta2 = sqrt(miu2/eps2);

% 初始化图形（添加hold on避免重绘覆盖）
figure('Position', [100 100 800 600])
ax1 = subplot(2,1,1); hold(ax1, 'on');
ax2 = subplot(2,1,2); hold(ax2, 'on');

% 预计算初始场（t=0）
t = 0;
[Ei_x, Ei_z, Hi_y, Et_x, Et_z, Ht_y] = calculate_fields(t, x, z, w, kx1, kz1, kx2, kz2, Ei0, eta1, eta2, cos_theta1, sin_theta1, cos_theta2, sin_theta2);
Ex1 = Ei_x.*(z<0) + Et_x.*(z>=0);
Ez1 = Ei_z.*(z<0) + Et_z.*(z>=0);
Hy1 = Hi_y.*(z<0) + Ht_y.*(z>=0);

% 初始绘图（保存句柄并设置属性）
quiver_handle = quiver(ax1, x, z, Ex1, Ez1, 0.5, 'Color', [0 0.5 1], 'LineWidth', 0.8);
contour_handle = contour(ax2, x, z, Hy1, 20, 'LineWidth', 1);
colormap(ax2, jet);

% 动画参数（增加时间范围，确保波传播可见）
num_frames = 200;  % 更多帧数
dt = 2*pi/(w*10);  % 更小时间步，更慢速度

% 动画循环（关键：每次更新后强制刷新，且不清除背景）
for frame = 1:num_frames
    t = frame*dt;
    
    % 计算当前场
    [Ei_x, Ei_z, Hi_y, Et_x, Et_z, Ht_y] = calculate_fields(t, x, z, w, kx1, kz1, kx2, kz2, Ei0, eta1, eta2, cos_theta1, sin_theta1, cos_theta2, sin_theta2);
    Ex1 = Ei_x.*(z<0) + Et_x.*(z>=0);
    Ez1 = Ei_z.*(z<0) + Et_z.*(z>=0);
    Hy1 = Hi_y.*(z<0) + Ht_y.*(z>=0);
    
    % 更新电场（直接修改句柄数据，不重绘整个图）
    set(quiver_handle, 'UData', Ex1, 'VData', Ez1);
    
    % 更新磁场（先删除旧等高线，再绘制新的，保持颜色映射）
    delete(contour_handle);
    contour_handle = contour(ax2, x, z, Hy1, 20, 'LineWidth', 1);
    
    % 强制刷新，确保每帧更新
    drawnow('expose');  % 更高效的刷新，避免延迟
    pause(0.01);  % 控制速度，可调整
end

% 场计算函数（保持不变）
function [Ei_x, Ei_z, Hi_y, Et_x, Et_z, Ht_y] = calculate_fields(t, x, z, w, kx1, kz1, kx2, kz2, Ei0, eta1, eta2, cos_theta1, sin_theta1, cos_theta2, sin_theta2)
    phase1 = w*t - (kx1*x + kz1*z);
    Ei_x = Ei0*cos_theta1 * cos(phase1);
    Ei_z = Ei0*sin_theta1 * cos(phase1);
    Hi_y = Ei0/eta1 * cos(phase1);
    
    phase2 = w*t - (kx2*x + kz2*z);
    Et_x = Ei0*cos_theta2 * cos(phase2);
    Et_z = Ei0*sin_theta2 * cos(phase2);
    Ht_y = Ei0/eta2 * cos(phase2);
end