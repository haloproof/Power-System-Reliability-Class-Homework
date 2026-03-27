% monte_carlo.m
function monte_carlo_main()
    clear; clc;
    
    % --- 1. 参数与常量定义 ---
    % 定义时间节点字符串，用于生成CSV表头
    TIME_LABELS = {
        'T2024_10_01_08_00', 'T2024_10_01_08_15', 'T2024_10_01_08_30', ...
        'T2024_10_01_08_45', 'T2024_10_01_09_00', 'T2024_10_01_09_15', ...
        'T2024_10_01_09_30', 'T2024_10_01_09_45'};

    PAST_P = [0.85, 0.823, 0.711, 0.774, 0.854, 0.918, 0.914, 0.881];
    FORECAST_P = [0.885, 0.868, 0.776, 0.668, 0.611, 0.594, 0.558, 0.452];
    TRUE_P = [0.901, 0.834, 0.709, 0.632, 0.609, 0.564, 0.487, 0.264];
    
    BIN_COUNT = 25;
    BIN_WIDTH = 1.0 / BIN_COUNT;
    
    N = 1000;
    seed_val = 12345;
    
    % 创建输出文件夹
    out_folder = 'output_2';
    if ~exist(out_folder, 'dir')
        mkdir(out_folder);
    end
    
    % --- 2. 核心逻辑执行 ---
    % 读取分布参数
    params_map = load_params('versatile_params.csv');
    
    % 蒙特卡洛抽样
    [scenarios, ci_bounds] = sample_scenarios(params_map, FORECAST_P, N, seed_val, BIN_COUNT, BIN_WIDTH);
    
    % 统计与保存CSV
    out = analyze_and_save(scenarios, ci_bounds, N, TIME_LABELS, out_folder);
    
    % 绘图
    plot_path = plot_scenarios(scenarios, ci_bounds, N, PAST_P, TRUE_P, FORECAST_P, out_folder);
    
    % 输出终端日志
    fprintf('Outputs:\n');
    fprintf(' - scenarios CSV: %s\n', out.scenarios_csv);
    fprintf(' - scenarios plot PNG: %s\n', plot_path);
    fprintf(' - Proportion of points within 90%% CI per time point:\n');
    disp(out.per_time_props);
    fprintf(' - Overall proportion of points within 90%% CI: %.4f\n\n', out.overall_prop);
    
    % 收敛性测试
    Ns_test = [100, 1000];
    conv_results = convergence_test(params_map, FORECAST_P, Ns_test, seed_val, BIN_COUNT, BIN_WIDTH);
    fprintf('Convergence check (mean - forecast) for Ns=100,1000:\n');
    for i = 1:length(conv_results)
        r = conv_results(i);
        txt_path = fullfile(out_folder, sprintf('summary_N%d.txt', r.N));
        fid = fopen(txt_path, 'w');
        fprintf(fid, 'N=%d:\n', r.N);
        fprintf(fid, 'Mean profile: %s\n', mat2str(r.mean_profile, 4));
        fprintf(fid, 'Difference from forecast: %s\n', mat2str(r.diff, 4));
        fclose(fid);
        
        fprintf('N=%d:\n', r.N);
        fprintf('Mean profile: %s\n', mat2str(r.mean_profile, 4));
        fprintf('Difference: %s\n\n', mat2str(r.diff, 4));
    end
end

% =========================================================================
% Local Functions
% =========================================================================

function params = load_params(csv_path)
    % 读取参数矩阵，假设格式：序号, a, b, c
    M = readmatrix(csv_path);
    params = zeros(25, 3);
    for i = 1:size(M, 1)
        idx = M(i, 1);
        params(idx, 1) = M(i, 2); % a
        params(idx, 2) = M(i, 3); % b
        params(idx, 3) = M(i, 4); % c
    end
end

function idx = value_to_bin_index(v, BIN_COUNT, BIN_WIDTH)
    if v >= 1.0
        idx = BIN_COUNT;
        return;
    end
    if v < 0.0
        idx = 1;
        return;
    end
    idx = floor(v / BIN_WIDTH) + 1;
    idx = max(1, min(BIN_COUNT, idx));
end

function vals = inv_cdf(u, a, b, c)
    eps_val = 1e-12;
    % 将u限制在合理范围内
    u = max(eps_val, min(1 - eps_val, u));
    
    power_val = u .^ (-1.0 / b);
    inner = power_val - 1.0;
    % 确保对数内的值大于0
    inner = max(1e-300, inner);
    vals = c - (1.0 / a) * log(inner);
end

function [scenarios, ci_bounds] = sample_scenarios(params_map, FORECAST_P, N, seed_val, BIN_COUNT, BIN_WIDTH)
    rng(seed_val, 'twister'); % 设定随机数种子
    M = length(FORECAST_P);
    scenarios = zeros(N, M);
    ci_bounds = zeros(M, 2);
    
    for j = 1:M
        p = FORECAST_P(j);
        idx = value_to_bin_index(p, BIN_COUNT, BIN_WIDTH);
        
        a = params_map(idx, 1);
        b = params_map(idx, 2);
        c = params_map(idx, 3);
        
        % 抽样 N 个 u ~ Uniform(0,1)
        u = rand(N, 1);
        samples = round(inv_cdf(u, a, b, c), 4);
        scenarios(:, j) = samples;
        
        % 90% 置信区间
        lo = round(inv_cdf(0.05, a, b, c), 4);
        hi = round(inv_cdf(0.95, a, b, c), 4);
        ci_bounds(j, :) = [lo, hi];
    end
