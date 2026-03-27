function bus_initial = get_oltc_voltage(t, Best_LTC_position, OLTC_final)
    % 根据时间t所在的区间返回对应的OLTC电压
    if t < Best_LTC_position(1)
        bus_initial = OLTC_final(1);
    elseif t < Best_LTC_position(2)
        bus_initial = OLTC_final(2);
    elseif t < Best_LTC_position(3)
        bus_initial = OLTC_final(3);
    elseif t < Best_LTC_position(4)
        bus_initial = OLTC_final(4);
    else
        bus_initial = OLTC_final(5);
    end
end