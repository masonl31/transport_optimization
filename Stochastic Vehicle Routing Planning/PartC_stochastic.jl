include("VRPTW_STT_Instance.jl")

module PartC_opti

using Gurobi
#using CPLEX
using JuMP

using ..VRPTW_STT_Instance
instance = VRPTW_STT_Instance.randInstance(8, 200, 0.5, 200, 2000, 1000, 2000, 4)

nn = instance.nn #number of customers + 1 (depot)
nScen = instance.nScen #number of scenarios
c = instance.c #transport cost
t = instance.tts #stochastic transport times
a = instance.a #early time window
b = instance.b #late time window
demand = instance.demand #demand at each customer
Q = instance.Q #vehicle capacity

M = 99999
alpha = [0.99 0.95 0.9 0.7 0.5 0.3 0.1]


PartC = Model(Gurobi.Optimizer)
set_time_limit_sec(PartC::Model, 600)

@variable(PartC, x[1:nn,1:nn], Bin) #equal to 1 if the arc is traversed
@variable(PartC, w[1:nn,1:nScen] >=0) #when service starts at node i
@variable(PartC, y[1:nn-1,1:nScen], Bin) #if y is 1, then customer i in scenario s must be visited on time
@variable(PartC, z[1:nn] >=0) #load on the vehicle upon leaving vertex i

@objective(PartC, Min, sum(c[i,j]*x[i,j] for i=1:nn, j=1:nn))

#flow constraints
@constraint(PartC, [i=1:nn-1], sum(x[i,j] for j=1:nn if i != j) == 1) #must leave every customer once
@constraint(PartC, [j=1:nn-1], sum(x[i,j] for i=1:nn if i != j) == 1) #must go to every customer once

#time constraints
@constraint(PartC, [i=1:nn, j=1:nn-1, s=1:nScen], w[i,s] + t[i,j,s] <= w[j,s] + (1 - x[i,j])*M) #time windows are satisfied
@constraint(PartC, [i=1:nn, s=1:nScen], a[i] <= w[i,s]) #service time must be above a
@constraint(PartC, [i=1:nn-1, s=1:nScen], w[i,s] <= b[i] + (1 - y[i,s])*M) #service time must be below b in at least alpha*s scenarios
@constraint(PartC, [i=1:nn-1], sum(y[i,s] for s=1:nScen) >= alpha[2]*nScen) #must be in the time window for alpha*scenario amount

#capacity constraints
@constraint(PartC, [i=1:nn, j=1:nn-1], z[i] + demand[j] + M*x[i,j] <= z[j] + M) #accounting for the load
@constraint(PartC, [i=1:nn-1], z[i] <= Q) #load at node i must always be less than the capacity

optimize!(PartC)

println()
println("Traversed arcs:")
for i=1:nn
    for j=1:nn
        if value.(x[i,j]) == 1
            println("from ", i, "to ", j, "   Travel time ", t[i,j,1])
        end
    end
end


end  # module PartC
