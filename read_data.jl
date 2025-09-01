#####################################################
### Autor: Valeria Aravena P.                     ###
### Fecha: 11/03/2025                             ###
### Lectura y pre-procesamiento de datos          ###
#####################################################

module Parametros

using DataFrames, XLSX 
using Statistics

export read_data_xlsx

# 1. Definición de struct para almacenamiento de datos 
struct GeneratorData
    GeneratorName::Any
    Type::Any
    Pmin::Any
    Pmax::Any
    Ramp::Any
    StartUpShutDownRamp::Any
    MinimumUpTime::Any
    MinimumDownTime::Any
    StartUpCost::Any
    ShutDownCost::Any
    FixedCost::Any
    VariableCost::Any
    H::Any
    Damping::Any
    Droop::Any
    InversorType::Any
    # Parámetros de unidades de almacenamiento
    ChargeCost::Any
    DischargeCost::Any
    Efficiency_cha::Any
    Efficiency_dis::Any
    EnergyStorage_min::Any
    EnergyStorage_init::Any
    EnergyStorage_time::Any
end


# 2. Definición de función para lectura de datos 
function read_data_xlsx(data_path::String, year::Int, season::String, hydrology::String)

    # Lectura como xlsx
    xf = XLSX.readxlsx(data_path)

    # Lectura de hojas como "Tabular Data"
    df_demand_Pd = dropmissing(DataFrame(XLSX.gettable(xf["Demand"], first_row=2, stop_in_empty_row=false)));
    df_demand_Pd = filter(row -> row.Year == year && row.Season == season, df_demand_Pd);
    D = vec(Matrix(select(df_demand_Pd, Not([:Year, :Season]))))  
    
    df_generators = DataFrame(XLSX.gettable(xf[string("Generators", year)], stop_in_empty_row=true));
    
    df_renewables = dropmissing(DataFrame(XLSX.gettable(xf["Renewables"], first_row=2, stop_in_empty_row=false)));
    df_renewables = filter(row -> row.Season == season, df_renewables);
    rw_generation = Dict(row[1] => collect(row[3:end]) for row in eachrow(df_renewables))

    df_reservoir = dropmissing(DataFrame(XLSX.gettable(xf["Reservoir"], first_row=2, stop_in_empty_row=false)));
    df_reservoir = filter(row -> row.Season == season && row.Hydrology == hydrology, df_reservoir);
    e_reservoir = collect(df_reservoir[!, :pu])[1] # energía (p.u. de capacidad de embalses) disponible durante un día 

    df_ror = dropmissing(DataFrame(XLSX.gettable(xf["ROR"], first_row=2, stop_in_empty_row=false)));
    df_ror = filter(row -> row.Season == season && row.Hydrology == hydrology, df_ror);
    ror_generation = [df_ror[1, string(i)] for i in 1:24]
    
    # Definición de conjuntos
    GeneratorSet = 1:size(df_generators, 1)


    ### Pre-procesamientos de datos ###
    ## Parámetros generales
    GeneratorName = df_generators."Generator"
    Type = df_generators."Type" 
    Pmin = df_generators."Pmin [MW]"
    Pmax = df_generators."Pmax [MW]"
    ## Parámetros de unidades térmicas
    Ramp = df_generators."Ramp [MW/h]"
    StartUpShutDownRamp = df_generators."SRamp [MW]"
    MinimumUpTime = df_generators."MinUP"
    MinimumDownTime = df_generators."MinDW"
    ### Parámetros asociados a inercia e inversores
    H = df_generators."H [s]"
    Damping = df_generators."Damping"
    Droop = df_generators."Droop"
    InversorType = df_generators."Inversor Type"
    ## Costos
    StartUpCost = df_generators."StartUpCost [\$]"
    ShutDownCost = df_generators."ShutDownCost [\$]"
    FixedCost = df_generators."FixedCost [\$]"
    VariableCost = df_generators."VariableCost [\$/MWh]"
    ## Parámetros baterías
    ChargeCost = df_generators."ChargeCost [\$/MWh]"
    DischargeCost = df_generators."DischargeCost [\$/MWh]"
    Efficiency_cha = df_generators."Charge Efficiency [%]"
    Efficiency_dis = df_generators."Discharge Efficiency [%]"
    EnergyStorage_max = df_generators."Energy Storage Time [h]" .* df_generators."Pmax [MW]"
    EnergyStorage_min = df_generators."Minimum SoC [%]" .* EnergyStorage_max
    EnergyStorage_init = df_generators."Initial SoC [%]" .* EnergyStorage_max
    EnergyStorage_time = df_generators."Energy Storage Time [h]"

    # Vector de struct GeneratorData
    params = GeneratorData[]
    for i in GeneratorSet
        push!(params, GeneratorData(
            GeneratorName[i],    
            Type[i],
            Pmin[i],
            Pmax[i],
            Ramp[i],
            StartUpShutDownRamp[i],
            MinimumUpTime[i],
            MinimumDownTime[i],
            StartUpCost[i],
            ShutDownCost[i],
            FixedCost[i],
            VariableCost[i],
            H[i],
            Damping[i],
            Droop[i],
            InversorType[i],
            ChargeCost[i],
            DischargeCost[i],
            Efficiency_cha[i],
            Efficiency_dis[i],
            EnergyStorage_min[i],
            EnergyStorage_init[i],
            EnergyStorage_time[i]
        ))
    end
    # Retornar todas las variables de manera individual
    # return BusSet, GeneratorSet, LineSet, D, params, line_params, rw_generation
    return (GeneratorSet = GeneratorSet,), (D = D, params = params, rw_generation = rw_generation, e_reservoir = e_reservoir, ror_generation = ror_generation)
end

# data_path = joinpath(@__DIR__, "05_05_25_caso_SEN.xlsx")
# year = 2024
# season = "Verano"
# hydrology = "Normal"

# set, par = read_data_xlsx(data_path, year, season, hydrology)
# print(set.GeneratorSet)

end