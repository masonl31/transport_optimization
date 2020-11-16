module pricingproblem

using Gurobi
using JuMP

include("data.jl")

(V,V)=size(c)
M = 999

lambda = [0.0 5.0 10.0 1.0 5.6 5.8 5.2 4.2 2.6000000000000005 0.0]

#Model
PP = Model(Gurobi.Optimizer)

@variable(PP, x[1:V,1:V], Bin) #equal to 1 if the arc is traversed
#@variable(PP, y[1:V] >=0) #load on the vehicle upon leaving vertex i
@variable(PP, z[1:V] >=0) #time the vehicle leaves vertex i

@objective(PP, Min, sum((c[i,j]-lambda[i])*x[i,j] for i=1:V, j=1:V))

#@constraint(PP, [k=2:V-1], sum(x[i,k] for i=1:V if i != k) == sum(x[k,j] for j=1:V if j != k)) #flow conservation
@constraint(PP, [k=2:V-1], sum(x[i,k] for i=1:V) == sum(x[k,j] for j=1:V)) #flow conservation
@constraint(PP, sum(x[1,j] for j=1:V) == 1) #vehicle must leave the depot once
@constraint(PP, sum(x[i,10] for i=1:V) == 1) #vehicle must return to the depot once
@constraint(PP, con2, sum(x[i,i] for i=1:V) == 0)
#@constraint(PP, sum(x[10,i] for i=1:V) == 0)
#@constraint(PP, sum(x[i,1] for i=1:V) == 0)

#@constraint(PP, [i=1:V, j=1:8], y[i] + q[j] + M*x[i,j+1] <= y[j+1] + M) #accounting for the load
#@constraint(PP, [i=1:V], y[i] <= Q)

@constraint(PP, con, sum(x[i,j]*q1[i] for i=1:V, j=1:V) <= Q)


@constraint(PP, [i=1:V], z[i] <= l[i]) #time vehicle leaves vertex i must be before or at the latest time
@constraint(PP,  [i=1:V, j=1:V], z[i] + t[i,j] + M*x[i,j] <= z[j] + M)

optimize!(PP)

println()
println("Traversed arcs:")
for a=1:V
    for b=1:V
        if(value.(x[a,b]) == 1)
            println("From:", a-1, " To:", b-1)
        end
    end
end

#println(value.(y))
#println(value.(z))

println("Cost of the route: ",value.(sum(x[i,j]*c[i,j] for i=1:V, j=1:V)))

end  # module pricingproblem
