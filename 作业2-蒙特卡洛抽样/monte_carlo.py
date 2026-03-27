"""
monte_carlo.py

实现说明：
- 读取 `versatile_params.csv`（每行：序号,a,b,c），共25组
- 根据预测值到分箱的映射（25等宽分箱，宽度=0.04），查表获取 (a,b,c)
- 使用解析反函数对每个时刻做 N 次蒙特卡洛抽样：
    x = CDF^{-1}(u|a,b,c) = c - (1/a) * ln(u^{-1/b} - 1)
  其中 u ~ Uniform(0,1)
- 将 N 条场景保存为 CSV，计算每条场景的 2 小时区间最大-最小值（DeltaP）并保存统计信息
- 计算解析 90% 置信区间（u=0.05 和 u=0.95 的反函数）并验证抽样点落在区间内的比例

输出文件：
- monte_carlo_scenarios_N{N}.csv
- monte_carlo_summary_N{N}.txt
- deltaP_hist_N{N}.png (如果 matplotlib 可用)
"""

from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

ROOT = Path(__file__).parent
PARAM_CSV = ROOT / "versatile_params.csv"
PW_FORECAST_CSV = ROOT / "Pw_2024-10-01.csv"

# Past values for 2024-10-01 06:00-07:45
PAST_P = [0.85, 0.823, 0.711, 0.774, 0.854, 0.918, 0.914, 0.881]
# Forecast values for 2024-10-01 08:00-09:45 (8 points)
FORECAST_P = [0.885, 0.868, 0.776, 0.668, 0.611, 0.594, 0.558, 0.452]
TRUE_P = [0.901, 0.834, 0.709, 0.632, 0.609, 0.564, 0.487, 0.264]
TIME_LABELS = [
    "2024-10-01 08:00",
    "2024-10-01 08:15",
    "2024-10-01 08:30",
    "2024-10-01 08:45",
    "2024-10-01 09:00",
    "2024-10-01 09:15",
    "2024-10-01 09:30",
    "2024-10-01 09:45",
]
BIN_COUNT = 25
BIN_WIDTH = 1.0 / BIN_COUNT

def load_params(csv_path: Path):
    df = pd.read_csv(csv_path)
    # expect columns: 序号,a,b,c or index starting at 1
    # return dict: index (1-based) -> (a,b,c)
    mapping = {}
    for _, row in df.iterrows():
        idx = int(row[df.columns[0]])
        a = float(row[df.columns[1]])
        b = float(row[df.columns[2]])
        c = float(row[df.columns[3]])
        mapping[idx] = (a, b, c)
    return mapping

def value_to_bin_index(v: float) -> int:
    # bins: [0,0.04) -> 1, [0.04,0.08) ->2, ..., [0.96,1.0] ->25
    if v >= 1.0:
        return BIN_COUNT
    if v < 0.0:
        return 1
    idx = int(v / BIN_WIDTH) + 1
    idx = max(1, min(BIN_COUNT, idx))
    return idx

def inv_cdf(u: np.ndarray, a: float, b: float, c: float) -> np.ndarray:
    # Handle edge u values: clamp to (eps, 1-eps)
    eps = 1e-12
    u = np.clip(u, eps, 1 - eps)
    # formula: c - (1/a) * ln(u^{-1/b} - 1)
    # compute u^{-1/b} safely
    with np.errstate(divide='ignore', invalid='ignore'):
        power = np.power(u, -1.0 / b)
        inner = power - 1.0
        # ensure inner>0 to avoid log domain errors; 
        # inner should be >0 because power>1 for u in (0,1)
        inner = np.clip(inner, 1e-300, None)
        vals = c - (1.0 / a) * np.log(inner)
    return vals

def sample_scenarios(params_map, N=1000, seed=None):
    rng = np.random.default_rng(seed)
    M = len(FORECAST_P)
    scenarios = np.zeros((N, M), dtype=float)
    ci_bounds = []
    for j, p in enumerate(FORECAST_P):
        idx = value_to_bin_index(p)
        if idx not in params_map:
            raise KeyError(f"Bin index {idx} not found in params table")
        a, b, c = params_map[idx]
        u = rng.random(N)
        samples = inv_cdf(u, a, b, c).round(4)
        scenarios[:, j] = samples
        lo = inv_cdf(0.05, a, b, c).round(4)
        hi = inv_cdf(0.95, a, b, c).round(4)
        ci_bounds.append((float(lo), float(hi)))
    return scenarios, ci_bounds

def analyze_and_save(scenarios, ci_bounds, N, out_folder):
    # scenarios: (N, M)
    df = pd.DataFrame(scenarios, columns=TIME_LABELS)
    scen_csv = out_folder / f"scenarios_N{N}.csv"
    df.to_csv(scen_csv, index=False)

    # proportion of sampled points within analytical 90% CI
    total_points = scenarios.size
    inside = 0
    per_time_props = []
    for j in range(scenarios.shape[1]):
        lo, hi = ci_bounds[j]
        col = scenarios[:, j]
        inside_j = np.sum((col >= lo) & (col <= hi))
        per_time_props.append(float(inside_j / scenarios.shape[0]))
        inside += inside_j
    overall_prop = float(inside / total_points)

    return {
        'scenarios_csv': str(scen_csv),
        'per_time_props': per_time_props,
        'overall_prop': overall_prop,
    }

