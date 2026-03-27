%% 潮流计算 判断线路是否过载
clear; clc;
result1 = runpf('case24_ieee_rts.m');
brch_over = overload(result1);
disp(brch_over);

%% 新型负荷计算 bus_9 load*6
clear; clc;
define_constants;
mpc = loadcase('case24_ieee_rts.m');
mpc.bus(9, PD) = mpc.bus(9, PD) * 6;
result2 = runpf(mpc);
brch_over = overload(result2);
disp(brch_over);

%% 新能源接入计算 bus_3 gen*6, load*-5
clear; clc;
mpc = loadcase('case24_ieee_rts.m');
mpc.bus(3, 3) = mpc.bus(3, 3) * (-5);
result3 = runpf(mpc);
brch_over = overload(result3);
disp(brch_over);

%% 线路故障计算 line_19,21 open circuit
clear; clc;
mpc = loadcase('case24_ieee_rts.m');
mpc.branch([19, 21],:) = [];
result4 = runpf(mpc);
brch_over = overload(result4);
disp(brch_over);