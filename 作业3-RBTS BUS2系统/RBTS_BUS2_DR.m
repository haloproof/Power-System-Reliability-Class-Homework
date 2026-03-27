%% 基本潮流数据
clear; clc; close all
load('Load_profiles');
load('RBTS_BUS2_topology');
opt = mpoption('VERBOSE',0,'OUT_ALL',0);
RBTS_BUS2_topology_calculate = RBTS_BUS2_topology;

%% 7种供电状态
branch(:,1)=[1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;0]; % 系统正常运行状态
branch(:,2)=[0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1]; % 馈线1-2断开-转供
branch(:,3)=[1;1;1;1;0;1;1;1;1;1;1;1;1;1;1;1]; % 馈线2-5断开-转供
branch(:,4)=[1;1;1;1;1;1;1;0;1;1;1;1;1;1;1;1]; % 馈线5-8断开-转供
branch(:,5)=[1;1;1;1;1;1;1;1;1;1;0;1;1;1;1;1]; % 馈线8-11断开-转供
branch(:,6)=[1;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1]; % 馈线1-13断开-转供
branch(:,7)=[1;1;1;1;1;1;1;1;1;1;1;1;1;0;1;1]; % 馈线13-15断开-转供

%%% 以下选取第6种：馈线1-13 断开-转供
k = 6; 

%% 阶段0：计算断开-转供的配电网电压问题
RBTS_BUS2_topology_calculate.branch(:,11) = branch(:,k);
for t = 1:96
    % 调用函数更新负荷
    RBTS_BUS2_topology_calculate = apply_load_profiles(RBTS_BUS2_topology_calculate, RBTS_BUS2_topology, Load_profiles, t);
    power_flow_origin{k,t} = runpf(RBTS_BUS2_topology_calculate, opt);
end

%% 阶段0：调整电压后输出 (中间过程图保持原样)
X = 0:0.25:23.75;
figure(1) % 论文Fig.10
for i = 1:16
    for t = 1:96
        V_origin(i,t) = power_flow_origin{k,t}.bus(i,8);
    end
    hold on
    plot(X, V_origin(i,:))
end
V_lowest_origin(1:96) = min(V_origin(:,1:96));
plot(X, 0.95*ones(1,96), '--k')
title('阶段0：故障后电压分布')
savefig('fault_results')

%% 阶段1：OLTC调整
% 1.1 确定OLTC调整时段
load('Best_LTC_position.mat'); 
% 1.2 确定OLTC调整大小
OLTC_final = [1, 1.025, 1.05, 1.0375, 1.0125]; 

% 1.3 计算OLTC调整后的电压
for t = 1:96
    % 调用函数获取当前时间的母线电压
    bus_initial = get_oltc_voltage(t, Best_LTC_position, OLTC_final);
    
    RBTS_BUS2_topology_calculate.gen(1,6) = bus_initial;
    RBTS_BUS2_topology_calculate.bus(1,8) = bus_initial;
    
    % 调用函数更新负荷
    RBTS_BUS2_topology_calculate = apply_load_profiles(RBTS_BUS2_topology_calculate, RBTS_BUS2_topology, Load_profiles, t);
    
    power_flow_before_response{k,t} = runpf(RBTS_BUS2_topology_calculate, opt);
end

%% 阶段1：调整后电压输出 (中间过程图保持原样)
figure(2)  % 论文Fig.11
axis([0 24 0.8 1.1]);
set(gca, 'xtick', 0:1:24)
for i = 1:16
    for t = 1:96
        V_before_response(i,t) = power_flow_before_response{k,t}.bus(i,8);
    end
    hold on
    stairs(X, V_before_response(i,:))
end
V_lowest_before_response(1:96) = min(V_before_response(:,1:96));
plot(X, 0.95*ones(1,96), '--k') % 0.95 p.u. 电压下限
title('阶段1：OLTC调整后电压分布')
savefig('OLTC_results')


%% 阶段2：空调负荷需求响应策略求解及潮流计算
load('Final_result.mat')
OLTC_position = Final_result{1};
P_need = Final_result{3};
P_HVAC_actual = P_need{2}';
P_HVAC_origin = P_need{3}';
Var_delta_P_actual = (P_HVAC_origin - P_HVAC_actual) / 1000;

