function poordump(@nospecialize(o), limit::Bool=false) # richdump minus annotations
    dom = Vector{Firelight.Node}()
    io = IOBuffer()
    Firelight.richdump(IOContext(io, :limit => limit), dom, o)
    @test !isempty(dom)
    return String(take!(io)), dom
end

@test poordump("Hello\nWorld")[1] == "String \"Hello\\nWorld\""
@test poordump(Core.svec())[1] == "empty SimpleVector"
@test poordump(Core.svec(1, "Hello\nWorld", []))[1] ==
    "SimpleVector\n    1: 1\n    2: \"Hello\\nWorld\"\n    3: Any[]"
@test poordump(:hello)[1] == "Symbol hello"
@test poordump(Firelight)[1] == "Module Firelight"
@test poordump(Main)[1] == "Module Main"
@test poordump(Core.Compiler)[1] == "Module Core.Compiler"
@test poordump(C_NULL)[1] == "Ptr{Nothing} @0x0000000000000000"
@test poordump(1)[1] == "Int64    1"
@test poordump(0x1)[1] == "UInt8    0x01"
@test poordump(3 + 4im)[1] == "Complex{Int64}\n    re: 3\n    im: 4"
@test poordump(fill(0x1, 100))[1] ==
    "Array{UInt8}((100,)) UInt8[0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01]"
@test poordump(fill(0x1, 100), true)[1] ==
    "Array{UInt8}((100,)) UInt8[0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01  …  0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01]"
@test poordump(fill(0x1, 5), true)[1] ==
    "Array{UInt8}((5,)) UInt8[0x01, 0x01, 0x01, 0x01, 0x01]"
@test poordump(fill("1", 100))[1] ==
    "Array{String}((100,))
    1: \"1\"\n    2: \"1\"\n    3: \"1\"\n    4: \"1\"\n    5: \"1\"\n    6: \"1\"\n    7: \"1\"\n    8: \"1\"\n    9: \"1\"\n    10: \"1\"
    11: \"1\"\n    12: \"1\"\n    13: \"1\"\n    14: \"1\"\n    15: \"1\"\n    16: \"1\"\n    17: \"1\"\n    18: \"1\"\n    19: \"1\"\n    20: \"1\"
    21: \"1\"\n    22: \"1\"\n    23: \"1\"\n    24: \"1\"\n    25: \"1\"\n    26: \"1\"\n    27: \"1\"\n    28: \"1\"\n    29: \"1\"\n    30: \"1\"
    31: \"1\"\n    32: \"1\"\n    33: \"1\"\n    34: \"1\"\n    35: \"1\"\n    36: \"1\"\n    37: \"1\"\n    38: \"1\"\n    39: \"1\"\n    40: \"1\"
    41: \"1\"\n    42: \"1\"\n    43: \"1\"\n    44: \"1\"\n    45: \"1\"\n    46: \"1\"\n    47: \"1\"\n    48: \"1\"\n    49: \"1\"\n    50: \"1\"
    51: \"1\"\n    52: \"1\"\n    53: \"1\"\n    54: \"1\"\n    55: \"1\"\n    56: \"1\"\n    57: \"1\"\n    58: \"1\"\n    59: \"1\"\n    60: \"1\"
    61: \"1\"\n    62: \"1\"\n    63: \"1\"\n    64: \"1\"\n    65: \"1\"\n    66: \"1\"\n    67: \"1\"\n    68: \"1\"\n    69: \"1\"\n    70: \"1\"
    71: \"1\"\n    72: \"1\"\n    73: \"1\"\n    74: \"1\"\n    75: \"1\"\n    76: \"1\"\n    77: \"1\"\n    78: \"1\"\n    79: \"1\"\n    80: \"1\"
    81: \"1\"\n    82: \"1\"\n    83: \"1\"\n    84: \"1\"\n    85: \"1\"\n    86: \"1\"\n    87: \"1\"\n    88: \"1\"\n    89: \"1\"\n    90: \"1\"
    91: \"1\"\n    92: \"1\"\n    93: \"1\"\n    94: \"1\"\n    95: \"1\"\n    96: \"1\"\n    97: \"1\"\n    98: \"1\"\n    99: \"1\"\n    100: \"1\""
@test poordump(fill("1", 100), true)[1] ==
    "Array{String}((100,))\n    1: \"1\"\n    2: \"1\"\n    3: \"1\"\n    4: \"1\"\n    5: \"1\"\n  ...\n    96: \"1\"\n    97: \"1\"\n    98: \"1\"\n    99: \"1\"\n    100: \"1\""
@test poordump(fill("1", 5), true)[1] ==
    "Array{String}((5,))\n    1: \"1\"\n    2: \"1\"\n    3: \"1\"\n    4: \"1\"\n    5: \"1\""
@test poordump(Union{Float32, Float64})[1] ==  "Union{Float32, Float64}"
@test poordump(Float32)[1] == "Float32 <: AbstractFloat"
@test poordump(Complex)[1] == "UnionAll where var: {\n    T<:Real\n}\nbody: Complex{T} <: Number\n    re::T\n    im::T"
@test poordump(ComplexF32)[1] == "Complex{Float32} <: Number\n    re::Float32\n    im::Float32"
struct LinearAlgebra_Diagonal{T, V<:AbstractVector{T}} <: AbstractMatrix{T}
    diag::V
end
let LinearAlgebra_Diagonal_name = "LinearAlgebra_Diagonal"
    @test poordump(LinearAlgebra_Diagonal)[1] ==
        "UnionAll where var: {\n    T,\n    V<:AbstractArray{T,1}\n}\nbody: $LinearAlgebra_Diagonal_name{T,V} <: AbstractArray{T,2}\n    diag::V"
    @test poordump(LinearAlgebra_Diagonal.body.body)[1] ==
        "$LinearAlgebra_Diagonal{T,V<:AbstractArray{T,1}} <: AbstractArray{T,2}\n    diag::V"
end
@test poordump(Union{})[1] == "Core.TypeofBottom    Union{}"
@test poordump(typeof(Union{}))[1] == "Core.TypeofBottom <: Type{Union{}}"
@test poordump(Type{Union{}})[1] == "Type{Union{}} <: Any"
