module FrequencyPlots

using PlotlyJS, Colors, ColorSchemes, PyCall

export generate_frequency_response_plot, generate_nadir_surfaces, generate_nadir_surfaces_5D,
    generate_filtered_nadir_scatter, generate_filtered_percentage_nadir_scatter, generate_frequency_metrics_plots,
    plot_nadir_2d



function generate_frequency_response_plot(solutions)
    
    system = solutions.prob.f.sys
    Δf = 50 * getproperty(system, :Δf) + 50
    trace = scatter(x=solutions.t, y=solutions[Δf, :], mode="lines", name="Δf(t)")
    layout = Layout(
        title="Respuesta del sistema",
        xaxis_title="Tiempo [s]",
        yaxis_title="Frecuencia [Hz]"
    )
    fig = PlotlyJS.plot(trace, layout)
    display(fig)
    savefig(fig, "grafico_respuesta_frecuencia.png")

end 



function generate_nadir_surfaces(nadir_results::Dict{Tuple{Number, Number, Number}, Number})

    # Inicializar listas para las superficies y las visibilidades
    surfaces = Vector{GenericTrace{Dict{Symbol, Any}}}()
    legend_traces = Vector{GenericTrace{Dict{Symbol, Any}}}()
    z_values = sort(unique([k[3] for k in keys(nadir_results)]))

    # Gradiente de colores 
    cs = ColorSchemes.Greens_9
    solid_colors = ["#" * hex(get(cs, i/length(z_values))) for i in 1:length(z_values)]    

    # Crear superficies y leyenda
    for (i, z_val) in enumerate(z_values)
        # Filtrar los datos con el mismo tercer valor en la tupla
        selected_data = filter(k -> k[3] == z_val, keys(nadir_results))

        # Obtener x, y ordenados
        x = sort(unique([k[1] for k in selected_data]))
        y = sort(unique([k[2] for k in selected_data]))

        # Crear un diccionario para mapear (x, y) a sus valores en a[k]
        values_dict = Dict((k[1], k[2]) => nadir_results[k] for k in selected_data)

        # Construir la matriz Z en el orden correcto
        Z_matrix = [values_dict[(xi, yi)] + 50 for yi in y, xi in x]

        # Crear la superficie
        push!(surfaces, surface(
            x=x, y=y, z=transpose(Z_matrix), name="Sc = $z_val", visible=true, 
            colorscale=[[0, solid_colors[i]], [1, solid_colors[i]]], 
            opacity = 0.8, showscale=false, showlegend=false
        ))

        # Agregar traza "invisible" para la leyenda
        push!(legend_traces, PlotlyJS.scatter3d(
            x=[NaN], y=[NaN], z=[NaN], 
            mode="markers", 
            marker=attr(size=10, color=solid_colors[i]), 
            name="Sc = $z_val", 
            showlegend=true
        ))
    end

    # Crear botones para controlar visibilidad
    buttons = [
        attr(label="✅ Mostrar Todas", method="update", args=[Dict("visible" => fill(true, length(surfaces)))])
    ]

    for (i, z_val) in enumerate(z_values)
        estado = fill(false, length(surfaces))
        estado[i] = true
        push!(buttons, attr(label="Sc = $z_val", method="update", args=[Dict("visible" => estado)]))
    end

    # Layout con leyenda y cámara ajustada
    layout = Layout(
        title = "Gráficos Nadir",
        scene = attr(
            xaxis = attr(title = "Sh [MW]"),
            yaxis = attr(title = "St [MW]"),
            zaxis = attr(title = "F nadir [Hz]"),
            camera = attr(eye = attr(x=-1.5, y=-1.5, z=1.1))
        ),
        legend=attr(x=1, y=0.9),
        updatemenus=[attr(buttons=buttons, direction="down", showactive=true)]
    )

    # Crear figura combinada
    fig = plot(vcat(surfaces, legend_traces), layout)

    display(fig)

    PlotlyJS.savefig(fig, "grafico_nadir.png")

end



