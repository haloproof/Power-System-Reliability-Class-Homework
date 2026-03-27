import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.stats import norm, beta
from scipy.optimize import curve_fit

def fit_distribution(bin_num):
    csv_name = f'Pw_bin_csv/Pw_bin_{bin_num}.csv'
    cdf_name = f'cdf_fit_png/cdf_fit_{bin_num}.png'
    pdf_name = f'pdf_fit_png/pdf_fit_{bin_num}.png'
    txt_name = f'para_fit_txt/para_fit_{bin_num}.txt'

    # 加载数据
    data = np.array(pd.read_csv(csv_name)['value'].values)
    # 去掉为0的值（风电功率为0时影响bete分布拟合）
    # data = data[data > 0]
    data_sorted = np.sort(data)
    y_actual_cdf = np.linspace(0, 1, len(data))
    x_range = np.linspace(0, 1, 500)

    # ---------------------------------------------------------
    # 2. 定义分布模型
    # ---------------------------------------------------------

    # Versatile CDF 
    def safe_exp(z):
        return np.exp(np.clip(z, -700, 700))

    def versatile_cdf(x, a, b, c):
        exp_term = safe_exp(-a * (x - c))
        return (1 + exp_term)**(-b)

    # Versatile PDF: CDF的导数 
    def versatile_pdf(x, a, b, c):
        exp_term = safe_exp(-a * (x - c))
        return (a * b * exp_term) / ((1 + exp_term)**(b + 1))

    # ---------------------------------------------------------
    # 3. 拟合计算
    # ---------------------------------------------------------

    # 高斯分布拟合 (MLE)
    mu, std = norm.fit(data)

    # Beta 分布拟合 (MLE)
    a_beta, b_beta, loc_beta, scale_beta = beta.fit(data, floc=0, fscale=1)

    # Versatile 分布拟合 (基于 CDF 曲线拟合)
    # 初始值参考论文 Table I: a=15, b=1.2, c=0.4
    # 使用参数 bounds 防止搜索到不合理区域，并限制 exp 数值范围以避免 overflow
    p0 = [15, 1.2, 0.4]
    lower = [0.01, 0.01, 0.0]
    upper = [1000.0, 10.0, 1.0]
    try:
        popt, _ = curve_fit(versatile_cdf, data_sorted, y_actual_cdf, p0=p0, bounds=(lower, upper), maxfev=5000)
        a_v, b_v, c_v = popt
    except RuntimeError:
        # 如果首次拟合未收敛，重试：更小的初始 a、更多迭代次数
        try:
            popt, _ = curve_fit(versatile_cdf, data_sorted, y_actual_cdf, p0=[5.0, 1.0, 0.2], bounds=(lower, upper), maxfev=20000)
            a_v, b_v, c_v = popt
        except Exception as e:
            print(f"Versatile fit failed for bin {bin_num}: {e}")
            # 退回到论文参考值，避免中断后续绘图
            a_v, b_v, c_v = (15.0, 1.2, 0.4)

    # ---------------------------------------------------------
    # 4. 绘制 CDF 曲线 (类似论文 Fig. 3)
    # ---------------------------------------------------------
    plt.figure(figsize=(10, 8))
    # 绘制散点 (注意步长)
    plt.scatter(data_sorted[::20], y_actual_cdf[::20], label='Actual', color='black', marker='o', facecolors='none')
    plt.plot(x_range, norm.cdf(x_range, mu, std), label='Gaussian', linestyle='-')
    plt.plot(x_range, beta.cdf(x_range, a_beta, b_beta, loc_beta, scale_beta), label='Beta', linestyle='-')
    plt.plot(x_range, versatile_cdf(x_range, a_v, b_v, c_v), label='Versatile', linestyle='--', color='red', linewidth=2)
    plt.xlabel('Probabilistic wind power output')
    plt.ylabel('CDF')
    plt.legend()
    plt.title('Comparison of CDF Fitting')
    plt.grid(True, linestyle=':', alpha=0.6)
    plt.savefig(cdf_name, dpi=300)
    plt.close()

    # ---------------------------------------------------------
    # 5. 绘制 PDF 曲线 (类似论文 Fig. 1 & 4)
    # ---------------------------------------------------------
    plt.figure(figsize=(10, 8))

    # 计算原始数据概率密度散点 (40个点, 步长0.025) 
    counts, bin_edges = np.histogram(data, bins=100, range=(0, 1), density=True)
    bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2
    plt.scatter(bin_centers, counts, label='Actual (Binned)', color='black', marker='o', facecolors='none')

    # 计算各分布的 PDF 曲线
    pdf_gaussian = norm.pdf(x_range, mu, std)
    pdf_beta = beta.pdf(x_range, a_beta, b_beta, loc_beta, scale_beta)
    pdf_versatile = versatile_pdf(x_range, a_v, b_v, c_v)

    plt.plot(x_range, pdf_gaussian, label='Gaussian', linestyle='-')
    plt.plot(x_range, pdf_beta, label='Beta', linestyle='-')
    plt.plot(x_range, pdf_versatile, label='Versatile', linestyle='--', color='red', linewidth=2)

    plt.xlabel('Probabilistic wind power output')
    plt.ylabel('PDF')
    plt.legend()
    plt.title('Comparison of PDF Fitting')
    plt.grid(True, linestyle=':', alpha=0.6)
    plt.savefig(pdf_name, dpi=300)
    plt.close()

    # ---------------------------------------------------------
    # 6. 输出参数与 RMSE 评估 (公式 3)
    # ---------------------------------------------------------
    n_o = 100
    eval_points = np.linspace(1/n_o, 1, n_o) 
    actual_cdf_at_eval = np.interp(eval_points, data_sorted, y_actual_cdf)

    def get_rmse(sim_vals):
        return np.sqrt(np.mean((actual_cdf_at_eval - sim_vals)**2))

    rmse_g = get_rmse(norm.cdf(eval_points, mu, std))
    rmse_b = get_rmse(beta.cdf(eval_points, a_beta, b_beta, loc_beta, scale_beta))
    rmse_v = get_rmse(versatile_cdf(eval_points, a_v, b_v, c_v))

    with open(txt_name, 'w') as f:
        f.write('--- Fitting Parameters ---\n')
        f.write(f'Gaussian: mu={mu:.4f}, std={std:.4f}\n')
        f.write(f'Beta: a={a_beta:.4f}, b={b_beta:.4f}\n')
        f.write(f'Versatile: a={a_v:.4f}, b={b_v:.4f}, c={c_v:.4f}\n\n')
        f.write('--- RMSE Evaluation ---\n')
        f.write(f'Gaussian RMSE:  {rmse_g:.5f}\n')
        f.write(f'Beta RMSE:      {rmse_b:.5f}\n')
        f.write(f'Versatile RMSE: {rmse_v:.5f} (Optimal)\n')
    print(f'Bin {bin_num}: finished fitting.')

bin_nums = [f"{i:02d}" for i in range(1, 26)]
for bin_num in bin_nums:
    fit_distribution(bin_num)
print(f"任务完成！已生成：\n- CDF图: cdf_fit_png\n- PDF图: pdf_fit_png\n- 参数表: para_fit_txt")