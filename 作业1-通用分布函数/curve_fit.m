%% 风电功率分布拟合 MATLAB 版
clear; clc; close all;

bin_num = "04"; % "12"
fit_single_bin(bin_num);

fprintf('任务完成！已生成：\n- CDF图: cdf_fit_png\n- PDF图: pdf_fit_png\n- 参数表: para_fit_txt\n');

%% 核心拟合函数
function fit_single_bin(bin_num)
    csv_name = fullfile(['Pw_bin_', bin_num, '.csv']);

    % --- 加载数据 ---
    opts = detectImportOptions(csv_name);
    T = readtable(csv_name, opts);
    data = T.value;
    data = data(~isnan(data)); % 去除NaN
    data_sorted = sort(data);
    
    n = length(data_sorted);
    y_actual_cdf = linspace(0, 1, n)';
    x_range = linspace(0, 1, 500)';

    % --- 定义分布模型 ---
    % Versatile CDF: (1 + exp(-a*(x-c)))^-b
    % p(1)=a, p(2)=b, p(3)=c
    versatile_cdf_func = @(p, x) (1 + exp(-min(max(-p(1)*(x-p(3)), -700), 700))).^(-p(2));
    
    % Versatile PDF
    versatile_pdf_func = @(p, x) (p(1)*p(2)*exp(-min(max(-p(1)*(x-p(3)), -700), 700))) ./ ...
                         ((1 + exp(-min(max(-p(1)*(x-p(3)), -700), 700))).^(p(2)+1));

    % --- 拟合计算 ---
    
    % 1. 高斯分布 (MLE)
    [mu, std_dev] = normfit(data);

    % 2. Beta 分布 (MLE)
    % 注意：MATLAB betafit 要求数据在 (0,1) 之间，进行极小值修正
    data_beta = data;
    data_beta(data_beta <= 0) = 0.0001;
    data_beta(data_beta >= 1) = 0.9999;
    beta_paras = betafit(data_beta);
    a_beta = beta_paras(1); b_beta = beta_paras(2);

    % 3. Versatile 分布拟合 (基于非线性最小二乘)
    p0 = [15, 1.2, 0.4];
    lb = [0.01, 0.01, 0.0];
    ub = [1000.0, 10.0, 1.0];
    
    options = optimset('Display','off', 'MaxIter', 5000, 'MaxFunEvals', 10000);
    try
        popt = lsqcurvefit(versatile_cdf_func, p0, data_sorted, y_actual_cdf, lb, ub, options);
    catch
        % 重试逻辑
        p0_retry = [5.0, 1.0, 0.2];
        popt = lsqcurvefit(versatile_cdf_func, p0_retry, data_sorted, y_actual_cdf, lb, ub, options);
    end
    a_v = popt(1); b_v = popt(2); c_v = popt(3);

    % --- 绘制 CDF 曲线 ---
    figure('Visible', 'off'); hold on;
    % 采样绘制散点以防过密
    idx = 1:floor(n/40):n;
    scatter(data_sorted(idx), y_actual_cdf(idx), 'k', 'LineWidth', 1);
    plot(x_range, normcdf(x_range, mu, std_dev), 'LineWidth', 1.5);
    plot(x_range, betacdf(x_range, a_beta, b_beta), 'LineWidth', 1.5);
    plot(x_range, versatile_cdf_func(popt, x_range), 'r--', 'LineWidth', 2);
    
    xlabel('Probabilistic wind power output'); ylabel('CDF');
    legend('Actual', 'Gaussian', 'Beta', 'Versatile', 'Location', 'Best');
    title(['Comparison of CDF Fitting - Bin ', bin_num]);
    grid on;
    saveas(gcf, cdf_name);
    close(gcf);

    % --- 绘制 PDF 曲线 ---
    figure('Visible', 'off'); hold on;
    [counts, edges] = histcounts(data, 100, 'BinLimits', [0, 1], 'Normalization', 'pdf');
    centers = (edges(1:end-1) + edges(2:end)) / 2;
    scatter(centers, counts, 'k', 'LineWidth', 1);
    
    plot(x_range, normpdf(x_range, mu, std_dev), 'LineWidth', 1.5);
    plot(x_range, betapdf(x_range, a_beta, b_beta), 'LineWidth', 1.5);
    plot(x_range, versatile_pdf_func(popt, x_range), 'r--', 'LineWidth', 2);
    
    xlabel('Probabilistic wind power output'); ylabel('PDF');
    legend('Actual (Binned)', 'Gaussian', 'Beta', 'Versatile', 'Location', 'Best');
    title(['Comparison of PDF Fitting - Bin ', bin_num]);
    grid on;
    saveas(gcf, pdf_name);
    close(gcf);

    % --- RMSE 评估 ---
    n_o = 100;
    eval_points = linspace(1/n_o, 1, n_o)';
    actual_cdf_at_eval = interp1(data_sorted, y_actual_cdf, eval_points, 'linear', 'extrap');
    
    rmse_g = sqrt(mean((actual_cdf_at_eval - normcdf(eval_points, mu, std_dev)).^2));
    rmse_b = sqrt(mean((actual_cdf_at_eval - betacdf(eval_points, a_beta, b_beta)).^2));
    rmse_v = sqrt(mean((actual_cdf_at_eval - versatile_cdf_func(popt, eval_points)).^2));

    % --- 写入 TXT ---
    fid = fopen(txt_name, 'w');
    fprintf(fid, '--- Fitting Parameters ---\n');
    fprintf(fid, 'Gaussian: mu=%.4f, std=%.4f\n', mu, std_dev);
    fprintf(fid, 'Beta: a=%.4f, b=%.4f\n', a_beta, b_beta);
    fprintf(fid, 'Versatile: a=%.4f, b=%.4f, c=%.4f\n\n', a_v, b_v, c_v);
    fprintf(fid, '--- RMSE Evaluation ---\n');
    fprintf(fid, 'Gaussian RMSE:  %.5f\n', rmse_g);
    fprintf(fid, 'Beta RMSE:      %.5f\n', rmse_b);
    fprintf(fid, 'Versatile RMSE: %.5f (Optimal)\n', rmse_v);
    fclose(fid);
    
    fprintf('Bin %s: finished fitting.\n', bin_num);
end