function generate_nadir_surfaces_5D(results::Dict{NTuple{5, Number}, Number}, Pl::Number)

    surfaces = Vector{GenericTrace{Dict{Symbol, Any}}}()

    sgfl_values = sort(unique(k[3] for k in keys(results)))
    sgfm_d_values = sort(unique(k[4] for k in keys(results)))
    sgfm_v_values = sort(unique(k[5] for k in keys(results)))

    combinations = [(sgfl, sgmf_d, sgfm_v) for sgfl in sgfl_values, sgmf_d in sgfm_d_values, sgfm_v in sgfm_v_values]

    cs = ColorSchemes.Paired_12
    solid_colors = ["#" * hex(get(cs, i/length(combinations))) for i in 1:length(combinations)]

    for (i, (sgfl, sgfm_d, sgfm_v)) in enumerate(combinations)
        selected_keys = filter(k -> k[3] == sgfl && k[4] == sgfm_d && k[5] == sgfm_v, keys(results))
        x = sort(unique(k[1] for k in selected_keys))
        y = sort(unique(k[2] for k in selected_keys))

        values_dict = Dict((k[1], k[2]) => results[k] for k in selected_keys)

        Z_matrix = [values_dict[(xi, yi)] + 50 for yi in y, xi in x]

        visible_init = (sgfl == 0 && sgfm_d == 0 && sgfm_v == 0)

        push!(surfaces, surface(
        x=x, y=y, z=transpose(Z_matrix),
        name="Sgfl=$sgfl, Sgfm-Droop=$sgfm_d, Sgfm-VSM=$sgfm_v",
        visible=visible_init,
        colorscale=[[0, solid_colors[i]], [1, solid_colors[i]]],
        opacity=0.8,
        showscale=false,
        showlegend=false,
        hovertemplate =
        "Sh=%{x}<br>" *
        "St=%{y}<br>" *
        "z=%{z}<br>" *
        "Sgfl=$sgfl<br>" *
        "Sgfm-Droop=$sgfm_d<br>" *
        "Sgfm-VSM=$sgfm_v<extra></extra>",
        contours=attr(
        x=attr(show=true, color="gray", width=2),
        y=attr(show=true, color="gray", width=2),
        z=attr(show=true, color="gray", width=2))
        ))

    end

    # Crear un botón toggle por superficie
    buttons = []
    for (i, (sgfl, sgfm_d, sgfm_v)) in enumerate(combinations)
        push!(buttons, attr(
            label="Sgfl=$sgfl, Sgfm-Droop=$sgfm_d, Sgfm-VSM=$sgfm_v [MW]",
            method="restyle",
            args=[
                Dict("visible" => ["toggle"]),
                [i-1]  # Índice correcto, Plotly es base 0
            ]
        ))
    end

    # Botón para ocultar todas las superficies
    push!(buttons, attr(
        label="❌ Ocultar todo",
        method="restyle",
        args=[
            Dict("visible" => repeat([false], length(surfaces))),
            collect(0:length(surfaces)-1)
        ]
    ))

    layout = Layout(
        title = "Gráficos Nadir ─── ΔP = $Pl [p.u.]",
        scene = attr(
            xaxis = attr(title = "Sh [MW]"),
            yaxis = attr(title = "St [MW]"),
            zaxis = attr(title = "F nadir [Hz]"),
            camera = attr(eye = attr(x=-1.5, y=-1.5, z=1.1))
        ),
        updatemenus=[attr(buttons=buttons, direction="down", showactive=false)]
    )

    fig = plot(surfaces, layout)

    display(fig)

    PlotlyJS.savefig(fig, "grafico_nadir.png")

end



