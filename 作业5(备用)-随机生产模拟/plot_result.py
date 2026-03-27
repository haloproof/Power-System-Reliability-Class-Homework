import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

H = 8760
total_cap = 2800  
max_power = 0
cum_cap = np.array([0, 1000, 2000, 2800])
# 将 edlc_i0-eldc_i3 画在在一张图上
fig, ax = plt.subplots(figsize=(12, 8))
name = ['edlc_i0.csv', 'edlc_i1.csv', 'edlc_i2.csv', 'edlc_i3.csv']
colors = ['green', 'blue', 'orange', 'purple']
for i in range(len(name)):
    df = pd.read_csv(name[i])
    max_power = max(max_power, df['power'].max())
    ax.plot(df['power'], df['time'], linewidth=1, color=colors[i], label=f'EDLC i={i}')
    # 标出阴影部分E_gi 
    if i < 3:
        x_min = cum_cap[i]
        x_max = cum_cap[i+1]
        mask = (df['power'] >= x_min) & (df['power'] <= x_max)
        df_range = df[mask]
        if len(df_range) > 0:
            ax.fill_between(df_range['power'], 0, df_range['time'], 
                           alpha=0.3, color=colors[i], label=f'E_g{i}')


ax.set_xlabel('Power (MW)', fontsize=12)
ax.set_ylabel('Time (hours)', fontsize=12)
ax.set_title('Equivalent Duration Load Curves for 3 units', fontsize=14)

ax.axvline(x=total_cap, color='red', linestyle='--', label='Total Capacity')
ax.legend()
ax.set_xlim(0, max_power)
ax.set_ylim(0, H)

# 创建一个小图用于放大
ax_inset = fig.add_axes([0.65, 0.2, 0.2, 0.3]) # [left, bottom, width, height]

for i in range(len(name)):
    df = pd.read_csv(name[i])
    ax_inset.plot(df['power'], df['time'], linewidth=1, color=colors[i])
    max_power = max(max_power, df['power'].max())

ax_inset.axvline(x=total_cap, color='red', linestyle='--')

# 设置小图的坐标轴范围
zoom_range = 100
ax_inset.set_xlim(total_cap - zoom_range, total_cap + zoom_range)

# 动态设置y轴范围
df3 = pd.read_csv('edlc_i3.csv')
y_at_total_cap_minus_100 = np.interp(total_cap - zoom_range, df3['power'], df3['time'])
ax_inset.set_ylim(0, y_at_total_cap_minus_100 * 1.2)
ax_inset.set_title('Zoom near Total Capacity')
ax_inset.grid(True)

plt.savefig('edlc_all.png', dpi=300, bbox_inches='tight')