end

function out = analyze_and_save(scenarios, ci_bounds, N, TIME_LABELS, out_folder)
    % 1. 保存为 CSV
    scen_csv = fullfile(out_folder, sprintf('scenarios_N%d.csv', N));
    T = array2table(scenarios, 'VariableNames', TIME_LABELS);
    writetable(T, scen_csv);
    
    % 2. 验证抽样点落在 90% 解析置信区间内的比例
    total_points = numel(scenarios);
    inside_total = 0;
    M = size(scenarios, 2);
    per_time_props = zeros(1, M);
    
    for j = 1:M
        lo = ci_bounds(j, 1);
        hi = ci_bounds(j, 2);
        col = scenarios(:, j);
        
        inside_j = sum(col >= lo & col <= hi);
        per_time_props(j) = inside_j / N;
        inside_total = inside_total + inside_j;
    end
    overall_prop = inside_total / total_points;
    
    out.scenarios_csv = scen_csv;
    out.per_time_props = per_time_props;
    out.overall_prop = overall_prop;
end

function results = convergence_test(params_map, FORECAST_P, Ns, seed_val, BIN_COUNT, BIN_WIDTH)
    results = struct('N', {}, 'mean_profile', {}, 'diff', {});
    for i = 1:length(Ns)
        N = Ns(i);
        [scenarios, ~] = sample_scenarios(params_map, FORECAST_P, N, seed_val, BIN_COUNT, BIN_WIDTH);
        mean_profile = mean(scenarios, 1);
        diff_val = mean_profile - FORECAST_P;
        
        results(i).N = N;
        results(i).mean_profile = mean_profile;
        results(i).diff = diff_val;
    end
end

function plot_path = plot_scenarios(scenarios, ci_bounds, N, PAST_P, TRUE_P, FORECAST_P, out_folder)
    % 构建完整的时间序列: 06:00 到 09:45，步长15分钟
    t_start = datetime(2024, 10, 1, 6, 0, 0);
    t_end = datetime(2024, 10, 1, 9, 45, 0);
    full_idx = t_start : minutes(15) : t_end;
    
    fig = figure('Position', [100, 100, 1000, 500], 'Visible', 'off');
    hold on;
    
    % 数据段落对齐
    len_past = length(PAST_P);
    len_future = length(FORECAST_P);
    idx_future = (length(full_idx) - len_future + 1) : length(full_idx);
    x_future = full_idx(idx_future);
    
    % 1. 绘制所有的 Scenarios (为了视觉效果，使用非常浅的颜色和细线)
    % 使用 rgba 控制透明度，R2021a+ 支持
    color_scenario = [0, 0.4470, 0.7410, 0.05]; 
    h_scen = plot(x_future, scenarios', 'Color', color_scenario, 'LineWidth', 0.5);
    
    % 2. 绘制 90% 置信区间 (08:00 - 09:45)
    ci_lo = ci_bounds(:, 1)';
    ci_hi = ci_bounds(:, 2)';
    x_fill = [x_future, fliplr(x_future)];
    y_fill = [ci_lo, fliplr(ci_hi)];
    h_ci = fill(x_fill, y_fill, [1, 0.647, 0], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    
    % 3. 绘制真实值 (06:00 - 09:45)
    true_vals = NaN(1, length(full_idx));
    true_vals(1:len_past) = PAST_P;
    true_vals(idx_future) = TRUE_P;
    h_true = plot(full_idx, true_vals, '-ro', 'LineWidth', 1.5, 'MarkerFaceColor', 'r');
    
    % 4. 绘制预测值 (08:00 - 09:45)
    h_fore = plot(x_future, FORECAST_P, '--bs', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
    
    % 格式化图表
    xticks(full_idx);
    xtickformat('HH:mm'); % 仅保留时:分
    xlim([full_idx(1), full_idx(end)]);
    xlabel('Time (06:00 - 09:45)');
    ylabel('Value');
    title(sprintf('Monte Carlo Scenarios (N=%d) — True, Scenarios, 90%% CI, Forecast', N));
    
    % 图例 (只取一根 scenario 曲线用于显示图例)
    legend([h_true, h_scen(1), h_ci, h_fore], ...
        {'True (06:00-09:45)', 'Scenarios', '90% CI (08:00-09:45)', 'Forecast (08:00-09:45)'}, ...
        'Location', 'best');
    
    grid on;
    hold off;
    
    % 保存并关闭图像
    plot_path = fullfile(out_folder, sprintf('scenarios_plot_N%d.png', N));
    saveas(fig, plot_path);
    close(fig);
end