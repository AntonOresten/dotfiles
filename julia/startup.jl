using Pkg

module UsingBang
# runs once per session, so interpret rather than compile it. This is what
# `Base.Experimental.@compiler_options compile=min infer=false` expands to, minus the
# ~30 ms that compiling that macro would add to startup
@eval $(Expr(:meta, :compile, 3))
@eval $(Expr(:meta, :infer, 0))
using Pkg
export @using!!

# Install what is missing in one `Pkg.add` and precompile what is stale in one `Pkg.precompile`,
# both with the global env active. `using` alone precompiles one package tree at a time, and
# when another project is active, the deps of a package from the global env one by one.
function prepare(names::Vector{String})
    # plain loops: closures would make Base compile `filter`/`map` specializations for them
    missing = String[]
    for name in names
        # also catches manifest entries whose source was never downloaded
        Base.find_package(name) === nothing && push!(missing, name)
    end
    prev = Base.ACTIVE_PROJECT[]
    Base.ACTIVE_PROJECT[] = Base.load_path_expand("@v#.#")
    try
        if !isempty(missing)
            @info "Installing $(join(missing, ", ")) to global environment..."
            Pkg.add(missing)
        end
        found, stale = String[], false
        for name in names
            id = Base.identify_package(name)
            (id === nothing || Base.locate_package(id) === nothing) && continue
            push!(found, name)
            stale |= !Base.isprecompiled(id)
        end
        # failures are left for `using` to report
        stale && try Pkg.precompile(found) catch end
    catch e
        @error "Failed to install $(join(missing, ", "))" exception=(e, catch_backtrace())
    finally
        Base.ACTIVE_PROJECT[] = prev
    end
end

# `@using!! A B` or `@using!! A, B`. Pass everything in one call: the batching is the point
macro using!!(args...)
    names = String[]
    loads = Expr(:block)
    for arg in args, pkg in (Meta.isexpr(arg, :tuple) ? arg.args : (arg,))
        push!(names, string(pkg))
        # one at a time, so a package that fails to load doesn't take the rest down with it
        push!(loads.args, :(try
            using $pkg
        catch e
            @error $("Failed to load $pkg") exception=(e, catch_backtrace())
        end))
    end
    :($prepare($names); $loads; nothing)
end
end
using .UsingBang

# Revise: package/code updates through file-watching
# PrettyChairmarks: `{@b,@be,@bs} <expr>` for fast benchmarking
# LocalRegistry: `@register` below
@using!! Revise PrettyChairmarks LocalRegistry

macro bc(f, keywords...)
    :(@b (CUDA.@sync $f) $(keywords...))
end

macro bec(f, keywords...)
    :(@be (CUDA.@sync $f) $(keywords...))
end

macro bsc(f, keywords...)
    :(@bs (CUDA.@sync $f) $(keywords...))
end

if VERSION.minor < 13
    # syntax highlighting, bracket completion
    @using!! OhMyREPL

    # colorschemes at:
    # https://kristofferc.github.io/OhMyREPL.jl/stable/features/syntax_highlighting/
    colorscheme!(get(ENV, "OHMYREPL_COLORSCHEME", "GitHubDark"))

    # fix bug where `[` + `]` results in `[]]`
    @async begin
        while !isdefined(Base, :active_repl) sleep(0.1) end
        OhMyREPL.Prompt.insert_keybindings()
    end
end

# if another registry is installed, make an attempt to register current project
macro register(args...)
    :(Pkg.Registry.update(); LocalRegistry.register($(esc(args...)), registry=get(ENV, "LOCAL_REGISTRY", "MurrellGroupRegistry")))
end

let local_file = joinpath(@__DIR__, "startup_local.jl")
    isfile(local_file) && include(local_file)
end