def convergence_test(params_map, Ns=(100, 1000, 5000, 10000), seed=42):
    results = []
    for N in Ns:
        scenarios, _ = sample_scenarios(params_map, N=N, seed=seed)
        mean_profile = scenarios.mean(axis=0)
        diff = mean_profile - np.array(FORECAST_P)
        results.append({'N': N, 'mean_profile': mean_profile, 'diff': diff})
    return results

def plot_scenarios(scenarios, ci_bounds, N, out_folder, true_series=None):
    # full timeline: 00:00 - 09:45 by 15 minutes
    full_idx = pd.date_range(start='2024-10-01 06:00:00', end='2024-10-01 09:45:00', freq='15min')
    scenario_len = scenarios.shape[1]
    scenario_start_pos = len(full_idx) - scenario_len
    x = np.arange(len(full_idx))

    plt.figure(figsize=(12, 6))

    # Part 1: plot all true values for 06:00-09:45 (if provided)
    if true_series is not None:
        true_vals = true_series.reindex(full_idx)
        plt.plot(x, true_vals, color='red', marker='o', linewidth=1.5, label='True (06:00-09:45)')

    # Part 2: plot all scenarios (only on 08:00-09:45 positions)
    for i in range(scenarios.shape[0]):
        y = np.full(len(full_idx), np.nan)
        y[scenario_start_pos:scenario_start_pos + scenario_len] = scenarios[i]
        plt.plot(x, y, color='C0', alpha=0.1, linewidth=0.6)

    # Part 3: 90% CI (08:00-09:45)
    ci_lo = np.full(len(full_idx), np.nan)
    ci_hi = np.full(len(full_idx), np.nan)
    ci_lo[scenario_start_pos:scenario_start_pos + scenario_len] = [b[0] for b in ci_bounds]
    ci_hi[scenario_start_pos:scenario_start_pos + scenario_len] = [b[1] for b in ci_bounds]
    plt.fill_between(x, ci_lo, ci_hi, color='orange', alpha=0.5, label='90% CI (08:00-09:45)')

    # Part 4: Forecast values (08:00-09:45)
    fore = np.full(len(full_idx), np.nan)
    fore[scenario_start_pos:scenario_start_pos + scenario_len] = FORECAST_P
    plt.plot(x, fore, color='blue', marker='s', linestyle='--', linewidth=1.5, label='Forecast (08:00-09:45)')

    # x ticks: show each hour
    xticks_pos = []
    xticks_labels = []
    for i, t in enumerate(full_idx):
        xticks_pos.append(i)
        xticks_labels.append(t.strftime('%H:%M'))
    plt.xticks(xticks_pos, xticks_labels, rotation=0)
    plt.xlim(0, len(full_idx) - 1)
    plt.xlabel('Time (06:00 - 09:45)')
    plt.ylabel('Value')
    plt.title(f'Monte Carlo Scenarios (N={N}) — True, Scenarios, 90% CI, Forecast')
    plt.legend()
    plt.tight_layout()
    plot_path = out_folder / f"scenarios_plot_N{N}.png"
    plt.savefig(plot_path)
    plt.close()
    return str(plot_path)

def main():
    N, seed = 1000, 12345
    params_map = load_params(PARAM_CSV)
    scenarios, ci_bounds = sample_scenarios(params_map, N, seed)
    output_folder = Path('output')
    out = analyze_and_save(scenarios, ci_bounds, N, output_folder)
    # Build true_series from PAST_P (06:00-07:45) and TRUE_P (08:00-09:45)
    full_idx = pd.date_range(start='2024-10-01 06:00:00', end='2024-10-01 09:45:00', freq='15min')
    true_vals = np.full(len(full_idx), np.nan)
    # PAST_P covers 06:00-07:45 -> first 8 positions
    true_vals[0:len(PAST_P)] = PAST_P
    # TRUE_P covers 08:00-09:45 -> last 8 positions
    start_pos = len(full_idx) - len(TRUE_P)
    true_vals[start_pos:start_pos + len(TRUE_P)] = TRUE_P
    true_series = pd.Series(index=full_idx, data=true_vals)
    plot_path = plot_scenarios(scenarios, ci_bounds, N, output_folder, true_series=true_series)

    print('Outputs:')
    print(' - scenarios CSV:', out['scenarios_csv'])
    print(' - scenarios plot PNG:', plot_path)
    print(' - Proportion of points within 90% CI per time point:', out['per_time_props'])
    print(' - Overall proportion of points within 90% CI:', out['overall_prop'])

    # Convergence quick check (small set)
    conv = convergence_test(params_map, Ns=(100, 1000), seed=seed)
    print('\nConvergence check (mean - forecast) for Ns=100,1000:')
    for r in conv:
        diffs = r['diff']
        with open (output_folder / f"summary_N{r['N']}.txt", 'w') as f:
            f.write(f"N={r['N']}:\n")
            f.write(f"Mean profile: {r['mean_profile']}\n")
            f.write(f"Difference from forecast: {diffs}\n")

if __name__ == '__main__':
    main()