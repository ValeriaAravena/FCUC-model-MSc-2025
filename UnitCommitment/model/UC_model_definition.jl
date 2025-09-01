using JuMP, GLPK, Gurobi, Ipopt, NLopt
export create_model, run_model

include(joinpath(@__DIR__, "read_data.jl"))
include(joinpath(@__DIR__, "sets_var.jl"))
include(joinpath(@__DIR__, "constraints.jl"))
using .Parametros
using .Conjuntos
using .Variables
using .ObjFunction
using .Restricciones
# using .Output

function create_model(data_path, f_0, Delta_P, f_lim, fss_lim, year, season, hydrology, inertia_case, uc_case, nadir_constraints, j, R_up) 

    model = Model(Gurobi.Optimizer)

    println("Reading Data")
    set, par = read_data_xlsx(data_path, year, season, hydrology)

    println("Generate Sets")
    set = generate_sets(par, set, j)

    println("Set Variables")
    var = set_variables(model, par, set)

    println("Set Objective Function")
    set_obj_function(model, par, set, var, hydrology)

    println("Set Constraints")
    set_constraints(model, par, set, var, f_0, Delta_P, f_lim, fss_lim, inertia_case, uc_case, year, nadir_constraints, R_up) 

    return [model, var, set, par]
end

function run_model(model, var, set, par, id_case, atr, inertia_case, uc_case)

    if haskey(atr, :TimeLimit)
        set_optimizer_attribute(model, "TimeLimit", atr.TimeLimit)
    end
    if haskey(atr, :MIPGap)
        set_optimizer_attribute(model, "MIPGap", atr.MIPGap)
    end
    if haskey(atr, :Cuts)
        set_optimizer_attribute(model, "Cuts", atr.Cuts)
    end
    if haskey(atr, :OutputFlag)
        set_optimizer_attribute(model, "OutputFlag", atr.OutputFlag)
    end

    JuMP.optimize!(model)


end