import pandas as pd

def forecastor(path):
    # 1. 原始数据, 分辨率1 min
    data = pd.read_csv(path)
    data['timestamp'] = pd.to_datetime(data['timestamp'])
    forecast = data.copy()

    # 2. 计算 15 分钟滚动平均值
    # rolling(15).mean() 在 12:14 时刻的值包含了 [12:00, 12:01, ..., 12:14] 这 15 个点
    # 使用 .shift(1) 将 12:14 计算出的均值移动到 12:15 这一行作为其预测值 (forecast)
    forecast['forecast'] = forecast['value'].rolling(window=15).mean().shift(1)

    # 3. 归一化处理
    max_val = forecast['value'].max()
    forecast['forecast_pu'] = (forecast['forecast'] / max_val).round(3)
    forecast['value_pu'] = (forecast['value'] / max_val).round(3)

    start_time = pd.to_datetime('2024-10-01 00:00:00')
    end_time = pd.to_datetime('2025-11-30 23:59:00')
    mask = (forecast['timestamp'] >= start_time) & (forecast['timestamp'] <= end_time)
    df_filtered = forecast.loc[mask].copy()
    forcast_res = df_filtered[df_filtered['timestamp'].dt.minute % 15 == 0].copy()
    forcast_res = forcast_res.dropna(subset=['value_pu', 'forecast_pu'])

    print(f'已生成修正后的预测数据：共 {len(forcast_res)} 行。')
    return forcast_res[['timestamp', 'value_pu', 'forecast_pu']].rename(
        columns={'value_pu': 'value', 'forecast_pu': 'forecast'}
    )

forcast_df = forecastor(path='Pw_true.csv')
forcast_df.to_csv('Pw_forecast.csv', index=False)