function generate_filtered_nadir_scatter(results::Dict{NTuple{5, Number}, Number}, nadir_limit::Number, Pl::Number)

    # Obtener combinaciones únicas de (Sgfm_d, Sgfm_v)
    sgfm_d_values = sort(unique(k[4] for k in keys(results)))
    sgfm_v_values = sort(unique(k[5] for k in keys(results)))
    combinations = [(sgfm_d, sgfm_v) for sgfm_d in sgfm_d_values, sgfm_v in sgfm_v_values]

    traces = Vector{GenericTrace{Dict{Symbol, Any}}}()

    for (i, (sgfm_d_val, sgfm_v_val)) in enumerate(combinations)
        # Filtrar puntos que pertenecen a esta combinación
        selected = filter(k -> k[4] == sgfm_d_val && k[5] == sgfm_v_val, keys(results))

        x_vals = Float64[]
        y_vals = Float64[]
        z_vals = Float64[]
        val_list = Float64[]

        for k in selected
            push!(x_vals, k[1])
            push!(y_vals, k[2])
            push!(z_vals, k[3])  # Sc1
            push!(val_list, results[k])
        end

        color_list = map(v -> v + 50 > nadir_limit ? "blue" : "red", val_list)

        push!(traces, scatter3d(
            x=x_vals,
            y=y_vals,
            z=z_vals,
            mode="markers",
            marker=attr(size=5, color=color_list),
            visible=(i == 1),
            hovertemplate =
            "Sh = %{x}<br>" *
            "St = %{y}<br>" *
            "Sgfl = %{z}<br>" *
            "Sgfm-Droop = $sgfm_d_val<br>" *
            "Sgfm-VSM = $sgfm_v_val<extra></extra>",
            showlegend=false
        ))
    end

    # Crear botones para seleccionar combinaciones
    buttons = []
    for (i, (sgfm_d_val, sgfm_v_val)) in enumerate(combinations)
        estado = [j == i for j in 1:length(traces)]
        push!(buttons, attr(
            label="Sgfm-Droop=$sgfm_d_val, Sgfm-VSM=$sgfm_v_val [MW]",
            method="update",
            args=[Dict("visible" => estado)]
        ))
    end

    layout = Layout(
        title="Cumplimiento Límite Nadir ─── ΔP = $Pl [p.u.]",
        scene=attr(
            xaxis=attr(title="Sh [MW]"),
            yaxis=attr(title="St [MW]"),
            zaxis=attr(title="Sgfl [MW]")
        ),
        updatemenus=[attr(buttons=buttons, direction="down", showactive=true)],
        legend=attr(x=1, y=0.9)
    )

    fig = plot(traces, layout)

    display(fig)

end


function generate_filtered_percentage_nadir_scatter(results::Dict{NTuple{5, Number}, Number}, Pl::Number)

    # Extraer combinaciones únicas de GFL, GFM-Droop y GFM-VSM
    gfl_values = sort(unique(k[3] for k in keys(results)))
    gfmd_values = sort(unique(k[4] for k in keys(results)))
    gfmv_values = sort(unique(k[5] for k in keys(results)))
    combinations = [(gfl, gfmd, gfmv) for gfl in gfl_values, gfmd in gfmd_values, gfmv in gfmv_values
                    if gfl + gfmd + gfmv < 1.0]  # Filtrar combinaciones válidas

    traces = GenericTrace[]

    for (i, (gfl, gfmd, gfmv)) in enumerate(combinations)
        # Filtrar puntos que pertenecen a esta combinación
        selected = filter(k -> k[3] == gfl && k[4] == gfmd && k[5] == gfmv, keys(results))

        x_vals = Float64[]
        y_vals = Float64[]
        z_vals = Float64[]
        f_nadir_vals = Float64[]

        for k in selected
            push!(x_vals, k[1] * 100)  # Convertir a porcentaje
            push!(y_vals, k[2] * 100)  # Convertir a porcentaje
            f_adjusted = results[k] + 50
            push!(z_vals, f_adjusted)
            push!(f_nadir_vals, f_adjusted)
        end

        push!(traces, scatter3d(
            x = x_vals,
            y = y_vals,
            z = z_vals,
            mode = "markers",
            marker = attr(
                size = 5,
                color = f_nadir_vals,
                colorscale = "Viridis",
                showscale = false,  # Ocultar la barra de color
                opacity = 0.8
            ),
            name = "GFL=$(gfl*100)%, GFM-D=$(gfmd*100)%, GFM-VSM=$(gfmv*100)%",
            visible = (i == 1),
            hovertemplate = 
                "Sh = %{x:.1f}%<br>" *
                "St = %{y:.1f}%<br>" *
                "GFL = $(gfl*100)%<br>" *
                "GFM-D = $(gfmd*100)%<br>" *
                "GFM-VSM = $(gfmv*100)%<br>" *
                "Frecuencia Nadir = %{z:.2f} Hz<extra></extra>"
        ))
    end

    # Crear botones para seleccionar combinaciones
    buttons = []
    for (i, (gfl, gfmd, gfmv)) in enumerate(combinations)
        estado = [j == i for j in 1:length(traces)]
        push!(buttons, attr(
            label = "GFL=$(gfl*100)%, GFM-D=$(gfmd*100)%, GFM-VSM=$(gfmv*100)%",
            method = "update",
            args = [Dict("visible" => estado)]
        ))
    end

    layout = Layout(
        title = "Frecuencia Nadir vs. Porcentaje de Tecnologías ─── ΔP = $Pl [p.u.]",
        scene = attr(
            xaxis = attr(title = "Hidroeléctrica [%]"),
            yaxis = attr(title = "Térmica [%]"),
            zaxis = attr(title = "Frecuencia Nadir [Hz]")
        ),
        updatemenus = [attr(
            buttons = buttons,
            direction = "down",
            showactive = true,
            x = 1.1,
            xanchor = "left",
            y = 1.0,
            yanchor = "top"
        )],
        margin = attr(l = 0, r = 0, b = 0, t = 50),
        hoverlabel = attr(
            bgcolor = "black",
            font = attr(color = "white")
        )
    )

    fig = plot(traces, layout)
    display(fig)
