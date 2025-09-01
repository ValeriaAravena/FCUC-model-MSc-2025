module Output
using Printf, XLSX, DataFrames, JuMP, Dates, Plots
export write_results

function write_results(model, var, set, par, id_case, inertia_case, uc_case, hydrology)
   
    results_df = DataFrame(
        Time = Int[], 
        Generator = Int[], 
        Type = String[],
        u = Float64[], 
        p = Float64[], 
        r_up = Float64[],
        r_up_max = Float64[],
        R = Float64[],
        m = Float64[],
        Total_generation = Float64[], 
        Total_inertia = Float64[],
        e = Float64[],
        p_cha = Float64[],
        p_dis = Float64[],
        r_cha_up = Float64[],
        r_dis_up = Float64[],
        r_PF_up = Float64[]
    )
    
    status = termination_status(model)
    
    if status == MOI.INFEASIBLE
        println("El modelo es infactible.")
    else 
        println("Total cost: ", JuMP.objective_value(model))
        if hydrology == "Húmeda"
            WaterCost = 15.0
        elseif hydrology == "Seca"
            WaterCost = 100.0
        else
            error("Hydrology type not recognized. Use 'Húmeda' or 'Seca'.")
        end
        println("Sin costo del agua: ", JuMP.objective_value(model)-sum(JuMP.value(var.p[i, t])*WaterCost for i in set.HydroRSet for t in set.TimeSet))
        for t in set.TimeSet
            total_generation = sum(JuMP.value(var.p[i, t]) for i in 1:length(set.GeneratorSet))
            total_inertia = JuMP.value(var.m[t])
            # rocof_and = 0.07 * 60 / JuMP.value(m[t])
            # qss_and = 0.07 * 60 / (JuMP.value(D[t]) + JuMP.value(R[t]))
            for i in set.GeneratorSet
                if i in set.ThermalSet || i in set.HydroRSet 
                    push!(results_df, (
                        t, i, par.params[i].Type,
                        JuMP.value(var.u[i, t]), 
                        JuMP.value(var.p[i, t]), 
                        JuMP.value(var.r_up[i,t]),
                        if JuMP.value(var.r_up[i,t]) > 0
                            0.28 * par.params[i].Pmax
                        else
                            0
                        end,
                        if JuMP.value(var.r_up[i,t]) > 0
                            (JuMP.value(var.u[i, t])*par.params[i].Pmax/par.D[t])*(1/par.params[i].Droop)
                        else
                            0
                        end,
                        2 * par.params[i].H * par.params[i].Pmax * JuMP.value(var.u[i,t]),
                        total_generation, 
                        total_inertia,
                        0,
                        0,
                        0,
                        0,
                        0,
                        JuMP.value(var.r_PF_up[t])
                    ))
                elseif i in set.HydroRORSet 
                    push!(results_df, (
                        t, i, par.params[i].Type,
                        JuMP.value(var.u[i, t]), 
                        JuMP.value(var.p[i, t]), 
                        0,
                        0,
                        0,
                        2 * par.params[i].H * par.params[i].Pmax * JuMP.value(var.u[i,t]),
                        total_generation, 
                        total_inertia,
                        0,
                        0,
                        0,
                        0,
                        0,
                        JuMP.value(var.r_PF_up[t])
                    ))
                elseif i in set.StorageSet
                    push!(results_df, (
                        t, i, par.params[i].Type,
                        JuMP.value(var.u[i, t]), 
                        JuMP.value(var.p[i, t]), 
                        0,
                        0,
                        0,
                        2 * par.params[i].H * par.params[i].Pmax * inertia_case["gfm_vsm"], 
                        total_generation, 
                        total_inertia,
                        JuMP.value(var.e[i,t]),
                        JuMP.value(var.p_cha[i,t]),
                        JuMP.value(var.p_dis[i,t]),
                        JuMP.value(var.r_cha_up[i,t]),
                        JuMP.value(var.r_dis_up[i,t]),
                        JuMP.value(var.r_PF_up[t])
                    ))
                elseif i in set.SyncCondenserSet
                    push!(results_df, (
                        t, i, par.params[i].Type,
                        JuMP.value(var.u[i, t]), 
                        JuMP.value(var.p[i, t]), 
                        0,
                        0,
                        0,
                        2 * par.params[i].H * par.params[i].Pmax * inertia_case["cs"], 
                        total_generation, 
                        total_inertia,
                        0,
                        0,
                        0,
                        0,
                        0,
                        JuMP.value(var.r_PF_up[t])
                    ))
                else # Renewables
                    push!(results_df, (
                        t, i, par.params[i].Type,
                        1, 
                        JuMP.value(var.p[i, t]), 
                        JuMP.value(var.r_up[i,t]),
                        0,
                        0,
                        2 * par.params[i].H * par.params[i].Pmax, 
                        total_generation, 
                        total_inertia,
                        0,
                        0,
                        0,
                        0,
                        0,
                        JuMP.value(var.r_PF_up[t])
                    ))
                end
            end
        end
    end
    

    fecha_hora_actual = now()
    mes = month(fecha_hora_actual)
    dia = day(fecha_hora_actual)
    hor = hour(fecha_hora_actual)
    min = minute(fecha_hora_actual)
    date = string(dia, "-", mes, "_", hor, ".", min)

    data_path = joinpath(@__DIR__,"UnitCommitment", "data", "Outputs pasada constante", string(id_case, ".xlsx"))
    try
        XLSX.writetable(data_path, collect(eachcol(results_df)), names(results_df))
    catch e
        @warn "No se pudo guardar el archivo Excel: $e"
    end


end

end