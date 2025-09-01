include(joinpath(@__DIR__, "Simulations", "frequency_response.jl"))
include(joinpath(@__DIR__, "UnitCommitment", "model", "UC_model_definition.jl"))
include(joinpath(@__DIR__, "nadir_constraints_generator.jl"))
include(joinpath(@__DIR__, "R_up_constraints_generator.jl"))
include(joinpath(@__DIR__, "nadir_checker.jl"))
include(joinpath(@__DIR__, "nadir_qss_checker.jl"))
include(joinpath(@__DIR__, "plots_csv_generator.jl"))
include(joinpath(@__DIR__, "output_writing.jl"))
data_path = joinpath(@__DIR__, "UnitCommitment", "data", "Inputs", "SEN_case.xlsx")

using .FrequencyDynamicsModels, .Output
using CSV, DataFrames, Printf, XLSX

for year in [2024, 2035]
    for hydrology in ["Seca", "Húmeda"]
        for season in ["Primavera", "Invierno", "Otoño", "Verano"]
            for uc_case in [0] #0:2

                println("Running case: Year: $year, Season: $season, 
                Hydrology: $hydrology, UC Case: $uc_case")
                
                ### Inertia Case
                id_inertia_case = 0
                # 0: Pesimista 
                # 1: CS 
                # 2: GFM VSM 
                # 3: Optimista 
                
                ### UC Case 
                # 0: tradicional todas las horas
                # 1: tradicional horas críticas 
                # 2: propuesto

                ### Rest. de frecuencia
                freq_const = 1
                # 0: sin rest. de frecuencia
                # 1: con rest. de frecuencia

                inertia_case = Dict()
                if id_inertia_case == 0 
                    inertia_case["gfm_vsm"] = 0
                    inertia_case["cs"] = 0
                elseif id_inertia_case == 1 
                    inertia_case["gfm_vsm"] = 0
                    inertia_case["cs"] = 1
                elseif id_inertia_case == 2 
                    inertia_case["gfm_vsm"] = 1
                    inertia_case["cs"] = 0
                elseif id_inertia_case == 3 
                    inertia_case["gfm_vsm"] = 1
                    inertia_case["cs"] = 1
                else
                    error("Caso de inercia no reconocido")
                end

                ## Rest. de frecuencia
                if freq_const == 1
                    f_0 = 50        # frecuencia nominal [Hz]
                    Delta_P = 400   # perturbación [MW]
                    f_lim = 0.6     # límite de RoCoF [Hz/s]
                    fss_lim = 0.7   # límite de frecuencia de QSS [Hz]
                elseif freq_const == 0
                    f_0 = 50                
                    Delta_P = 0             
                    f_lim = 0           
                    fss_lim = 0             
                end

                ## Parámetros del solver
                TimeLimit   = 300        # Tiempo límite 
                MIPGap      = 0.0002     # Gap óptimo del 0.1%
                Cuts        = 0          # Activar cortes agresivos
                OutputFlag  = 1          # Mostrar salida del solver
                Heuristics  = 0
                atributos   = (TimeLimit=TimeLimit, MIPGap=MIPGap, Cuts=Cuts, OutputFlag=OutputFlag, Heuristics=Heuristics)

                ## Case ID Definition ##
                id_case_full = string(
                    "UC", uc_case, "_", year, "_", season, "_", hydrology,
                    if freq_const == 0
                        "_sin_freq"
                    elseif freq_const == 1
                        "_con_freq"
                    end,
                    if id_inertia_case == 0
                        "_pesimista"
                    elseif id_inertia_case == 1
                        "_CS"
                    elseif id_inertia_case == 2
                        "_GFM"
                    elseif id_inertia_case == 3
                        "_optimista"
                    end
                )

                nadir_constraints = Dict()
                R_up = Dict{Int, Number}()
                stop_check = false
                iter = 0
                j = 1
                model = nothing
                var = nothing
                set = nothing
                par = nothing

                    
                if uc_case == 0
                    
                    tiempo_total = @elapsed begin
                        
                        while !stop_check 
                            
                            println("Creando modelo...")
                            model, var, set, par = create_model(data_path, f_0, Delta_P, 
                            f_lim, fss_lim, year, season, hydrology, inertia_case, uc_case, 
                            nadir_constraints, j, R_up)
                            
                            println("Resolviendo modelo...")
                            run_model(model, var, set, par, id_case_full, atributos, 
                            inertia_case, uc_case)

                            id_case_full = string(
                                "UC", uc_case, "_", year, "_", season, "_", hydrology,
                                    "_sin_freq"
                            )
                            
                            break

                            
                            # println("Modelo resuelto, verificando restricciones de Nadir y QSS...")
                            # stop_check = nadir_qss_checker(var, set, par, Delta_P, 
                            # inertia_case)
                            
                            # println("Resultado verificación: ", stop_check)
                            # if stop_check
                            #     break
                            # end
                            # iter += 1
                            
                            # println("Iteración n° $iter. Aumentando reservas...")
                            # new_R_up_constraints = Dict(t => 1 for t in set.TimeSet)
                            # new_R_up_constraints = Dict(k => (v[1] * 100,) for (k, v) in 
                            # new_R_up_constraints)
                            # for (k, v) in new_R_up_constraints
                            #     if iter == 1
                            #         R_up[k] = v[1]
                            #     elseif iter > 1
                            #         R_up[k] += v[1]
                            #     end
                            # end
                            # println("R_up Constraints: ", 
                            # [R_up[k] for k in sort(collect(keys(R_up)))])
                        
                        end

                    end

                    println("Tiempo total de resolución del modelo: $(round(tiempo_total, digits=2)) segundos")
                    println("Generando archivos xlsx y csv...")
                    write_results(model, var, set, par, id_case_full, inertia_case, uc_case, hydrology)
                    plots_csv_generator(var, set, par, Delta_P, uc_case, id_case_full, inertia_case)
                    

                elseif uc_case == 1 
                    
                    tiempo_total = @elapsed begin
                        
                        while !stop_check         
                            
                            println("Creando modelo...")
                            model, var, set, par = create_model(data_path, f_0, Delta_P, f_lim, 
                            fss_lim, year, season, hydrology, inertia_case, uc_case, 
                            nadir_constraints, j, R_up)
                            
                            println("Resolviendo modelo...")
                            run_model(model, var, set, par, id_case_full, atributos, inertia_case, 
                            uc_case)
                            
                            println("Modelo resuelto, verificando restricciones de Nadir y QSS...")
                            stop_check = nadir_qss_checker(var, set, par, Delta_P, inertia_case)
                            
                            println("Resultado verificación: ", stop_check)
                            if stop_check
                                break
                            end
                            iter += 1
                            
                            println("Iteración n° $iter. Aumentando reservas...")
                            new_R_up_constraints = R_up_constraints_generator(var, set, par, Delta_P, 
                            uc_case, inertia_case)
                            new_R_up_constraints = Dict(k => (v[1] * 100,) for (k, v) in new_R_up_constraints)
                            for (k, v) in new_R_up_constraints
                                if iter == 1
                                    R_up[k] = v[1]
                                elseif iter > 1
                                    R_up[k] += v[1]
                                end
                            end
                            println("R_up Constraints: ", [R_up[k] for k in sort(collect(keys(R_up)))])
                        
                        end
                    
                    end
                    
                    println("Tiempo total de resolución del modelo (todas las iteraciones): 
                    $(round(tiempo_total, digits=2)) segundos")
                    println("Generando archivos xlsx y csv...")
                    write_results(model, var, set, par, id_case_full, inertia_case, uc_case, hydrology)
                    plots_csv_generator(var, set, par, Delta_P, uc_case, id_case_full, inertia_case)
                    

                elseif uc_case == 2 
                    
                    if year == 2024
                        
                        tiempo_total = @elapsed begin 
                            
                            while !stop_check 
                                
                                println("Creando modelo...")
                                model, var, set, par = create_model(data_path, f_0, Delta_P, f_lim, 
                                fss_lim, year, season, hydrology, inertia_case, uc_case, 
                                nadir_constraints, j, R_up)
                              
                                println("Resolviendo modelo...")
                                run_model(model, var, set, par, id_case_full, atributos, inertia_case, 
                                uc_case)
                                
                                println("Modelo resuelto, verificando restricciones de Nadir...")
                                stop_check = nadir_checker(var, set, par, year, Delta_P, inertia_case)    
                                
                                println("Resultado verificación: ", stop_check)
                                if stop_check
                                    break
                                end
                                iter += 1

                                println("Iteración n° $iter. Generando restricciones de Nadir...")
                                new_constraints = nadir_constraints_generator(var, set, par, year, 
                                Delta_P, inertia_case, j)
                                for (k, v) in new_constraints
                                    nadir_constraints[k] = v
                                end
                                println("Nadir Constraints: ", nadir_constraints)
                            
                            end
                        
                        end
                    
                    elseif year == 2035
                        
                        tiempo_total = @elapsed begin 
                            
                            while !stop_check 
                                
                                println("Creando modelo...")
                                model, var, set, par = create_model(data_path, f_0, Delta_P, f_lim, 
                                fss_lim, year, season, hydrology, inertia_case, uc_case, nadir_constraints, j, R_up)
                                
                                println("Resolviendo modelo...")
                                run_model(model, var, set, par, id_case_full, atributos, inertia_case, 
                                uc_case)
                                
                                println("Modelo resuelto, verificando restricciones de Nadir...")
                                stop_check = nadir_checker(var, set, par, year, Delta_P, inertia_case)
                                
                                println("Resultado verificación: ", stop_check)
                                if stop_check
                                    break
                                end
                                iter += 1

                                println("Iteración n° $iter. Generando restricciones de Nadir...")
                                new_constraints = nadir_constraints_generator(var, set, par, year, 
                                Delta_P, inertia_case, j)
                                for (k, v) in new_constraints
                                    nadir_constraints[k] = v
                                end
                                println("Nadir Constraints: ", nadir_constraints)
                           
                            end
                        
                        end
                   
                    end
                    
                    println("Tiempo total de resolución del modelo (todas las iteraciones): 
                    $(round(tiempo_total, digits=2)) segundos")
                    println("Generando archivos xlsx y csv...")
                    write_results(model, var, set, par, id_case_full, inertia_case, uc_case, hydrology)
                    plots_csv_generator(var, set, par, Delta_P, uc_case, id_case_full, inertia_case)

                end


                println("Guardando costo total, gap y tiempo de simulación...")
                results_file = joinpath(@__DIR__, "resultados_simulaciones.csv")
                if isfile(results_file)
                    df_results = CSV.read(results_file, DataFrame)
                else
                    df_results = DataFrame(
                        Caso = String[],
                        Objetivo = Float64[],
                        Gap = Float64[],
                        Tiempo = Float64[]
                    )
                end
                objetivo = objective_value(model)  
                gap = MOI.get(model, MOI.RelativeGap())  
                tiempo = round(tiempo_total, digits = 2)
                objetivo = round(objetivo, digits = 3)
                gap = round(gap, digits = 6)
                id_case_full_trunc = first(id_case_full, 31)
                println("Caso: $id_case_full, Objetivo: $objetivo, Gap: $gap, Tiempo: $tiempo segundos")
                push!(df_results, (id_case_full, objetivo, gap, tiempo))
                CSV.write(results_file, df_results)

            end
        
        end
    
    end

end