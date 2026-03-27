% 灵敏度切机/切负荷策略
clear; clc;

%% 两条线路故障
mpc = loadcase('case24_ieee_rts.m');
mpc.branch([19,21], :) = [];
mpopt = mpoption('out.all', 0, 'verbose', 0);
result_fault = runpf(mpc, mpopt);
brch_over = overload(result_fault); % 20号线 13-23过载
disp(brch_over(:, [1,2,6,7,8,14,15,16,17,18]));

%% 发电机调整信息和负荷调整信息
gen_p = result_fault.gen(:, 9) - result_fault.gen(:, 2); % 发电机可调余量
all_genbus = [1, 2, 7, 13, 14, 15, 16, 18, 21, 22, 23];

position_sum = zeros(max(all_genbus), 1);

for i = 1:numel(all_genbus)
    position = all_genbus(i);
    position_indices = find(result_fault.gen(:,1) == position);
    if ~isempty(position_indices)
        position_sum(position) = sum(gen_p(position_indices));
    end
end
bus_pg = [all_genbus', position_sum(all_genbus)];
disp(bus_pg);

% 方法二：直流灵敏度切机/切负荷
%% 直流潮流的灵敏度矩阵
fault_id = 20;
fault_from = 13;
fault_to = 23;
H = makePTDF(mpc);
disp(H(fault_id, :)); % 确定灵敏度最大23号节点减少出力，灵敏度最小7号节点增加出力

%% 直流流调整操作
mpc.gen([9, 10, 11], 2) = mpc.gen([9, 10, 11], 2) + 15; % bus7, 3台发电机+15*3 MW
mpc.gen([31, 32, 33], 2) = mpc.gen([31, 32, 33], 2) - 15; % bus23, 1台发电机-15*3 MW
result_dc = runpf(mpc);
brch_over_dc = overload(result_dc);
disp(brch_over_dc(:, [1,2,6,7,8,14,15,16,17,18]));