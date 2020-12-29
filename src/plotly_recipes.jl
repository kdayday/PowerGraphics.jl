### PlotlyJS set up

function set_seriescolor(seriescolor::Array, gens::Array)
    colors = []
    for i in 1:length(gens)
        count = i % length(seriescolor)
        count = count == 0 ? length(seriescolor) : count
        colors = vcat(colors, seriescolor[count])
    end
    return colors
end

function _empty_plot(backend::Plots.PlotlyJSBackend)
    traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
    return Plots.PlotlyJS.plot(traces)
end

########################################## PLOTLYJS STACK ##########################

function _stack_plot_internal(
    res::Vector,
    backend::Plots.PlotlyJSBackend,
    save_fig::Any,
    set_display::Bool,
    reserves::Vector;
    kwargs...,
)
    seriescolor = get(kwargs, :seriescolor, PLOTLY_DEFAULT)
    title = get(kwargs, :title, " ")
    ylabel = _make_ylabel(IS.get_base_power(res[1]))
    stack = plotly_stack_plots(res, seriescolor, ylabel; kwargs...)
    gen_stack = plotly_stack_gen(res, seriescolor, title, ylabel, reserves; kwargs...)
    return PlotList(merge(stack, gen_stack))
end

function plotly_stack_gen(
    results::Vector,
    seriescolors::Vector,
    title::String,
    ylabel::String,
    reserve_list::Vector;
    kwargs...,
)
    set_display = get(kwargs, :display, true)
    line_shape = get(kwargs, :stair, false) ? "hv" : "linear"
    save_fig = get(kwargs, :save, nothing)
    format = get(kwargs, :format, "png")
    plot_output = Dict()
    plots = []
    for i in 1:length(results)
        gens = collect(keys(IS.get_variables(results[i])))
        params = collect(keys(results[i].parameter_values))
        time_range = IS.get_timestamp(results[i])[:, 1]
        stack = []
        for (k, v) in IS.get_variables(results[i])
            stack = vcat(stack, [sum(convert(Matrix, v), dims = 2)])
        end
        parameters = []
        for (p, v) in results[i].parameter_values
            parameters = vcat(stack, [sum(convert(Matrix, v), dims = 2)])
        end
        stack = hcat(stack...)
        parameters = hcat(parameters...)
        trace = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
        seriescolor = set_seriescolor(seriescolors, gens)
        line_shape = get(kwargs, :stairs, "linear")
        i == 1 ? leg = true : leg = false
        for gen in 1:length(gens)
            push!(
                trace,
                Plots.PlotlyJS.scatter(;
                    name = gens[gen],
                    showlegend = leg,
                    x = time_range,
                    y = stack[:, gen],
                    stackgroup = "one",
                    mode = "lines",
                    line_shape = line_shape,
                    fill = "tonexty",
                    line_color = seriescolor[gen],
                    fillcolor = seriescolor[gen],
                ),
            )
        end
        if !isempty(params)
            for param in 1:length(params)
                push!(
                    trace,
                    Plots.PlotlyJS.scatter(;
                        name = params[param],
                        x = time_range,
                        y = parameters[:, param],
                        showlegend = leg,
                        stackgroup = "two",
                        mode = "lines",
                        line_shape = line_shape,
                        fill = "tozeroy",
                        line_color = "black",
                        line_dash = "dash",
                        line_width = "3",
                        fillcolor = "rgba(0, 0, 0, 0)",
                    ),
                )
            end
        end
        p = Plots.PlotlyJS.plot(
            trace,
            Plots.PlotlyJS.Layout(title = title, yaxis_title = ylabel),
        )
        plots = vcat(plots, p)
    end
    plots = vcat(plots...)
    set_display && Plots.display(plots)
    if !isnothing(reserve_list[1])
        for key in keys(reserve_list[1])
            r_plots = []
            for i in 1:length(reserve_list)
                i == 1 ? leg = true : leg = false
                time_range = IS.get_timestamp(results[i])[:, 1]
                r_data = []
                r_gens = []
                r_traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
                for (k, v) in reserve_list[i][key]
                    r_data = vcat(r_data, [sum(convert(Matrix, v), dims = 2)])
                    r_gens = vcat(r_gens, k)
                end
                r_data = hcat(r_data...)
                r_seriescolor = set_seriescolor(seriescolors, r_gens)
                for gen in 1:size(r_gens, 1)
                    push!(
                        r_traces,
                        Plots.PlotlyJS.scatter(;
                            name = r_gens[gen],
                            x = time_range,
                            y = r_data[:, gen],
                            stackgroup = "one",
                            mode = "lines",
                            showlegend = leg,
                            line_shape = line_shape,
                            fill = "tonexty",
                            line_color = r_seriescolor[gen],
                            fillcolor = r_seriescolor[gen],
                        ),
                    )
                end
                r_plot = Plots.PlotlyJS.plot(
                    r_traces,
                    Plots.PlotlyJS.Layout(title = "$(key) Reserves", yaxis_title = ylabel),
                )
                r_plots = vcat(r_plots, r_plot)
            end
            r_plot = vcat(r_plots...)
            set_display && Plots.display(r_plot)
            if !isnothing(save_fig)
                Plots.PlotlyJS.savefig(
                    r_plot,
                    joinpath(save_fig, "$(key)_Reserves.$format");
                    width = 800,
                    height = 450,
                )
            end
            plot_output[Symbol("$(key)_Reserves")] = r_plot
        end
    end
    stack_title = line_shape == "linear" ? "Stack_Generation" : "Stair_Generation"
    title = title == " " ? stack_title : replace(title, " " => "_")
    if !isnothing(save_fig)
        Plots.PlotlyJS.savefig(
            plots,
            joinpath(save_fig, "$title.$format");
            width = 800,
            height = 450,
        )
    end
    plot_output[Symbol(title)] = plots
    return plot_output
