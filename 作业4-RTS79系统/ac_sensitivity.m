function result = ac_sensitivity(mpc, result_fault, fault_num)
    mpc2 = mpc;
     result = zeros(24, 1);
    for i = 1:24
        mpc2.bus(i, 3) = mpc2.bus(i, 3) + 10; % bus_i出力增加10 (delta_p=0.1)
        result_temp = runpf(mpc2); 
        result(i) = (result_temp.branch(fault_num, 14) - result_fault.branch(fault_num, 14))/ 100 / 0.1;
        mpc2 = mpc;
    end
end