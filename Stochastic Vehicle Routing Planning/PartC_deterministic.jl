include("VRPTW_STT_Instance.jl")

module PartC_det_opti

using Gurobi
using JuMP

using ..VRPTW_STT_Instance
instance = VRPTW_STT_Instance.randInstance(8, 200, 0.5, 200, 2000, 1000, 2000, 4)

nn = instance.nn #number of customers + 1 (depot)
c = instance.c #transport cost
t = instance.tt #transport times
a = instance.a #early time window
b = instance.b #late time window
demand = instance.demand #demand at each customer
Q = instance.Q #vehicle capacity

M = 99999


PartC_det = Model(Gurobi.Optimizer)

@variable(PartC_det, x[1:nn,1:nn], Bin) #equal to 1 if the arc is traversed
@variable(PartC_det, w[1:nn] >=0) #when service starts at node i
@variable(PartC_det, y[1:nn-1], Bin) #if y is 1, then customer i in scenario s must be visited
@variable(PartC_det, z[1:nn] >=0) #load on the vehicle upon leaving vertex i

@objective(PartC_det, Min, sum(c[i,j]*x[i,j] for i=1:nn, j=1:nn))

#flow constraints
@constraint(PartC_det, [i=1:nn-1], sum(x[i,j] for j=1:nn if i != j) == 1) #must leave every customer once
@constraint(PartC_det, [j=1:nn-1], sum(x[i,j] for i=1:nn if i != j) == 1) #must go to every customer once

#time constraints
@constraint(PartC_det, [i=1:nn, j=1:nn-1], w[i] + t[i,j] <= w[j] + (1 - x[i,j])*M) #time windows are satisfied
@constraint(PartC_det, [i=1:nn], a[i] <= w[i]) #service time must be above a
@constraint(PartC_det, [i=1:nn-1], w[i] <= b[i]) #service time must be below b in at least alpha*s scenarios

#capacity constraints
@constraint(PartC_det, [i=1:nn, j=1:nn-1], z[i] + demand[j] + M*x[i,j] <= z[j] + M) #accounting for the load
@constraint(PartC_det, [i=1:nn-1], z[i] <= Q) #load at node i must always be less than the capacity

optimize!(PartC_det)

println()
println("Traversed arcs:")
for i=1:nn
    for j=1:nn
        if value.(x[i,j]) == 1
            println("from ", i, "to ", j, "   Travel time ", t[i,j])
        end
    end
end


end  # module PartC_det