end

function plotly_stack_plots(results::Array, seriescolor::Array, ylabel::String; kwargs...)
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    line_shape = get(kwargs, :stair, false) ? "hv" : "linear"
    _check_matching_variables(results)
    plot_list = Dict()
    for key in collect(keys(IS.get_variables(results[1, 1])))
        plots = []
        for res in 1:size(results, 2)
            traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
            var = IS.get_variables(results[1, res])[key]
            gens = collect(names(var))
            seriescolor = set_seriescolor(seriescolor, gens)
            for gen in 1:length(gens)
                leg = res == 1 ? true : false
                push!(
                    traces,
                    Plots.PlotlyJS.scatter(;
                        name = gens[gen],
                        showlegend = leg,
                        x = results[1, res].timestamp[:, 1],
                        y = convert(Matrix, var)[:, gen],
                        stackgroup = "one",
                        mode = "lines",
                        line_shape = line_shape,
                        fill = "tonexty",
                        line_color = seriescolor[gen],
                        fillcolor = "transparent",
                    ),
                )
            end
            p = Plots.PlotlyJS.plot(
                traces,
                Plots.PlotlyJS.Layout(
                    title = "$key",
                    yaxis_title = ylabel,
                    grid = (rows = 3, columns = 1, pattern = "independent"),
                ),
            )
            plots = vcat(plots, p)
        end
        plots = vcat(plots...)
        set_display && Plots.display(plots)
        if !isnothing(save_fig)
            format = get(kwargs, :format, "png")
            key_title = line_shape == "linear" ? "$(key)_Stack" : "$(key)_Stair"
            Plots.PlotlyJS.savefig(
                plots,
                joinpath(save_fig, "$key_title.$format");
                width = 800,
                height = 450,
            )
        end
        plot_list[key] = plots
    end
    return plot_list
end

function plotly_fuel_stack_gen(
    stacked_gen::StackedGeneration,
    seriescolor::Vector,
    title::String,
    ylabel::String;
    kwargs...,
)
    stair = get(kwargs, :stair, false)
    line_shape = stair ? "hv" : "linear"
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
    gens = stacked_gen.labels
    seriescolor = set_seriescolor(seriescolor, gens)
    for gen in 1:length(gens)
        push!(
            traces,
            Plots.PlotlyJS.scatter(;
                name = gens[gen],
                x = stacked_gen.time_range,
                y = stacked_gen.data_matrix[:, gen],
                stackgroup = "one",
                mode = "lines",
                fill = "tonexty",
                line_color = seriescolor[gen],
                fillcolor = seriescolor[gen],
                line_shape = line_shape,
                showlegend = true,
            ),
        )
    end
    if get(kwargs, :load, false) == true
        push!(
            traces,
            Plots.PlotlyJS.scatter(;
                name = "Load",
                x = stacked_gen.time_range,
                y = stacked_gen.parameters[:, 1],
                mode = "lines",
                line_color = "black",
                line_shape = line_shape,
                marker_size = 12,
            ),
        )
    end

    p = Plots.PlotlyJS.plot(
        traces,
        Plots.PlotlyJS.Layout(title = title, yaxis_title = ylabel),
    )
    set_display && Plots.display(p)
    if !isnothing(save_fig)
        format = get(kwargs, :format, "png")
        title = replace(title, " " => "_")
        Plots.PlotlyJS.savefig(
            p,
            joinpath(save_fig, "$title.$format");
            width = 800,
            height = 450,
        )
    end
    return p
