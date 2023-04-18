# DynamicScope.jl

Code like it's the '80s! Combine the power of Julia with the scoping rules of amazing languages like Bash and Elisp.

```julia
@dyn function inner()
    @requires c
    return c
end

@dyn function outer(a=2a)
    @provides c
    c = 10+a
    return @inner()
end

a = 5
@outer() # 20
@outer(a=1) # 11
```