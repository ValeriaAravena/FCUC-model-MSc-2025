# include(joinpath(@__DIR__, "Simulations", "frequency_response.jl"))
# using .FrequencyDynamicsModels
using CSV, DataFrames, Printf, LinearAlgebra

export nadir_constraints_generator

function nadir_constraints_generator(var, set, par, year, Delta_P, inertia_case, j)

    nadir_constraints = Dict()
    frequency_metrics_dict = Dict{Int, Tuple{Number, Number, Number}}()
    nadir_values = Dict{Int, Number}()
    simulation_time = [0, 20]
    K_PF = 0.9

    m = Dict{Int, Any}()
    b = Dict{Int, Any}()
    p1 = Dict{Int, Any}()
    p2 = Dict{Int, Any}()
    p3 = Dict{Int, Any}()

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
   
        solutions = solve_frequency_response(Delta_P / Demand, Demand, K_PF, Ss, Scc, Shs, Shr, Ssc, Sgfld, Sgfmd, Sgfmv, simulation_time)
        frequency_metrics_dict = get_frequency_metrics(frequency_metrics_dict, t, solutions)
        nadir_values[t] = frequency_metrics_dict[t][1]

        if nadir_values[t] < -1.1

            if year == 2024

                println("Nadir no cumplido en hora $t: $(nadir_values[t])")
                Ss = range(0, 1000, step=100)
                Scc = range(0, 1000, step=100)
                Shs = range(0, 3400, step=100) # planos cortantes, granularidad de las unidades...

                ax_x = "Ss"
                ax_y = "Scc"
                ax_z = "Shs"

                corner_values = get_nadir_corners_UC2_2024(Delta_P, Demand, K_PF, Ss, Scc, Shs, Shr, Ssc, Sgfld, Sgfmd, Sgfmv, simulation_time)

                corner_points = [
                    [0, 0, corner_values[ax_z]],
                    [0, corner_values[ax_y], 0],
                    [corner_values[ax_x], 0, 0]
                ]

                # Calcula el plano: ax + by + cz + d = 0
                p1, p2, p3 = corner_points
                v1 = p2 .- p1
                v2 = p3 .- p1
                normal = cross(v1, v2)
                a, b, c = normal
                d = -dot(normal, p1)

                nadir_constraints[t] = (a, b, c, d)



            elseif year == 2035

                println("Nadir no cumplido en hora $t: $(nadir_values[t])")
                Shs_max = sum(par.params[hydro_resevoir].Pmax for hydro_resevoir in set.HydroRSet; init=0.0)
                nadir_constraints[t] = PWL_UC2_2035_v2(j, Delta_P, Demand, K_PF, Scc, Shs_max, Shr, Ssc, Sgfmv, simulation_time)

            end
        
        end
    
    end

    return nadir_constraints

end