end

function plotly_fuel_stack_gen(
    stacks::Array{StackedGeneration},
    seriescolor::Array,
    title::String,
    ylabel::String;
    kwargs...,
)
    line_shape = get(kwargs, :stair, false) ? "hv" : "linear"
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    plots = []
    for stack in 1:length(stacks)
        trace = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
        gens = stacks[stack].labels
        seriescolor = set_seriescolor(seriescolor, gens)
        for gen in 1:length(gens)
            leg = stack == 1 ? true : false
            push!(
                trace,
                Plots.PlotlyJS.scatter(;
                    name = gens[gen],
                    showlegend = leg,
                    x = stacks[stack].time_range,
                    y = stacks[stack].data_matrix[:, gen],
                    stackgroup = "one",
                    mode = "lines",
                    fill = "tonexty",
                    line_color = seriescolor[gen],
                    fillcolor = seriescolor[gen],
                    line_shape = line_shape,
                ),
            )
        end
        p = Plots.PlotlyJS.plot(
            trace,
            Plots.PlotlyJS.Layout(title = title, yaxis_title = ylabel),
        )
        plots = vcat(plots, p)
    end
    plots = vcat(plots...)
    set_display && Plots.display(plots)
    if !isnothing(save_fig)
        format = get(kwargs, :format, "png")
        title = replace(title, " " => "_")
        Plots.PlotlyJS.savefig(
            plots,
            joinpath(save_fig, "$title.$format");
            width = 800,
            height = 450,
        )
    end
    return plots
end
############################# PLOTLYJS BAR ##############################################

function _bar_plot_internal(
    res::Vector,
    backend::Plots.PlotlyJSBackend,
    save_fig::Any,
    set_display::Bool,
    interval::Float64,
    reserves::Vector;
    kwargs...,
)
    seriescolor = get(kwargs, :seriescolor, PLOTLY_DEFAULT)
    title = get(kwargs, :title, " ")
    ylabel = _make_bar_ylabel(IS.get_base_power(res[1]))
    plots = plotly_bar_plots(res, seriescolor, ylabel, interval; kwargs...)
    gen_plots =
        plotly_bar_gen(res, seriescolor, title, ylabel, interval, reserves; kwargs...)
    return PlotList(merge(plots, gen_plots))
end

function plotly_fuel_bar_gen(
    bar_gen::Vector{BarGeneration},
    seriescolor::Array,
    title::String,
    ylabel::String,
    interval::Float64;
    kwargs...,
)
    time_range = bar_gen[1].time_range
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    time_span = IS.convert_compound_period(
        convert(Dates.TimePeriod, time_range[2] - time_range[1]) * length(time_range),
    )
    seriescolor = set_seriescolor(seriescolor, bar_gen[1].labels)
    plots = []
    for bar in 1:length(bar_gen)
        traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
        p_traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
        gens = bar_gen[bar].labels
        params = bar_gen[bar].p_labels
        for gen in 1:length(gens)
            leg = bar == 1 ? true : false
            push!(
                traces,
                Plots.PlotlyJS.scatter(;
                    name = gens[gen],
                    showlegend = leg,
                    x = ["$time_span, $(time_range[1])"],
                    y = (bar_gen[bar].bar_data[:, gen]) ./ interval,
                    type = "bar",
                    barmode = "stack",
                    marker_color = seriescolor[gen],
                ),
            )
        end
        #=
        for param in 1:length(params)
            push!(
                p_traces,
                Plots.PlotlyJS.scatter(;
                    name = params[param],
                    x = ["$time_span, $(time_range[1])"],
                    y = bar_gen.parameters[:, param],
                    type = "bar",
                    marker_color = "rgba(0, 0, 0, .1)",
                ),
            )
        end
        =#
        p = Plots.PlotlyJS.plot(
            [traces; p_traces],
            Plots.PlotlyJS.Layout(
                title = title,
                yaxis_title = ylabel,
                color = seriescolor,
                barmode = "overlay",
            ),
        )
        plots = vcat(plots, p)
    end
    plots = vcat(plots...)
    set_display && Plots.display(plots)
    if !isnothing(save_fig)
        title = title == " " ? "Bar_Generation" : replace(title, " " => "_")
        format = get(kwargs, :format, "png")
        Plots.PlotlyJS.savefig(
            plots,
            joinpath(save_fig, "$title.$format");
            width = 800,
            height = 450,
        )
    end
    return plots
