import numpy as np
import pandas as pd

# 在edlc_data.csv插值，得到整数功率x=0,1,2,...,max_power对应的时间
dx = 1
edlc_df = pd.read_csv('edlc_data.csv')
max_power = int(edlc_df['power'].max())
power_interp = np.arange(0, max_power + 1)
time_interp = np.interp(power_interp, edlc_df['power'], edlc_df['time'])
time_interp = np.round(time_interp).astype(int)

# 保存插值后的数据到CSV文件
interp_df = pd.DataFrame({'power': power_interp, 'time': time_interp})
interp_df.to_csv('edlc_i0.csv', index=False)

# 安排3台机组，作业3.md要求
n = 3
Cap = [1000, 1000, 800]
p = [0.01, 0.02, 0.03]  # 强迫停运率
q = [0.99, 0.98, 0.97]  # 正常运行率
power_i0 = interp_df['power'].values
edlc_prev = interp_df['time'].values
H = 8760

E_g = np.zeros(3)  # 每台机组的发电量
cum_cap = np.array([0, 1000, 2000, 2800])

# 迭代计算每台机组的等效持续负荷曲线
for i in range(n):
    C_i = Cap[i]
    p_i = p[i]  # 强迫停运率
    q_i = q[i]  # 正常运行率
    # f^(i-1)(x-C_i)
    shifted_power = np.arange(0, max_power + C_i + 1)
    shifted_time = np.concatenate((np.ones(int(C_i)) * H, edlc_prev))  # 前C_i部分均为H, 后续部分为edlc_prev
    edlc_prev = np.concatenate((edlc_prev, np.zeros(int(C_i))))  
    # f^(i)(x) = q_i * f^(i-1)(x) + p_i * f^(i-1)(x-C_i)
    # 注意：脚本中的 p, q 与公式中的 p, q 定义相反
    edlc_i_time = q_i * edlc_prev + p_i * shifted_time
    E_g[i] = np.sum(edlc_prev[int(cum_cap[i]):int(cum_cap[i+1])]) * dx  #

    edlc_i_df = pd.DataFrame({'power': shifted_power, 'time': edlc_i_time})
    edlc_i_df.to_csv(f'edlc_i{i+1}.csv', index=False)    
    # 更新 edlc_prev
    edlc_prev = edlc_i_time
    max_power += C_i  

# 保存计算结果
total_cap = sum(Cap)
edlc = pd.read_csv('edlc_i3.csv')['time'].values    
power = pd.read_csv('edlc_i3.csv')['power'].values
LOLP = edlc[int(total_cap)] / H 
EENS = np.sum(edlc[int(total_cap)+1:]) * dx
with open('results.txt', 'w') as f:
    f.write(f'Total Capacity: {total_cap} MW\n')
    f.write(f'LOLP: {LOLP:.6f}\n')
    f.write(f'EENS: {EENS:.2f} MWh\n')
    for i in range(n):
        f.write(f'E_g{i+1}: {E_g[i]:.2f} MWh\n')