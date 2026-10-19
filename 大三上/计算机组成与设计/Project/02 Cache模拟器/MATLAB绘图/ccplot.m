% 数据录入区域
% Cache 大小 (Bytes)
sizes = [4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072];

% 指令 Cache 命中率 (Instruction Hit Rate)
i_hit_rates = [0.0000, 0.0000, 0.0047, 0.0353, 0.1194, 0.2023, 0.3010, 0.3993, 0.4736, 0.5930, 0.7360, 0.8684, 0.9360, 0.9492, 0.9511, 0.9588];

% 数据 Cache 命中率 (Data Hit Rate)
d_hit_rates = [0.0676, 0.1373, 0.2229, 0.3330, 0.4366, 0.5502, 0.6583, 0.7523, 0.8344, 0.8766, 0.9105, 0.9437, 0.9555, 0.9606, 0.9618, 0.9618];

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