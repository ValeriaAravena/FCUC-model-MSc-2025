module Conjuntos
using JuMP, GLPK, Gurobi, Ipopt, NLopt
export generate_sets

function generate_sets(par, set, j)

    PicewiseSet = 1:j
    TimeSet = 1:24
    T = 24
    BlockSet = 1:4
    ThermalSet = [i for i in set.GeneratorSet if par.params[i].Type == "Gas" || par.params[i].Type == "Coal" || par.params[i].Type == "Diesel"]
    CoalSet = [i for i in set.GeneratorSet if par.params[i].Type == "Coal"]
    GasCombiendCycleSet = [i for i in set.GeneratorSet if par.params[i].Type == "Gas"]
    GasOpenCycleSet = [i for i in set.GeneratorSet if par.params[i].Type == "Gas"]
    HydroRSet = [i for i in set.GeneratorSet if par.params[i].Type == "HydroR"]
    SynchroSet = [i for i in set.GeneratorSet if par.params[i].Type == "Gas" || par.params[i].Type == "Coal" || par.params[i].Type == "Diesel" 
                 || par.params[i].Type == "HydroR" || par.params[i].Type == "SC"]
    RenewableSet = [i for i in set.GeneratorSet if par.params[i].Type == "Wind" || par.params[i].Type == "Solar"]
    HydroRORSet = [i for i in set.GeneratorSet if par.params[i].Type == "HydroROR"]
    StorageSet = [i for i in set.GeneratorSet if par.params[i].Type == "Storage"]
    SyncCondenserSet = [i for i in set.GeneratorSet if par.params[i].Type == "SC"]
    ConversorSet = [i for i in set.GeneratorSet if par.params[i].Type == "Wind" || par.params[i].Type == "Solar" || par.params[i].Type == "Storage"]
    GFLConvSet = [i for i in set.GeneratorSet if !ismissing(par.params[i].InversorType) && par.params[i].InversorType == "GFL"]
    GFMDroopConvSet = [i for i in set.GeneratorSet if !ismissing(par.params[i].InversorType) && par.params[i].InversorType == "GFM Droop"]
    GFMVSMConvSet = [i for i in set.GeneratorSet if !ismissing(par.params[i].InversorType) && par.params[i].InversorType == "GFM VSM"]


    return (GeneratorSet = set.GeneratorSet, TimeSet=TimeSet, T=T, BlockSet=BlockSet, ThermalSet=ThermalSet, CoalSet=CoalSet, GasCombiendCycleSet=GasCombiendCycleSet,
            GasOpenCycleSet = GasOpenCycleSet, HydroRSet=HydroRSet, SynchroSet=SynchroSet, RenewableSet=RenewableSet, HydroRORSet=HydroRORSet, StorageSet=StorageSet, 
            SyncCondenserSet=SyncCondenserSet, ConversorSet=ConversorSet, GFLConvSet=GFLConvSet, GFMDroopConvSet=GFMDroopConvSet, GFMVSMConvSet=GFMVSMConvSet,
            PicewiseSet=PicewiseSet)
end

end


module Variables
using JuMP, GLPK, Gurobi, Ipopt, NLopt
export set_variables

function set_variables(modelo, par, set)

    # Variables generales
    u     = @variable(modelo, u[set.GeneratorSet,set.TimeSet], Bin)
    p     = @variable(modelo, p[set.GeneratorSet,set.TimeSet] >= 0)
    y     = @variable(modelo, y[set.GeneratorSet,set.TimeSet], Bin)
    z     = @variable(modelo, z[set.GeneratorSet,set.TimeSet], Bin)

    # Variables de almacenamiento
    p_dis = @variable(modelo, p_dis[set.StorageSet, set.TimeSet] >= 0)
    p_cha = @variable(modelo, p_cha[set.StorageSet, set.TimeSet] >= 0)
    e     = @variable(modelo, e[set.StorageSet, set.TimeSet] >= 0)
    
    # Variables de reserva
    r_up     = @variable(modelo, r_up[set.GeneratorSet,set.TimeSet] >= 0)
    r_dis_up = @variable(modelo, r_dis_up[set.StorageSet,set.TimeSet] >= 0)
    r_cha_up = @variable(modelo, r_cha_up[set.StorageSet,set.TimeSet] >= 0)
    r_PF_up  = @variable(modelo, r_PF_up[set.TimeSet] >= 0)

    # Variables de inercia
    m = @variable(modelo, m[set.TimeSet] >= 0)

    # Variables de PWL 
    x = @variable(modelo, x[set.PicewiseSet, set.TimeSet], Bin) 

    # Retornamos un NamedTuple con todas las variables
    return (u=u, p=p, y=y, z=z, p_dis=p_dis, p_cha=p_cha, e=e, r_up=r_up, r_dis_up=r_dis_up, r_cha_up=r_cha_up, r_PF_up=r_PF_up, m=m, x=x)
end

end



module ObjFunction
using JuMP, GLPK, Gurobi, Ipopt, NLopt
export set_obj_function

function set_obj_function(modelo, par, set, var, hydrology)

    if hydrology == "Húmeda"
        WaterCost = 15.0
    elseif hydrology == "Seca"
        WaterCost = 100.0
    else
        error("Hydrology type not recognized. Use 'Húmeda' or 'Seca'.")
    end
    
    @objective(modelo, Min,
        sum(    par.params[i].FixedCost     * var.u[i,t] +
                par.params[i].StartUpCost   * var.y[i,t] +
                par.params[i].ShutDownCost  * var.z[i,t] +
                par.params[i].VariableCost  * var.p[i,t]
        for i in set.ThermalSet, t in set.TimeSet) +
                
        sum(    WaterCost  * var.p[h,t]
        for h in set.HydroRSet, t in set.TimeSet) +

        sum(    par.params[b].ChargeCost    * var.p_cha[b,t] +
                par.params[b].DischargeCost * var.p_dis[b,t]
        for b in set.StorageSet, t in set.TimeSet)) 

end

end