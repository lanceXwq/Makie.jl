#=
Buffers are just normal plots, with the benefit of being setup correctly to
efficiently append + push new values to them
=#

function LinesegmentBuffer(
        scene::SceneLike, ::Type{Point{N}} = Point{2};
        color = RGBAf[], linewidth = Float32[],
        kw_args...
    ) where N
    linesegments!(
        scene, Point{N, Float32}[]; color = color,
        linewidth = linewidth, kw_args...
    )
end

function append!(lsb::LineSegments, positions::Vector{Point{N, Float32}}; color = :black, linewidth = 1.0) where N
    thickv = same_length_array(positions, linewidth, key"linewidth"())
    colorv = same_length_array(positions, color, key"color"())
    append!(lsb[1][], positions)
    append!(lsb[:color][], colorv)
    append!(lsb[:linewidth][], thickv)
    return
end

function push!(tb::LineSegments, positions::Point{N, Float32}; kw_args...) where N
    append!(tb, [positions]; kw_args...)
end

function start!(lsb::LineSegments)
    resize!(lsb[1][], 0)
    resize!(lsb[:color][], 0)
    resize!(lsb[:linewidth][], 0)
    return
end

function finish!(lsb::LineSegments)
    # update the signal!
    lsb[1][] = lsb[1][]
    lsb[:color][] = lsb[:color][]
    lsb[:linewidth][] = lsb[:linewidth][]
    return
end

function TextBuffer(
        scene::SceneLike, ::Type{Point{N}} = Point{2};
        rotation = [Quaternionf(0,0,0,1)],
        color = RGBAf[RGBAf(0,0,0,0)],
        fontsize = Float32[0],
        font = [defaultfont()],
        align = [Vec2f(0)],
        kw_args...
    ) where N
    text!(
        scene, tuple.(String[" "], [Point{N, Float32}(0)]);
        rotation = rotation,
        color = color,
        fontsize = fontsize,
        font = font,
        align = align,
        kw_args...
    )
end

function start!(tb::Makie.Text)
    for key in (1, :color, :rotation, :fontsize, :font, :align)
        empty!(tb[key][])
    end
    return
end

function finish!(tb::Makie.Text)
    # update the signal!
    # now update all callbacks
    # TODO this is a bit shaky, buuuuhut, in theory the whole lift(color, ...)
    # in basic_recipes annotations should depend on all signals here, so updating one should be enough
    if length(tb[1][]) != length(tb.fontsize[])
        error("Inconsistent buffer state for $(tb[1][])")
    end
    notify(tb[1])
    return
end

function push!(tb::Makie.Text, text::String, position::VecTypes{N}; kw_args...) where N
    append!(tb, [(String(text), Point{N, Float32}(position))]; kw_args...)
end

function append!(tb::Makie.Text, text::Vector{String}, positions::Vector{Point{N, Float32}}; kw_args...) where N
    text_positions = convert_arguments(Makie.Text, tuple.(text, positions))[1]
    append!(tb, text_positions; kw_args...)
    return
end

function append!(tb::Makie.Text, text_positions::Vector{Tuple{String, Point{N, Float32}}}; kw_args...) where N
    append!(tb[1][], text_positions)
    kw = Dict(kw_args)
    for key in (:color, :rotation, :fontsize, :font, :align)
        val = get(kw, key) do
            isempty(tb[key][]) && error("please provide default for $key")
            return last(tb[key][])
        end
        val_vec = if key === :font
            same_length_array(text_positions, to_font(tb.fonts, val))
        else
            same_length_array(text_positions, val, Key{key}())
        end
        append!(tb[key][], val_vec)
    end
    return
end