end

function plotly_bar_gen(
    results::Array,
    seriescolor::Array,
    title::String,
    ylabel::String,
    interval::Float64,
    reserve_list::Any;
    kwargs...,
)
    time_range = IS.get_timestamp(results[1])[:, 1]
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    format = get(kwargs, :format, "png")
    time_span = IS.convert_compound_period(
        convert(Dates.TimePeriod, time_range[2] - time_range[1]) * length(time_range),
    )
    plots = []
    plot_output = Dict()
    for i in 1:length(results)
        traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
        p_traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
        gens = collect(keys(IS.get_variables(results[i])))
        seriescolors = set_seriescolor(seriescolor, gens)
        params = collect(keys((results[i].parameter_values)))
        data = []
        for (k, v) in IS.get_variables(results[i])
            data = vcat(data, [sum(sum(convert(Matrix, v), dims = 2), dims = 1)])
        end
        data = hcat(data...) ./ interval
        p_data = []
        for (p, v) in results[i].parameter_values
            p_data = vcat(p_data, [sum(sum(convert(Matrix, v), dims = 2), dims = 1)])
        end
        p_data = hcat(p_data...) ./ interval
        for gen in 1:length(gens)
            i == 1 ? leg = true : leg = false
            push!(
                traces,
                Plots.PlotlyJS.scatter(;
                    name = gens[gen],
                    showlegend = leg,
                    x = ["$time_span, $(time_range[1])"],
                    y = data[:, gen],
                    type = "bar",
                    barmode = "stack",
                    marker_color = seriescolors[gen],
                ),
            )
        end
        #=
        for param in 1:length(params)
            push!(
                p_traces,
                Plots.PlotlyJS.scatter(;
                    name = params[param],
                    x = ["$time_span, $(time_range[1])"],
                    y = bar_gen.parameters[:, param],
                    type = "bar",
                    marker_color = "rgba(0, 0, 0, .1)",
                ),
            )
        end
        =#
        p = Plots.PlotlyJS.plot(
            [traces; p_traces],
            Plots.PlotlyJS.Layout(
                title = title,
                yaxis_title = ylabel,
                color = seriescolors,
                barmode = "overlay",
            ),
        )
        plots = vcat(plots, p)
    end
    plots = vcat(plots...)
    set_display && Plots.display(plots)
    title = title == " " ? "Bar_Generation" : title
    title = replace(title, " " => "_")
    plot_output[Symbol(title)] = plots
    if !isnothing(save_fig)
        format = get(kwargs, :format, "png")
        Plots.PlotlyJS.savefig(
            plots,
            joinpath(save_fig, "$title.$format");
            width = 800,
            height = 450,
        )
    end
    if !isnothing(reserve_list[1])
        for key in keys(reserve_list[1])
            r_plots = []
            for i in 1:length(reserve_list)
                r_data = []
                for (k, v) in reserve_list[i][key]
                    r_data =
                        vcat(r_data, [sum(sum(convert(Matrix, v), dims = 2), dims = 1)])
                end
                r_data = hcat(r_data...) / interval
                r_gens = collect(keys(reserve_list[i][key]))
                r_traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
                r_seriescolor = set_seriescolor(seriescolor, r_gens)
                for gen in 1:length(r_gens)
                    i == 1 ? leg = true : leg = false
                    push!(
                        r_traces,
                        Plots.PlotlyJS.scatter(;
                            name = r_gens[gen],
                            x = ["$time_span, $(time_range[1])"],
                            y = r_data[:, gen],
                            type = "bar",
                            barmode = "stack",
                            stackgroup = "one",
                            marker_color = r_seriescolor[gen],
                            showlegend = leg,
                        ),
                    )
                end
                r_plot = Plots.PlotlyJS.plot(
                    r_traces,
                    Plots.PlotlyJS.Layout(
                        title = "$(key) Reserves",
                        yaxis_title = ylabel,
                        color = seriescolor,
                        barmode = "stack",
                    ),
                )
                r_plots = vcat(r_plots, r_plot)
            end
            r_plot = vcat(r_plots...)
            set_display && Plots.display(r_plot)
            if !isnothing(save_fig)
                Plots.PlotlyJS.savefig(
                    r_plot,
                    joinpath(save_fig, "$(key)_Reserves.$format");
                    width = 800,
                    height = 450,
                )
            end
            plot_output[Symbol("$(key)_Reserves")] = r_plot
        end
    end
    return plot_output
