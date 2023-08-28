# DynamicScope.jl

Code like it's the '80s! Combine the power of Julia with the scoping rules of amazing languages like Bash and Elisp.

The main use for this library is compiling dynamically scoped languages to Julia.
So the focus is to be efficient and simple rather than provide a user-friendly API.

```julia
@dyn function inner()
    @requires c
    return c
end

@dyn function outer(a=2a)
    @requires a
    @provides c
    c = 10+a
    return @inner()
end

a = 5
@outer() # 20
@outer(a=1) # 11
```