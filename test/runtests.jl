using Test, DynamicScope

@dyn function simple()
    @requires a
    return a
end

@dyn function nestedvar()
    @requires b
    (@simple(), b)
end

@dyn function args(a, c=3; b, d=4)
    return a, b, c, d
end

@dyn function argdeps(a, b=a*10)
    return a, b
end

@dyn function inner()
    @requires c
    return c
end

@dyn function outer()
    @provides c
    c = 12
    return @inner()
end

@dyn function selfouter()
    @requires c
    @provides c
    c = c*2
    return @inner()
end

@dyn function defaultouter(c=14)
    return @inner()
end

@dyn function selfarg(c=c*2)
    return @inner()
end

a = 1
b = 2
@test @simple() == 1
@test @nestedvar() == (1, 2)
@test @args() == (1, 2, 3, 4)
@test @args(8, b=10) == (8, 10, 3, 4)
@test @args(c=7, d=9) == (1, 2, 7, 9)
@test @argdeps() == (1, 10)
@test @argdeps(a=2) == (2, 20)
@test @argdeps(a=2, b=3) == (2, 3)
@test @outer() == 12
@test @selfouter(c=4) == 8
@test @defaultouter() == 14
@test @selfarg(c=4) == 4
let c=8
    @test @selfarg() == 16
end