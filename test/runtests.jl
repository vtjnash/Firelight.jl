using Firelight
using Test

@testset "escapehtml" begin
    escapehtml = Firelight.escapehtml
    @test sprint(escapehtml, codeunits("abc")) == "abc"
    @test sprint(escapehtml, codeunits("α&<>\"';β"), false) == "α&amp;&lt;&gt;\"';β"
    @test sprint(escapehtml, codeunits("α&<>\"';β"), true) == "α&amp;&lt;&gt;&quot;&apos;;β"
    @test sprint(escapehtml, codeunits("'\0\1\x0f\x10\x1f\x20'")) == "&apos;&#0;&#1;&#15;&#16;&#31; &apos;"
end

@testset "richprint" begin
    include("richprint.jl")
end

@testset "richdump" begin
    include("richdump.jl")
end