end

function plotly_bar_plots(
    results::Vector,
    seriescolor::Vector,
    ylabel::String,
    interval::Float64;
    kwargs...,
)
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    time_range = results[1].timestamp
    time_span = IS.convert_compound_period(
        convert(Dates.TimePeriod, time_range[2, 1] - time_range[1, 1]) *
        size(time_range, 1),
    )
    plot_list = Dict()
    for key in collect(keys(IS.get_variables(results[1])))
        plots = []
        for res in 1:length(results)
            var = IS.get_variables(results[res])[key]
            traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
            gens = collect(names(var))
            seriescolor = set_seriescolor(seriescolor, gens)
            for gen in 1:length(gens)
                leg = res == 1 ? true : false
                push!(
                    traces,
                    Plots.PlotlyJS.scatter(;
                        name = gens[gen],
                        showlegend = leg,
                        x = ["$time_span, $(time_range[1, 1])"],
                        y = sum(convert(Matrix, var)[:, gen], dims = 1) ./ interval,
                        type = "bar",
                        barmode = "stack",
                        marker_color = seriescolor[gen],
                    ),
                )
            end
            p = Plots.PlotlyJS.plot(
                traces,
                Plots.PlotlyJS.Layout(
                    title = "$key",
                    yaxis_title = ylabel,
                    barmode = "stack",
                ),
            )
            plots = vcat(plots, p)
        end
        plot = vcat(plots...)
        set_display && Plots.display(plot)
        if !isnothing(save_fig)
            format = get(kwargs, :format, "png")
            Plots.PlotlyJS.savefig(
                plot,
                joinpath(save_fig, "$(key)_Bar.$format");
                width = 800,
                height = 450,
            )
        end
        plot_list[key] = plot
    end
    return plot_list
end

###################################### PLOTLYJS FUEL ################################
function _fuel_plot_internal(
    stack::Vector{StackedGeneration},
    bar::Vector{BarGeneration},
    seriescolor::Array,
    backend::Plots.PlotlyJSBackend,
    save_fig::Any,
    set_display::Bool,
    title::String,
    ylabel::NamedTuple{(:stack, :bar), Tuple{String, String}},
    interval::Float64;
    kwargs...,
)
    stair = get(kwargs, :stair, false)
    stack_title = stair ? "$(title) Stair" : stack_title = "$(title) Stack"
    stacks = plotly_fuel_stack_gen(stack, seriescolor, stack_title, ylabel.stack; kwargs...)
    bars = plotly_fuel_bar_gen(
        bar,
        seriescolor,
        "$(title) Bar",
        ylabel.bar,
        interval;
        kwargs...,
    )
    return PlotList(Dict(:Fuel_Stack => stacks, :Fuel_Bar => bars))
end

############################## PLOTLYJS DEMAND PLOTS ##########################

