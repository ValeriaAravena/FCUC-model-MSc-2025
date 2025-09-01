using CSV, DataFrames, Printf, LinearAlgebra

export nadir_checker

function nadir_checker(var, set, par, year, Delta_P, inertia_case)

    frequency_metrics_dict = Dict{Int, Tuple{Number, Number, Number}}()
    nadir_values = Dict{Int, Number}()
    simulation_time = [0, 20]

    for t in set.TimeSet
        Ss = sum(par.params[steam_generator].Pmax * value.(var.u[steam_generator,t]) for steam_generator in set.CoalSet; init=0.0)
        Scc = sum(par.params[gas_cc_generator].Pmax * value.(var.u[gas_cc_generator,t]) for gas_cc_generator in set.GasCombiendCycleSet; init=0.0)
        Shs = sum(par.params[hydro_storage].Pmax * value.(var.u[hydro_storage,t]) for hydro_storage in set.HydroRSet; init=0.0)
        Shr = sum(par.params[hydro_run_of_river].Pmax * value.(var.u[hydro_run_of_river,t]) for hydro_run_of_river in set.HydroRORSet; init=0.0)
        Sgfld = 0
        Sgfmd = sum(par.params[grid_forming_droop_converter].Pmax for grid_forming_droop_converter in set.GFMDroopConvSet if value.(var.p[grid_forming_droop_converter, t]) > 0.0; init=0.0)
        Ssc = inertia_case["cs"] * sum(par.params[synchronous_condenser].Pmax for synchronous_condenser in set.SyncCondenserSet; init=0.0)
        Sgfmv = inertia_case["gfm_vsm"] * sum(par.params[grid_forming_vsm_converter].Pmax for grid_forming_vsm_converter in set.GFMVSMConvSet; init=0.0)
        Demand = par.D[t]
        K_PF = 0.9

        solutions = solve_frequency_response(Delta_P / Demand, Demand, K_PF, Ss, Scc, Shs, Shr, Ssc, Sgfld, Sgfmd, Sgfmv, simulation_time)
        frequency_metrics_dict = get_frequency_metrics(frequency_metrics_dict, t, solutions)
        nadir_values[t] = frequency_metrics_dict[t][1]

        if nadir_values[t] < -1.1
            println("Nadir no cumplido en hora $t: $(nadir_values[t])")
            return false
        else
            println("Nadir cumplido en hora $t: $(nadir_values[t])")
        end
    
    end
    
    return true

end