function topology_calc = apply_load_profiles(topology_calc, topology_base, profiles, t)
    % 更新各类负荷的功率
    topology_calc.bus([3,4,6],3:4) = topology_base.bus([3,4,6],3:4) * profiles.residential(t);
    topology_calc.bus([7,9],3:4)   = topology_base.bus([7,9],3:4)   * profiles.institution(t);
    topology_calc.bus([10,12],3:4) = topology_base.bus([10,12],3:4) * profiles.commercial(t);
    topology_calc.bus([14,16],3:4) = topology_base.bus([14,16],3:4) * profiles.smalluser(t);
end