for t = 1:96
    % 调用函数获取OLTC状态并更新基础负荷
    bus_initial = get_oltc_voltage(t, Best_LTC_position, OLTC_final);
    RBTS_BUS2_topology_calculate.gen(1,6) = bus_initial;
    RBTS_BUS2_topology_calculate.bus(1,8) = bus_initial;
    RBTS_BUS2_topology_calculate = apply_load_profiles(RBTS_BUS2_topology_calculate, RBTS_BUS2_topology, Load_profiles, t);
    
    % 仅在 37 至 84 时段响应空调功率削减
    if (t >= 37 && t <= 84)
        m = t - 36;
        RBTS_BUS2_topology_calculate.bus(7,3)  = RBTS_BUS2_topology_calculate.bus(7,3)  - 3 * Var_delta_P_actual(m);
        RBTS_BUS2_topology_calculate.bus(9,3)  = RBTS_BUS2_topology_calculate.bus(9,3)  - 3 * Var_delta_P_actual(m);
        RBTS_BUS2_topology_calculate.bus(10,3) = RBTS_BUS2_topology_calculate.bus(10,3) - 3 * Var_delta_P_actual(m);
        RBTS_BUS2_topology_calculate.bus(12,3) = RBTS_BUS2_topology_calculate.bus(12,3) - 2 * Var_delta_P_actual(m);
        RBTS_BUS2_topology_calculate.bus(14,3) = RBTS_BUS2_topology_calculate.bus(14,3) - 6 * Var_delta_P_actual(m);
        RBTS_BUS2_topology_calculate.bus(16,3) = RBTS_BUS2_topology_calculate.bus(16,3) - 7 * Var_delta_P_actual(m);
    end
    power_flow_after_response{k,t} = runpf(RBTS_BUS2_topology_calculate, opt);
end

%% 阶段2：调整后电压数据提取
for i = 1:16
    for t = 1:96
        V_after_response(i,t) = power_flow_after_response{k,t}.bus(i,8);
    end
end
V_lowest_after_response(1:96) = min(V_after_response(:, 1:96));


%% ===================== 终图美化部分 =====================

%% 空调负荷的功率对比
X_HVAC = 9:0.25:20.75;
figure('Name', '空调功率需求响应对比', 'Position', [100, 100, 600, 400]); % 设置固定窗口大小，方便导出

% 绘图并调整线宽、使用质感更好的颜色 (十六进制RGB)
stairs(X_HVAC, P_HVAC_origin, 'LineWidth', 2, 'Color', '#0072BD'); % 经典MATLAB蓝
hold on
stairs(X_HVAC, P_HVAC_actual, 'LineWidth', 2, 'Color', '#D95319', 'LineStyle', '-.'); % 经典MATLAB橙，虚线区分

% 坐标轴与网格设置
axis([9 21 100 200]);
set(gca, 'XTick', 9:1:21, 'FontSize', 11, 'FontName', 'Times New Roman', 'LineWidth', 1);
grid on; 
box on; % 加上边框更严谨

% 标签与图例
xlabel('时间 (h)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('空调负荷总功率 (kW)', 'FontSize', 12, 'FontWeight', 'bold');
title('需求响应前后空调负荷功率对比', 'FontSize', 14, 'FontWeight', 'bold');
legend('需求响应前', '需求响应后', 'Location', 'best', 'FontSize', 11, 'Box', 'off'); % 去除图例边框显得清爽
savefig('LoadPower_results')

%% 最低电压曲线对比
figure('Name', '系统最低电压对比', 'Position', [150, 150, 700, 450]);

% 绘制三条曲线，颜色选择对比度高、不刺眼的组合
stairs(X, V_lowest_origin, 'LineWidth', 1.5, 'Color', '#0072BD'); % 蓝
hold on
stairs(X, V_lowest_before_response, 'LineWidth', 1.5, 'Color', '#EDB120'); % 黄
stairs(X, V_lowest_after_response, 'LineWidth', 2, 'Color', '#77AC30'); % 绿，加粗突出最终效果

% 0.95 电压红线警告
plot(X, 0.95*ones(1,96), '--', 'LineWidth', 1.5, 'Color', '#A2142F'); 

% 坐标轴与网格设置
axis([0 24 0.85 1.07]);
set(gca, 'XTick', 0:2:24, 'FontSize', 11, 'FontName', 'Times New Roman', 'LineWidth', 1);
grid on;
box on;

% 标签与图例
xlabel('时间 (h)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('系统最低节点电压 (p.u.)', 'FontSize', 12, 'FontWeight', 'bold');
title('配电网各阶段最低电压曲线演变对比', 'FontSize', 14, 'FontWeight', 'bold');
legend('故障后电压', '仅OLTC调整后电压', '空调负荷需求响应后电压', '系统电压下限 (0.95 p.u.)', ...
    'Location', 'northeast', 'FontSize', 11, 'Box', 'off');
savefig('all_results')