local IO = terralib.includec("stdio.h")

local P = opt.ProblemSpec()

local W = opt.Dim("W", 0)
local H = opt.Dim("H", 1)

P:Image("X",float,W,H,0)
P:Image("A",float,W,H,1)
P:Adjacency("iAdj", {W,H}, {W,H}, 0)
P:EdgeValues("w", float, "iAdj", 0)

local C = terralib.includecstring [[
#include <math.h>
#include <stdio.h>
]]

local w_fit = 0.1
local w_reg = 1.0

local terra laplacian(i : uint32, j : uint32, X : P:TypeOf("X"), iAdj : P:TypeOf("iAdj"), w : P:TypeOf("w"))

	var x = X(i, j)

	var sum = 0.0
	var sumWeights = 0.0
	for a in iAdj:neighbors(i, j) do
	    --C.printf("%d %d -> %d %d\n",int(i),int(j),int(a.x),int(a.y))
		sum = sum + X(a.x, a.y) * w(a)
		sumWeights = sumWeights + w(a)
	end

	--iAdj:count(i, j)
	var v = sumWeights * x - sum
	return v
end

local terra cost(i : uint32, j : uint32, self : P:ParameterType())
	var x = self.X(i, j)
	var a = self.A(i, j)

	var v = laplacian(i, j, self.X, self.iAdj, self.w)
	var laplacianCost = v * v

	var v2 = x - a
	var reconstructionCost = v2 * v2

	return (float)(w_reg*laplacianCost + w_fit*reconstructionCost)
end

local terra gradient(i : uint32, j : uint32, self : P:ParameterType())
	var x = self.X(i, j)
	var a = self.A(i, j)

	var reconstructionGradient = 2 * (x - a)
	
	var sum = 0.0
	var sumWeights = 0.0
	for a in self.iAdj:neighbors(i, j) do
	    sum = sum + laplacian(a.x, a.y, self.X, self.iAdj, self.w) * self.w(a)
		sumWeights = sumWeights + self.w(a)
	end
	
	var laplacianGradient = 2.0 * (sumWeights * laplacian(i, j, self.X, self.iAdj, self.w) - sum)
	
	return w_reg*laplacianGradient + w_fit*reconstructionGradient
end

P:Function("cost", {W,H}, {0,0}, cost)
P:Function("gradient", {W,H}, {0,0}, gradient)
return P