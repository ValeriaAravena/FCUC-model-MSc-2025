using CSV, DataFrames, Printf, LinearAlgebra

export R_up_constraints_generator

function R_up_constraints_generator(var, set, par, Delta_P, uc_case, inertia_case)

    R_up_constraints = Dict{Int, Number}()
    frequency_metrics_dict = Dict{Int, Tuple{Number, Number, Number}}()
    nadir_values = Dict{Int, Number}()
    simulation_time = [0, 20]
    K_PF = 0.9

    for t in set.TimeSet
        
        Ss = sum(par.params[steam_generator].Pmax * value.(var.u[steam_generator,t]) for steam_generator in set.CoalSet; init=0.0)
        Scc = sum(par.params[gas_cc_generator].Pmax * value.(var.u[gas_cc_generator,t]) for gas_cc_generator in set.GasCombiendCycleSet; init=0.0)
        Shs = sum(par.params[hydro_storage].Pmax * value.(var.u[hydro_storage,t]) for hydro_storage in set.HydroRSet; init=0.0)
        Shr = sum(par.params[hydro_run_of_river].Pmax * value.(var.u[hydro_run_of_river,t]) for hydro_run_of_river in set.HydroRORSet; init=0.0)
        Sgfld = 0
        Sgfmd = 0 
        Ssc = inertia_case["cs"] * sum(par.params[synchronous_condenser].Pmax for synchronous_condenser in set.SyncCondenserSet; init=0.0)
        Sgfmv = inertia_case["gfm_vsm"] * sum(par.params[grid_forming_vsm_converter].Pmax for grid_forming_vsm_converter in set.GFMVSMConvSet; init=0.0)
        Demand = par.D[t]
   
        solutions = solve_frequency_response(Delta_P / Demand, Demand, K_PF, Ss, Scc, Shs, Shr, Ssc, Sgfld, Sgfmd, Sgfmv, simulation_time)
        frequency_metrics_dict = get_frequency_metrics(frequency_metrics_dict, t, solutions)
        nadir_values[t] = frequency_metrics_dict[t][1]

        # Estimación de QSS

        if inertia_case["gfm_vsm"] == 1
            Rg = sum(
                (1/par.params[i].Droop) * (value.(var.u[i, t]) * par.params[i].Pmax / par.D[t])
                for i in set.GeneratorSet
                if (i in set.ThermalSet || i in set.HydroRSet) && value(var.r_up[i, t]) > 0
                ; init=0.0
            ) +
            sum(
                (1/par.params[i].Droop) * (value.(var.u[i, t]) * par.params[i].Pmax / par.D[t])
                for i in set.GeneratorSet
                if (i in set.GFMVSMConvSet) && ((value(var.r_cha_up[i, t]) > 0) || (value(var.r_dis_up[i, t]) > 0))
                ; init=0.0
            )
        else
            Rg = sum(
                (1/par.params[i].Droop) * (value.(var.u[i, t]) * par.params[i].Pmax / par.D[t])
                for i in set.GeneratorSet
                if (i in set.ThermalSet || i in set.HydroRSet) && value(var.r_up[i, t]) > 0
                ; init=0.0
            )
        end
        f_qss = 50 * (400/par.D[t]) / (0.9 + Rg)

        
        if nadir_values[t] < -1.1 || f_qss > 0.7          
            if nadir_values[t] < -1.1
                println("Nadir no cumplido en hora $t: $(nadir_values[t])")
            end
            if f_qss > 0.7
                println("QSS no cumplido en hora $t: $f_qss")
            end        
            R_up_constraints[t] = 1
        else
            R_up_constraints[t] = 0
        end
    end
    
    return R_up_constraints

end