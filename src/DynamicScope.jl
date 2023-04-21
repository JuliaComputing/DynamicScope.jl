module DynamicScope

# source: https://rosettacode.org/wiki/Topological_sort#Julia
function toposort(data::Dict{T,Set{T}}) where T
    data = copy(data)
    for (k, v) in data
        delete!(v, k)
    end
    extraitems = setdiff(reduce(∪, values(data); init=Set{T}()), keys(data))
    for item in extraitems
        data[item] = Set{T}()
    end
    rst = Vector{T}()
    while true
        ordered = Set(item for (item, dep) in data if isempty(dep))
        if isempty(ordered) break end
        append!(rst, ordered)
        data = Dict{T,Set{T}}(item => setdiff(dep, ordered) for (item, dep) in data if item ∉ ordered)
    end
    isempty(data) || error("a cyclic dependency exists amongst $(keys(data))")
    return rst
end

function exprsymbols(expr)
    expr isa Symbol && return Set{Symbol}([expr])
    expr isa Expr || return Set{Symbol}()
    return Set{Symbol}(reduce(∪, (exprsymbols(a) for a in expr.args); init=Set{Symbol}()))
end

function exprtreemap(f, expr)
    expr = f(expr)
    expr isa Expr || return expr
    Expr(expr.head, (exprtreemap(f, a) for a in expr.args)...)
end

iskwcall(expr) = length(expr.args) >= 2 && expr.args[2] isa Expr && expr.args[2].head == :parameters

"""
    @requires args...

Declare variables that are expected from the calling scope
"""
macro requires(args...) end

"""
    @provides args...

Declare variables that are provided to dynamic calls
"""
macro provides(args...) end


"""
    @dyn function name(...) ... end

Generates a macro `@name` that resolves default arguments and declared `@requires` in the calling scope.

Local variables that are provided by this function to inner dynamic functions
should be declared with `@provides` to stop them from bubbling up.
Function parameters are provided automatically.

The order of `@requires` and `@provides` matters, so that a function can both provide and declare a variable.
For example in the case of `a=a+2`.
The exception is that the first `@requires` overrides variables provided by function arguments.
For example in the case of `function foo(a=a+2); @requires a`
"""
macro dyn(fn)
    fn isa Expr && fn.head == :function || error("@dyn argument is not a function definition")
    requires = Set{Symbol}()
    provides = Set{Symbol}()
    kwargs = Dict{Symbol, Any}()
    # collect and strip all the default arguments (put in caller context)
    # collect all the argument names (provided variables)
    fname = fn.args[1].args[1]
    fn.args[1] = exprtreemap(fn.args[1]) do expr
        if expr isa Expr && expr.head == :kw
            kwargs[expr.args[1]] = expr.args[2]
            expr = expr.args[1]
        end
        if expr isa Symbol && expr != fname
            push!(provides, expr)
        end
        return expr
    end
    # keep track of the argument names, so we don't duplicate them
    argprovides = copy(provides)
    first = true
    # collect @requires and @provides symbol names
    fn.args[2] = exprtreemap(fn.args[2]) do expr
        expr isa Expr || return expr
        # expand other macros to collect their @requires
        if expr.head == :macrocall && expr.args[1] ∉ (Symbol("@requires"), Symbol("@provides"))
            expr = macroexpand(__module__, expr; recursive=false)
        end
        if expr.head == :macrocall && expr.args[1] == Symbol("@requires")
            nr = expr.args[3:end]
            if first
                # the first requires ignores provides from the arguments
                union!(requires, nr)
            else
                # don't require already provided variables
                union!(requires, setdiff(nr, provides))
            end
            first = false
        end
        if expr.head == :macrocall && expr.args[1] == Symbol("@provides")
            union!(provides, expr.args[3:end])
            first = false
        end
        return expr
    end
    call = fn.args[1]
    # add required variables (that aren't already arguments) as extra function arguments
    append!(call.args, setdiff(requires, argprovides))
    pargs = iskwcall(call) ? call.args[3:end] : call.args[2:end]
    esc(quote
        $fn
        macro $fname(args...)
            # take default expressions
            bindings = copy($kwargs)
            # and override with macro arguments
            for (i, expr) in enumerate(args)
                if expr isa Expr && expr.head == :(=)
                    bindings[expr.args[1]] = expr.args[2]
                else
                    bindings[$pargs[i]] = expr
                end
            end
            # topologically sort the bindings
            deps = Dict{Symbol, Set{Symbol}}()
            for (id, expr) in bindings
                deps[id] = $exprsymbols(expr)
            end
            letnames = $toposort(deps)
            # generate let binding and function call
            leteqs = [:($id = $(bindings[id])) for id in letnames if haskey(bindings, id)]
            # the function arguments that were not bound by the let are implicit requires
            impl_req = setdiff($argprovides, keys(bindings))
            esc(quote
                @requires $($requires...) $(impl_req...)
                let $(leteqs...)
                    $$(QuoteNode(call))
                end
            end)
        end
    end)
end

export @dyn, @requires, @provides

end # module DynamicScope