end


function generate_frequency_metrics_plots(frequency_metrics_dict::Dict{Int, Tuple{Number, Number, Number}}, minimum_nadir::Number, maximum_RoCoF::Number, minimum_QSS::Number)

    Δnadir_reference = [minimum_nadir for _ in 1:24]
    RoCoF_reference = [maximum_RoCoF for _ in 1:24]
    ΔQSS_reference = [minimum_QSS for _ in 1:24]

    hours = 1:24

    Δnadir_values = [50 + frequency_metrics_dict[t][1] for t in sort(collect(keys(frequency_metrics_dict)))]
    RoCoF_values = [-frequency_metrics_dict[t][2] for t in sort(collect(keys(frequency_metrics_dict)))]
    ΔQSS_values = [50 + frequency_metrics_dict[t][3] for t in sort(collect(keys(frequency_metrics_dict)))]

    trace_nadir_sim = scatter(
        x = hours, y = Δnadir_values,
        mode = "lines+markers", name = "Simulation nadir frequency values",
        line = attr(dash = "solid", width = 2),
        marker = attr(size = 7),
        hovertemplate = "Hour: %{x}<br>fnadir value: %{y}<extra></extra>"
    )

    trace_nadir_ref = scatter(
        x = hours, y = Δnadir_reference,
        mode = "lines+markers", name = "Reference nadir frequency values",
        line = attr(dash = "dot", width = 2),
        marker = attr(size = 7),
        hovertemplate = "Hour: %{x}<br>fnadir value: %{y}<extra></extra>"
    )

    trace_rocof_sim = scatter(
        x = hours, y = RoCoF_values,
        mode = "lines+markers", name = "Simulation RoCoF values",
        line = attr(dash = "solid", width = 2),
        marker = attr(size = 7),
        hovertemplate = "Hour: %{x}<br>RoCoF value: %{y}<extra></extra>"
    )

    trace_rocof_ref = scatter(
        x = hours, y = RoCoF_reference,
        mode = "lines+markers", name = "Reference RoCoF values",
        line = attr(dash = "dot", width = 2),
        marker = attr(size = 7),
        hovertemplate = "Hour: %{x}<br>RoCoF value: %{y}<extra></extra>"
    )

    trace_qss_sim = scatter(
        x = hours, y = ΔQSS_values,
        mode = "lines+markers", name = "Simulation QSS frequency values",
        line = attr(dash = "solid", width = 2),
        marker = attr(size = 7),
        hovertemplate = "Hour: %{x}<br>fQSS value: %{y}<extra></extra>"
    )

    trace_qss_ref = scatter(
        x = hours, y = ΔQSS_reference,
        mode = "lines+markers", name = "Reference QSS frequency values",
        line = attr(dash = "dot", width = 2),
        marker = attr(size = 7),
        hovertemplate = "Hour: %{x}<br>fQSS value: %{y}<extra></extra>"
    )

    layout_nadir = Layout(title = "Nadir frequency values", xaxis_title = "Hour", yaxis_title = "Frequency [Hz]", showlegend = true)
    layout_rocof = Layout(title = "RoCoF values", xaxis_title = "Hour", yaxis_title = "RoCoF [Hz/s]", showlegend = true)
    layout_qss = Layout(title = "QSS frequency values", xaxis_title = "Hour", yaxis_title = "Frequency [Hz]", showlegend = true)
    
    
    display(plot([trace_nadir_sim, trace_nadir_ref], layout_nadir))
    display(plot([trace_rocof_sim, trace_rocof_ref], layout_rocof))
    display(plot([trace_qss_sim, trace_qss_ref], layout_qss))
