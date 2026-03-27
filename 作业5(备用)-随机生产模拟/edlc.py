import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime

# 读取CSV文件，获取第1列（时间）和第7列（负荷）
# 跳过最后1行，共读取8760行数据
df = pd.read_csv('hrl_load.csv')

# 提取前8760行的第1列（datetime_beginning_utc）和第7列（mw）
time = df.iloc[:8760, 0]
load = df.iloc[:8760, 6]  # 第7列的索引是6

# 将时间转换为datetime对象
time = pd.to_datetime(time)

# 创建小时数序列（0到8759）
hours = np.arange(len(load))

# ===== 图1：时间序列图 L(负荷) vs t(时间) =====
plt.figure(figsize=(10, 6))
plt.plot(hours, load, linewidth=1.5, color='blue')
plt.xlabel('Time (hours)', fontsize=12)
plt.ylabel('Load (MW)', fontsize=12)
plt.title('Load Time Series', fontsize=14)
plt.savefig('load_timeseries.png', dpi=150, bbox_inches='tight')

# ===== 图2：等效持续负荷曲线 T(时间)-x轴 vs P(功率)-y轴 =====
# 将负荷从大到小排序，得到等效持续负荷曲线
load_sorted = np.sort(load.values)[::-1]  # 降序排列
time_duration = np.arange(len(load_sorted))  # 时间轴（小时数）

plt.figure(figsize=(10, 6))
plt.plot(load_sorted, time_duration, linewidth=1.5, color='red')
plt.xlim(0, load.max())
plt.ylim(0, len(load))
plt.xlabel('Power (MW)', fontsize=12)
plt.ylabel('Time (hours)', fontsize=12)
plt.title('Equivalent Duration Load Curve', fontsize=14)
plt.savefig('edlc_curve.png', dpi=150, bbox_inches='tight')

# 保存edlc数据到CSV文件
edlc_df = pd.DataFrame({'power': load_sorted[::-1], 'time': time_duration[::-1]})
edlc_df.to_csv('edlc_data.csv', index=False)

print("数据处理完成！")
print(f"总数据点数: {len(load)}")
print(f"最大负荷: {load.max():.2f} MW")
print(f"最小负荷: {load.min():.2f} MW")
print(f"平均负荷: {load.mean():.2f} MW")
