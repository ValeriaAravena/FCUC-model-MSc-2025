include(joinpath(@__DIR__, "Simulations", "frequency_response.jl"))
using .FrequencyDynamicsModels
using CSV, DataFrames, Printf
df_plots_dir = joinpath(@__DIR__, "Simulations", "Plots pasada constante")

function plots_csv_generator(var, set, par, Delta_P, uc_case, id_case_full, inertia_case)

    frequency_metrics_dict = Dict{Int, Tuple{Number, Number, Number}}()
    f_qss = Dict{Int, Number}()
    K_PF = 0.9

    hourly_summary = DataFrame(
        hour = Int[],
        Demand = Float64[],
        K_PF = Float64[],
        Ss = Float64[],
        Scc = Float64[],
        Shs = Float64[],
        Shr = Float64[],
        Ssc = Float64[],
        Sgfl_droop = Float64[],
        Sgfm_droop = Float64[],
        Sgfm_vsm = Float64[]
    )

    for t in set.TimeSet
        
        Ss = sum(par.params[steam_generator].Pmax * value.(var.u[steam_generator,t]) for steam_generator in set.CoalSet; init=0.0)
        Scc = sum(par.params[gas_cc_generator].Pmax * value.(var.u[gas_cc_generator,t]) for gas_cc_generator in set.GasCombiendCycleSet; init=0.0)
        Shs = sum(par.params[hydro_storage].Pmax * value.(var.u[hydro_storage,t]) for hydro_storage in set.HydroRSet; init=0.0)
        Shr = sum(par.params[hydro_run_of_river].Pmax * value.(var.u[hydro_run_of_river,t]) for hydro_run_of_river in set.HydroRORSet; init=0.0)
        Sgfl_droop = 0
        Sgfm_droop = sum(par.params[grid_forming_droop_converter].Pmax for grid_forming_droop_converter in set.GFMDroopConvSet if value.(var.p[grid_forming_droop_converter, t]) > 0.0; init=0.0)
        Ssc = inertia_case["cs"] * sum(par.params[synchronous_condenser].Pmax for synchronous_condenser in set.SyncCondenserSet; init=0.0)
        Sgfm_vsm = inertia_case["gfm_vsm"] * sum(par.params[grid_forming_vsm_converter].Pmax for grid_forming_vsm_converter in set.GFMVSMConvSet; init=0.0)
        Demand = par.D[t]

        push!(hourly_summary, (
            hour = t,
            Demand = Demand,
            K_PF = K_PF,
            Ss = Ss,
            Scc = Scc,
            Shs = Shs,
            Shr = Shr,
            Ssc = Ssc,
            Sgfl_droop = Sgfl_droop,
            Sgfm_droop = Sgfm_droop,
            Sgfm_vsm = Sgfm_vsm
        ))

        ### Estimación de QSS

        if inertia_case["gfm_vsm"] == 1
            
            Rg_convencional = sum((1/par.params[i].Droop) * (value.(var.u[i, t]) * par.params[i].Pmax / par.D[t])
                for i in set.GeneratorSet
                if (i in set.ThermalSet || i in set.HydroRSet) && (value(var.r_up[i, t]) > 0); init=0.0) 
        
            Rg_gfm = sum((1/par.params[i].Droop) * par.params[i].Pmax / par.D[t]
                for i in set.GeneratorSet
                if (i in set.GFMVSMConvSet) && ((value(var.r_cha_up[i, t]) + value(var.r_dis_up[i, t]) > 0))
                ; init=0.0)
           
            Rg = Rg_convencional + Rg_gfm

        else
            
            Rg = sum(
                (1/par.params[i].Droop) * (value.(var.u[i, t]) * par.params[i].Pmax / par.D[t])
                for i in set.GeneratorSet
                if (i in set.ThermalSet || i in set.HydroRSet) && value(var.r_up[i, t]) > 0
                ; init=0.0
            )

        end
        
        f_qss[t] = 50 * (400/par.D[t]) / (0.9 + Rg)
        solutions = solve_frequency_response(Delta_P / Demand, Demand, K_PF, Ss, Scc, Shs, Shr, Ssc, Sgfl_droop, Sgfm_droop, Sgfm_vsm, [0, 60])
        frequency_metrics_dict = get_frequency_metrics(frequency_metrics_dict, t, solutions)

    end

    CSV.write(joinpath(df_plots_dir, string("hourly_summary_", id_case_full, ".csv")), hourly_summary)

    df_metrics = DataFrame(
        hour = sort(collect(keys(frequency_metrics_dict))),
        nadir = [50 + frequency_metrics_dict[t][1] for t in sort(collect(keys(frequency_metrics_dict)))],
        rocof = [-frequency_metrics_dict[t][2] for t in sort(collect(keys(frequency_metrics_dict)))],
        qss = [50 - f_qss[t] for t in sort(collect(keys(f_qss)))]
    )
    csv_name = string("frequency_metrics_", id_case_full, ".csv")
    CSV.write(joinpath(df_plots_dir, csv_name), df_metrics)
    
end


### Generación de csv para construir gráficos de simulaciones

# Demand = 14850
# K_PF = 0.9 
# Delta_P = 400
# Ss = 0
# Scc = 0
# Shs = range(0, 3400, step = 100)
# Shr = 4283
# Ssc = range(0, 0, step=1) #range(0, 3400, step = 50)
# Sgfmv = range(0, 500, step = 10)
# simulation_time = [0, 10]
# nadir_results = get_nadir_results_3D_UC2_2035(Delta_P, Demand, K_PF,
#     Ss, Scc, Shs, Shr, Ssc, 0, 0, Sgfmv, simulation_time)
# Shs_values = [k[1] for k in keys(nadir_results)]
# Ssc_values = [k[2] for k in keys(nadir_results)]
# Sgfmv_values = [k[3] for k in keys(nadir_results)]
# nadir_values = [v for v in values(nadir_results)]
# df_nadir = DataFrame(
#     Shs = Shs_values,
#     Ssc = Ssc_values,
#     Sgfmv = Sgfmv_values,
#     nadir = nadir_values
# )
# csv_name = string("nadir_results_2035_D_14850_Shs_Sgfmv.csv")
# CSV.write(joinpath(df_plots_dir, csv_name), df_nadir)