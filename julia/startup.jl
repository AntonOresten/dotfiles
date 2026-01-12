using Pkg

macro try_using(pkgs...)
    expr = :()
    for pkg in pkgs
        pkg_str = string(pkg)
        push!(expr.args, :(try
            using $pkg
        catch
            @info "Failed to load $($pkg_str). Attempting to install..."
            Pkg.add($pkg_str)
            using $pkg
        end))
    end
    :($expr; nothing)
end

# package/code updates through file-watching
@try_using Revise

# `{@b,@be,@bs} <expr>` for fast benchmarking
@try_using PrettyChairmarks

if VERSION.minor < 13
    # syntax highlighting, bracket completion
    @try_using OhMyREPL

    # colorschemes at:
    # https://kristofferc.github.io/OhMyREPL.jl/stable/features/syntax_highlighting/
    colorscheme!(get(ENV, "OHMYREPL_COLORSCHEME", "GitHubDark"))

    # fix bug where `[` + `]` results in `[]]`
    @async begin
        while !isdefined(Base, :active_repl) sleep(0.1) end
        OhMyREPL.Prompt.insert_keybindings()
    end
end

@try_using LocalRegistry
# if another registry is installed, make an attempt to register current project
macro register(args...)
    :(Pkg.Registry.update(); LocalRegistry.register($(esc(args...)), registry=get(ENV, "LOCAL_REGISTRY", "MurrellGroupRegistry")))
end

let local_file = joinpath(@__DIR__, "startup_local.jl")
    isfile(local_file) && include(local_file)
end