end

function plot_nadir_2d(nadir_results::Dict{Tuple{Number, Number, Number}, Number})

    # Extraer puntos únicos en el plano (Sh, Sg) y verificar si se cumple la condición para algún Sc
    point_status = Dict{Tuple{Number, Number}, Bool}()

    for ((sh, _, sc), val) in nadir_results
        if sh != 0
            key = (sh, sc)
            cumple = val >= -1.0
            println(key, val, cumple)
            # Si ya hay un valor y es true, mantenerlo como true
            if haskey(point_status, key)
                point_status[key] = point_status[key] || cumple
            else
                point_status[key] = cumple
            end
        end
    end

    # Separar puntos por color
    sh_cumple = Float64[]
    sc_cumple = Float64[]
    sh_falla = Float64[]
    sc_falla = Float64[]

    for ((sh, sc), cumple) in point_status
        if cumple
            push!(sh_cumple, sh)
            push!(sc_cumple, sc)
        else
            push!(sh_falla, sh)
            push!(sc_falla, sc)
        end
    end

    # Crear trazas de puntos
    trace_cumple = scatter(
        x = sh_cumple,
        y = sc_cumple,
        mode = "markers",
        marker = attr(color = "green", size = 10),
        name = "Nadir ≥ 49 Hz"
    )

    trace_falla = scatter(
        x = sh_falla,
        y = sc_falla,
        mode = "markers",
        marker = attr(color = "red", size = 10),
        name = "Nadir < 49 Hz"
    )

    layout = Layout(
        xaxis = attr(
        title = "Sh [MW]",
        showgrid = true,
        titlefont = attr(size = 36, family = "Latin Modern Roman", color = "black"),
        tickfont = attr(size = 36, family = "Latin Modern Roman", color = "black"),
        gridcolor = "lightgray",
        showline = true,
        linecolor = "black",
        linewidth = 2
        ),
        yaxis = attr(
            title = "Sc [MW]",
            showgrid = true,
            titlefont = attr(size = 36, family = "Latin Modern Roman", color = "black"),
            tickfont = attr(size = 36, family = "Latin Modern Roman", color = "black"),
            gridcolor = "lightgray",
            showline = true,
            linecolor = "black",
            linewidth = 2
        ),
            legend = attr(
        x = 0.7,
        y = 1,
        font = attr(size = 36, family = "Latin Modern Roman", color = "black"),  # Aquí defines el tamaño de letra
        bordercolor = "black",   # Color del borde de la leyenda
        borderwidth = 2          # Ancho del borde
            ),
        plot_bgcolor = "white",
        paper_bgcolor = "white"
    )

    fig = plot([trace_cumple, trace_falla], layout)
    display(fig)

    PlotlyJS.savefig(fig, "nadir_2d.pdf")
end

end