function _demand_plot_internal(results::Vector, backend::Plots.PlotlyJSBackend; kwargs...)
    seriescolor = get(kwargs, :seriescolor, PLOTLY_DEFAULT)
    save_fig = get(kwargs, :save, nothing)
    set_display = get(kwargs, :display, true)
    ylabel = _make_ylabel(IS.get_base_power(results[1]))
    line_shape = get(kwargs, :stair, false) ? "hv" : "linear"
    plot_list = Dict()
    for (key, parameters) in results[1].parameter_values
        plots = []
        title = get(kwargs, :title, "$key")
        for n in 1:length(results)
            traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
            parameters = results[n].parameter_values[key]
            p_names = collect(names(parameters))
            n_traces = length(p_names)
            seriescolor =
                length(seriescolor) < n_traces ?
                repeat(seriescolor, Int64(ceil(n_traces / length(seriescolor)))) :
                seriescolor
            n == 1 ? leg = true : leg = false
            for i in 1:n_traces
                push!(
                    traces,
                    Plots.PlotlyJS.scatter(;
                        name = p_names[i],
                        x = results[n].timestamp[:, 1],
                        y = parameters[:, p_names[i]],
                        #stackgroup = "one",
                        mode = "lines",
                        #fill = "tonexty",
                        line_color = seriescolor[i],
                        showlegend = leg,
                    ),
                )
            end
            title = get(kwargs, :title, "$key")
            p = Plots.PlotlyJS.plot(
                traces,
                Plots.PlotlyJS.Layout(title = title, yaxis_title = ylabel),
            )
            plots = vcat(plots, p)
        end
        plots = vcat(plots...)
        set_display && Plots.display(plots)
        if !isnothing(save_fig)
            format = get(kwargs, :format, "png")
            Plots.PlotlyJS.savefig(
                plots,
                joinpath(save_fig, "$title.$format");
                width = 800,
                height = 450,
            )
        end
        plot_list[key] = plots
    end
    return PlotList(plot_list)
end

################################ SYSTEM DEMAND PLOTS ###################################

function _demand_plot_internal(
    parameters::Array,
    base_power::Array,
    backend::Plots.PlotlyJSBackend;
    kwargs...,
)
    n_traces = size((parameters[1]))[1]
    seriescolor = get(kwargs, :seriescolor, PLOTLY_DEFAULT)
    seriescolor =
        length(seriescolor) < n_traces ?
        repeat(seriescolor, Int64(ceil(n_traces / length(seriescolor)))) : seriescolor
    save_fig = get(kwargs, :save, nothing)
    set_display = get(kwargs, :display, true)
    line_shape = get(kwargs, :stair, false) ? "hv" : "linear"
    plot_list = Dict()
    plots = []
    title = get(kwargs, :title, "PowerLoad")
    for i in 1:length(parameters)
        data = DataFrames.select(parameters[i], DataFrames.Not(:timestamp))
        p_names = collect(names(data))
        ylabel = _make_ylabel(base_power[i])
        traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
        for n in 1:length(p_names)
            i == 1 ? leg = true : leg = false
            stackgroup = get(kwargs, :stack, false) ? "one" : "$n"
            fillcolor = get(kwargs, :stack, false) ? seriescolor[n] : "transparent"
            push!(
                traces,
                Plots.PlotlyJS.scatter(;
                    name = p_names[n],
                    x = parameters[i][:, :timestamp],
                    y = data[:, p_names[n]],
                    stackgroup = stackgroup,
                    mode = "lines",
                    fill = "tonexty",
                    fillcolor = fillcolor,
                    line_color = seriescolor[n],
                    showlegend = leg,
                ),
            )
        end
        p = Plots.PlotlyJS.plot(
            traces,
            Plots.PlotlyJS.Layout(title = title, yaxis_title = ylabel),
        )
        plots = vcat(plots, p)
    end
    plots = vcat(plots...)
    set_display && Plots.display(plots)
    if !isnothing(save_fig)
        format = get(kwargs, :format, "png")
        title = replace(title, " " => "_")
        Plots.PlotlyJS.savefig(
            plots,
            joinpath(save_fig, "$title.$format");
            width = 800,
            height = 450,
        )
    end
    plot_list[Symbol(title)] = plots
    return PlotList(plot_list)
end

function _variable_plots_internal(
    p::Plots.Plot{Plots.PlotlyJSBackend},
    variable::DataFrames.DataFrame,
    time_range::Array,
    base_power::Float64,
    variable_name::Symbol,
    backend::Plots.PlotlyJSBackend;
    kwargs...,
)
    seriescolor = get(kwargs, :seriescolor, PLOTLY_DEFAULT)
    y_label = _make_ylabel(base_power)
    title = get(kwargs, :title, "$variable_name")
    plot = plotly_dataframe_plots(
        p,
        variable,
        seriescolor,
        time_range,
        title,
        y_label;
        kwargs...,
    )
    return plot
end

function _dataframe_plots_internal(
    variable::DataFrames.DataFrame,
    time_range::Array,
    backend::Plots.PlotlyJSBackend;
    kwargs...,
)
    seriescolor = get(kwargs, :seriescolor, PLOTLY_DEFAULT)
    save_fig = get(kwargs, :save, nothing)
    unit = get(kwargs, :y_label, nothing)
    y_label = isnothing(unit) ? "Generation per unit" : unit
    title = get(kwargs, :title, " ")
    p = plotly_dataframe_plots(variable, seriescolor, time_range, title, y_label; kwargs...)
    return p
