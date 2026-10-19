% 数据录入区域
% Cache 大小 (Bytes)
sizes = [4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072];

% 指令 Cache 命中率 (Instruction Hit Rate)
i_hit_rates = [0.0000, 0.0000, 0.0034, 0.0101, 0.2636, 0.3687, 0.4548, 0.5368, ...
               0.7548, 0.8620, 0.9057, 0.9747, 0.9864, 0.9885, 0.9885, 0.9885];

% 数据 Cache 命中率 (Data Hit Rate)
d_hit_rates = [0.0604, 0.1454, 0.2622, 0.3659, 0.4521, 0.5395, 0.7243, 0.8448, ...
               0.9080, 0.9532, 0.9656, 0.9726, 0.9806, 0.9806, 0.9806, 0.9806];

% 绘图逻辑
figure('Color', 'w'); % 创建白色背景的窗口

% 使用半对数坐标系绘图 (X轴为对数刻度)
semilogx(sizes, i_hit_rates, '-bo', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', 'Instruction Hit Rate');
hold on; 
semilogx(sizes, d_hit_rates, '-rs', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', 'Data Hit Rate');

% 设置 X 轴刻度，使其以 2 的幂次显示
set(gca, 'XScale', 'log', 'XTick', sizes);
xtickangle(45);

% 设置坐标轴标签和标题
xlabel('Cache Size (Bytes) - Log Scale', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Hit Rate', 'FontSize', 12, 'FontWeight', 'bold');
title('Working Set Characterization (spice.trace)', 'FontSize', 14);

% 添加网格和图例
grid on;
grid minor; 
legend('Location', 'southeast', 'FontSize', 10); 

% 设置 Y 轴范围 (0 到 1.05)
ylim([0, 1.05]);

hold off;