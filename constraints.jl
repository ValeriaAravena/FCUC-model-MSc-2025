module Restricciones
using JuMP, GLPK, Gurobi, Ipopt, NLopt
export set_constraints

function set_constraints(modelo, par, set, var, f_0, Delta_P, f_lim, fss_lim, inertia_case, uc_case, year, nadir_constraints, R_up) 

    ######################################## Restricciones Generales ###################################################

    # 1. Balance de potencia
    @constraint(modelo, PowerBalance[t in set.TimeSet],
    sum(var.p[k,t] for k in set.GeneratorSet) - sum(var.p_cha[b,t] for b in set.StorageSet) == par.D[t])

    ######################################## Restricciones de Unidades Térmicas ########################################

    # 1. Lógica de variables binarias de start, stop y commitment
    @constraint(modelo, TH_LogicConstraint1[i in set.ThermalSet], var.y[i,1] - var.z[i,1] == var.u[i,1] - var.u[i,24])
    @constraint(modelo, TH_LogicConstraint2[i in set.ThermalSet, t in 2:set.T], var.y[i,t] - var.z[i,t] == var.u[i,t] - var.u[i,t-1])

    # 2. Límites de generación
    @constraint(modelo, TH_PMinConstraint[i in set.ThermalSet, t in set.TimeSet], var.p[i,t] >= par.params[i].Pmin * var.u[i,t])
    @constraint(modelo, TH_PMaxConstraint[i in set.ThermalSet, t in set.TimeSet], var.p[i,t] + var.r_up[i,t] <= par.params[i].Pmax * var.u[i,t])

    # 3. Tiempos minimos de encendido y apagado
    @constraint(modelo, TH_MinUpConstraint[i in set.ThermalSet, t in 1:(set.T-par.params[i].MinimumUpTime)], (sum((var.u[i,l]) 
    for l in t:(t+par.params[i].MinimumUpTime-1)) >= par.params[i].MinimumUpTime*var.y[i,t]))
    @constraint(modelo, TH_MinDownConstraint[i in set.ThermalSet, t in 1:(set.T-par.params[i].MinimumDownTime)], (sum((1-var.u[i,l]) 
    for l in t:(t+par.params[i].MinimumDownTime-1)) >= par.params[i].MinimumDownTime*var.z[i,t]))
    # restricciones de borde...
    @constraint(modelo, TH_MinUp_border[i in set.ThermalSet, t in (set.T-par.params[i].MinimumUpTime):set.T], (sum((var.u[i,l]) 
    for l in t:set.T) >= (set.T-t+1)*var.y[i,t]))
    @constraint(modelo, TH_MinDown_border[i in set.ThermalSet, t in (set.T-par.params[i].MinimumUpTime):set.T], (sum((1-var.u[i,l]) 
    for l in t:set.T) >= (set.T-t+1)*var.z[i,t]))

    ######################################## Restricciones de Unidades Hidráulicas ######################################

    # 1. Lógica de variables binarias del commitment
    @constraint(modelo, H1[h in set.HydroRSet, t in 2:set.T], var.y[h,t] - var.z[h,t] == var.u[h,t] - var.u[h,t-1])

    # 2. Definición de la generación de las unidades
    @constraint(modelo, H2[h in set.HydroRSet, t in set.TimeSet], var.p[h,t] + var.r_up[h,t] <= par.params[h].Pmax * var.u[h,t])
    @constraint(modelo, H3[h in set.HydroRSet, t in set.TimeSet], var.p[h,t] >= par.params[h].Pmin * var.u[h,t])

    # 3. Límites de descarga de agua (o energía desembalsada)
    delta_t = 1
    @constraint(modelo, H4[h in set.HydroRSet, t in set.TimeSet], sum(var.p[h,t] * delta_t for t in set.TimeSet) <= par.e_reservoir * par.params[h].Pmax)
    
    # # 4. Condición inicial
    # @constraint(modelo, H5[h in set.HydroRSet, t in 1:1], var.u[h,t] == 1)


    ######################################## Restricciones de Condensadores Síncronos ######################################

    # 1. Potencia activa nula
    @constraint(modelo, SC1[i in set.SyncCondenserSet, t in set.TimeSet], var.p[i,t] == 0)

    # 2. Reserva nula
    @constraint(modelo, SC2[i in set.SyncCondenserSet, t in set.TimeSet], var.r_up[i,t] == 0)


    ######################################## Restricciones de Unidades Renovables #######################################

    # 1. El máximo nivel de generación vendrá dado por el valor mínimo entre la potencia máxima técnica de la unidad y el perfil de capacidad renovable
    @constraint(modelo, RW_PMax[r in set.RenewableSet, t in set.TimeSet], var.p[r,t] <= min(par.rw_generation[par.params[r].GeneratorName][t]*par.params[r].Pmax,par.params[r].Pmax))
    @constraint(modelo, RW_PMin[r in set.RenewableSet, t in set.TimeSet], var.p[r,t] >= 0)
    # 2. Hidros de pasada
    @constraint(modelo, ROR_PMax[h in set.HydroRORSet, t in set.TimeSet], var.p[h,t] <= par.params[h].Pmax * par.ror_generation[t] * var.u[h,t])
    @constraint(modelo, ROR_PMin[h in set.HydroRORSet, t in set.TimeSet], var.p[h,t] >= par.params[h].Pmin * var.u[h,t])
    @constraint(modelo, ROR_on[h in set.HydroRORSet, t in set.TimeSet], var.u[h,t] == 1)
    

    ######################################## Restricciones de Unidades de Almacenamiento #######################################
    
    # 1. Definición de generación en t y reserva upward
    @constraint(modelo, B1[b in set.StorageSet, t in set.TimeSet], var.p[b,t] == var.p_dis[b,t])

    # 2. Límites de carga y descarga
    @constraint(modelo, B2[b in set.StorageSet, t in set.TimeSet], var.p_dis[b,t] + var.r_dis_up[b,t] <= par.params[b].Pmax)
    @constraint(modelo, B3[b in set.StorageSet, t in set.TimeSet], var.p_cha[b,t] <= par.params[b].Pmax)

    # 3. Si la batería se está descargando, la reserva de carga es cero 
    @constraint(modelo, B4[b in set.StorageSet, t in set.TimeSet], var.r_cha_up[b,t] <= var.p_cha[b,t])

    # 4. Balance de energía 
    delta_t = 1
    @constraint(modelo, B5[b in set.StorageSet, t in 2:set.T], var.e[b,t] - var.e[b,t-1] == 
    ((var.p_cha[b,t] * par.params[b].Efficiency_cha) - (var.p_dis[b,t] / par.params[b].Efficiency_dis)) * delta_t)
    @constraint(modelo, B6[b in set.StorageSet, t in 1:1], var.e[b,t] - par.params[b].EnergyStorage_init == 
    ((var.p_cha[b,t]  *par.params[b].Efficiency_cha) - (var.p_dis[b,t] / par.params[b].Efficiency_dis)) * delta_t)

    # 5. Límite de energía almacenada 
    @constraint(modelo, B7[b in set.StorageSet, t in set.TimeSet], var.e[b,t] <= par.params[b].Pmax * par.params[b].EnergyStorage_time)
    @constraint(modelo, B8[b in set.StorageSet, t in set.TimeSet], var.e[b,t] >= 0)
    @constraint(modelo, B9[b in set.StorageSet, t in set.TimeSet], var.e[b,t] - (var.r_cha_up[b,t] * par.params[b].Efficiency_cha 
    + (var.r_dis_up[b,t] / par.params[b].Efficiency_dis)) * delta_t >= par.params[b].EnergyStorage_min)
    
    # 6. Condición final
    @constraint(modelo, B10[b in set.StorageSet], var.e[b,24] == par.params[b].EnergyStorage_init)


    ######################################## Restricciones de Reservas ##################################################

    if uc_case == 0 || uc_case == 1
        for t in keys(R_up)
            @constraint(modelo, (sum(var.r_up[i,t] for i in set.ThermalSet) + sum(var.r_up[h,t] for h in set.HydroRSet) 
            + inertia_case["gfm_vsm"] * sum(var.r_dis_up[b,t] + var.r_cha_up[b,t] for b in set.GFMVSMConvSet) >= Delta_P + R_up[t]))
        end
    elseif uc_case == 2
        @constraint(modelo, ResUp[t in set.TimeSet], (sum(var.r_up[i,t] for i in set.ThermalSet) + sum(var.r_up[h,t] for h in set.HydroRSet) 
        + inertia_case["gfm_vsm"] * sum(var.r_dis_up[b,t] + var.r_cha_up[b,t] for b in set.GFMVSMConvSet) + var.r_PF_up[t] >= Delta_P))
    end

    
    ############################################### Restricciones de Inercia/RoCoF ########################################

    # 1. Inercia total del sistema 
    @constraint(modelo, Inertia[t in set.TimeSet], var.m[t] == 
    sum(2 * par.params[i].H * par.params[i].Pmax * var.u[i,t] for i in set.ThermalSet) 
    + sum(2 * par.params[i].H * par.params[i].Pmax * inertia_case["cs"] for i in set.SyncCondenserSet) 
    + sum(2 * par.params[h].H * par.params[h].Pmax * var.u[h,t] for h in set.HydroRSet)
    + sum(2 * par.params[h].H * par.params[h].Pmax * var.u[h,t] for h in set.HydroRORSet)
    + sum(2 * par.params[b].H * par.params[b].Pmax * inertia_case["gfm_vsm"] for b in set.GFMVSMConvSet)
    )
   
    # 2. Restricción de RoCoF
    @constraint(modelo, RoCoF[t in set.TimeSet], (f_lim / f_0) * var.m[t] >= abs(Delta_P))


    ######################################## Restricciones Frecuencia-dinámicas QSS #######################################
    
    if uc_case == 2
        # 1. Restricciones asociadas al droop de las unidades
        @constraint(modelo, FD_Thermal[i in set.ThermalSet, t in set.TimeSet], var.r_up[i,t] <= (fss_lim/f_0) * (par.params[i].Pmax/par.params[i].Droop))
        @constraint(modelo, FD_HydroR[h in set.HydroRSet, t in set.TimeSet], var.r_up[h,t] <= (fss_lim/f_0) * (par.params[h].Pmax/par.params[h].Droop))
        @constraint(modelo, FD_GFMVSM[b in set.GFMVSMConvSet, t in set.TimeSet], var.r_dis_up[b,t] + var.r_cha_up[b,t] <= (fss_lim/f_0) * (par.params[b].Pmax/par.params[b].Droop))
        
        # 2. Restricciones asociadas al damping de la demanda
        K_PF = 0.9 # (Korunovic, 2018), (Informe del CEN Junio 2018)
        @constraint(modelo, PF[t in set.TimeSet], var.r_PF_up[t] <= (fss_lim / f_0) * K_PF * par.D[t])
    end


    ####################################### Restricción de Nadir ##########################################################

    if uc_case == 2
        
        if year == 2024
            for t in keys(nadir_constraints)
                a = nadir_constraints[t][1]
                b = nadir_constraints[t][2]
                c = nadir_constraints[t][3]
                d = nadir_constraints[t][4]
                @constraint(modelo, a * sum(par.params[i].Pmax * var.u[i,t] for i in set.CoalSet) +
                            b * sum(par.params[i].Pmax * var.u[i,t] for i in set.GasCombiendCycleSet) +
                            c * sum(par.params[h].Pmax * var.u[h,t] for h in set.HydroRSet) 
                            + d <= 0)
            end
        
        elseif year == 2035
            for t in keys(nadir_constraints)
                @constraint(modelo, 
                sum(par.params[h].Pmax * var.u[h,t] for h in set.HydroRSet) 
                >= nadir_constraints[t]["p"][(0,"Shs")])
            end

        end
    end

end
end