end

function _dataframe_plots_internal(
    p::Union{Plots.PlotlyJS.SyncPlot, Nothing},
    variable::DataFrames.DataFrame,
    time_range::Array,
    backend::Plots.PlotlyJSBackend;
    kwargs...,
)
    seriescolor = get(kwargs, :seriescolor, PLOTLY_DEFAULT)
    save_fig = get(kwargs, :save, nothing)
    unit = get(kwargs, :y_label, nothing)
    y_label = isnothing(unit) ? "Generation per unit" : unit
    title = get(kwargs, :title, " ")
    p = plotly_dataframe_plots(
        p,
        variable,
        seriescolor,
        time_range,
        title,
        y_label;
        kwargs...,
    )
    return p
end

function plotly_dataframe_plots(
    variable::DataFrames.DataFrame,
    seriescolor::Array,
    time_range::Array,
    title::Union{String, Symbol},
    ylabel::String;
    kwargs...,
)
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    line_shape = get(kwargs, :stair, false) ? "hv" : "linear"
    traces = Plots.PlotlyJS.GenericTrace{Dict{Symbol, Any}}[]
    gens = collect(names(variable))
    seriescolor = set_seriescolor(seriescolor, gens)
    for gen in 1:length(gens)
        stackgroup = get(kwargs, :stack, false) ? "one" : "$gen"
        fillcolor = get(kwargs, :stack, false) ? seriescolor[gen] : "transparent"
        push!(
            traces,
            Plots.PlotlyJS.scatter(;
                name = gens[gen],
                x = time_range,
                y = convert(Matrix, variable)[:, gen],
                stackgroup = stackgroup,
                mode = "lines",
                line_shape = line_shape,
                line_color = seriescolor[gen],
                fillcolor = fillcolor,
                showlegend = true,
            ),
        )
    end
    p = Plots.PlotlyJS.plot(
        traces,
        Plots.PlotlyJS.Layout(title = "$title", yaxis_title = ylabel),
    )
    title = title == " " ? "Generation" : title
    if !isnothing(save_fig)
        format = get(kwargs, :format, "png")
        Plots.PlotlyJS.savefig(
            p,
            joinpath(save_fig, "$title.$format");
            width = 800,
            height = 450,
        )
    end
    return p
end

function plotly_dataframe_plots(
    plot::Any,
    variable::DataFrames.DataFrame,
    seriescolor::Array,
    time_range::Array,
    title::Union{String, Symbol},
    ylabel::String;
    kwargs...,
)
    plot_list = []
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    line_shape = get(kwargs, :stair, false) ? "hv" : "linear"
    traces = plot.plot.data
    plot_length = length(traces)
    existing_traces = ones(plot_length)
    gens = collect(names(variable))
    seriescolor = set_seriescolor(seriescolor, [existing_traces; gens])
    for gen in 1:length(gens)
        stackgroup = get(kwargs, :stack, false) ? "one" : "$gen"
        fillcolor =
            get(kwargs, :stack, false) ? seriescolor[gen + plot_length] : "transparent"
        traces = push!(
            traces,
            Plots.PlotlyJS.scatter(;
                name = gens[gen],
                x = time_range,
                y = convert(Matrix, variable)[:, gen],
                stackgroup = stackgroup,
                mode = "lines",
                line_shape = line_shape,
                line_color = seriescolor[gen + plot_length],
                fillcolor = fillcolor,
                showlegend = true,
            ),
        )
    end
    if title !== " "
        old_title = [title]
        haskey(plot.plot.layout, :title) && pushfirst!(old_title, plot.plot.layout[:title])
        update = Dict(:title => join(old_title, " & "))
        Plots.PlotlyJS.relayout!(plot.plot.layout, update)
    end
    p = Plots.PlotlyJS.plot(traces, plot.plot.layout)
    title = title == " " ? "Generation" : title
    if !isnothing(save_fig)
        format = get(kwargs, :format, "png")
        Plots.PlotlyJS.savefig(
            p,
            joinpath(save_fig, "$title.$format");
            width = 800,
            height = 450,
        )
    end
    return p
end
