import pandas as pd

def binning(data, bin_size = 25, bin_index = 4):
    # divide [0, 1] into 25 equal bins [0, 0.04, 0.08, ..., 1.0]
    # [0.16, 0.20) -> bin_index = 4
    bins = [i/bin_size for i in range(bin_size + 1)]
    data['bin_tag'] = pd.cut(data['forecast'], bins=bins, include_lowest=True, labels=bins[:-1])
    target_label = bins[int(bin_index)-1]
    selected_data = data[data['bin_tag'] == target_label]
    lower_bound = target_label
    upper_bound = target_label + 1/bin_size
    print(f'Bin {bin_index}: Selected {len(selected_data)} rows in range [{lower_bound:.2f}, {upper_bound:.2f}]')   
    return selected_data[['value', 'forecast']]

bin_nums = [f"{i:02d}" for i in range(1, 26)]
data = pd.read_csv('Pw_forecast.csv')
# 因为beta分布的特殊性(0,1) 进行预处理
# 0 -> 0.001, 1 -> 0.999
data['value'] = data['value'].clip(0.001, 0.999)
data['forecast'] = data['forecast'].clip(0.001, 0.999)
for bin_index in range(1, 26):
    binned_data = binning(data.copy(), bin_size=25, bin_index=bin_index)
    binned_data.to_csv(f'Pw_bin_csv/Pw_bin_{bin_nums[bin_index-1]}.csv', index=False)