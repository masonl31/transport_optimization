#************************************************************************#
# Light Robust Rolling Stock Scheduling
#************************************************************************#
module Light_RRSS
using Gurobi, JuMP
#************************************************************************
#************************************************************************
# DATA
include("RSdata.jl")

#************************************************************************
#************************************************************************
# Robust Rolling Stock Scheduling Model
Light_RRS_model = Model(Gurobi.Optimizer)
nrArcs = size(Arcs, 1);
customer_penalty = [0.75, 0.75, 0.75, 0.75, 0.75, 0.5, 0.5, 0.5, 0.5, 0.5];
segment_penalty = 120;
best_sol = 80;

###################
# Define decision variables
###################
#the amount of train units per arc and per train unit type
@variable(Light_RRS_model, x[1:rsNrTypes, 1:nrArcs] >=0, Int)
@variable(Light_RRS_model, z[1:rsNrTypes, 1:nrArcs, 4:13] >=0, Int)
@variable(Light_RRS_model, d[1:nrArcs, 1:5], Bin)

###################
# Objective: minimizing costs by summing costs of overnight arcs (3 column is 1)
###################
# Objective 4a
# @objective(Light_RRS_model, Min, sum(rsCosts[i]*x[i,j] for i=1:rsNrTypes, j=1:nrArcs if Arcs[j,3]==1) +
#                                  sum(z[i,j,p]*customer_penalty[p-3] for p=4:13, i=1:rsNrTypes, j=1:nrArcs if Arcs[j,3]==2))

# Objective 4b
@objective(Light_RRS_model, Min, sum(segment_penalty*d[j,p] for p=1:5, j=1:nrArcs if Arcs[j,3]==2) +
                                 sum(rsCosts[i]*x[i,j] for i=1:rsNrTypes, j=1:nrArcs if Arcs[j,3]==1))

# Objective 4a + 4b
# @objective(Light_RRS_model, Min, sum(segment_penalty*d[j,p] for p=1:5, j=1:nrArcs if Arcs[j,3]==2) + sum(rsCosts[i]*x[i,j] for i=1:rsNrTypes, j=1:nrArcs if Arcs[j,3]==1)
#                                  + sum(z[i,j,p]*customer_penalty[p-3] for i=1:rsNrTypes, p=4:13, j=1:nrArcs if Arcs[j,3]==2))

#######################
#constraints
#######################
#flow conservation: train units entering node must be equal to train units leaving
@constraint(Light_RRS_model, FlowCons[i=1:rsNrTypes, j=1:nrNodes], sum(x[i,k] for k=1:nrArcs if Arcs[k,1] == j) - sum(x[i,k] for k=1:nrArcs if Arcs[k,2] == j) == 0)

for j=1:nrArcs
    if(Arcs[j,3]==2)
        @constraint(Light_RRS_model, sum(rsUnits[i]*x[i,j] for i=1:rsNrTypes) <= maxCompLength)
    end
end

#light robust for each type
@constraint(Light_RRS_model, [k=1:nrArcs, p=4:8], sum(rsCapFC[i]*x[i,k] + z[i,k,p] for i=1:rsNrTypes if Arcs[i,3] == 2) >= Arcs[k,p])
@constraint(Light_RRS_model, [k=1:nrArcs, p=9:13], sum(rsCapSC[i]*x[i,k] + z[i,k,p] for i=1:rsNrTypes if Arcs[i,3] == 2) >= Arcs[k,p])

# budget contraint
@constraint(Light_RRS_model, sum(rsCosts[i]*x[i,j] for i=1:rsNrTypes, j=1:nrArcs if Arcs[j,3]==1) <= 1.15*best_sol)

# penalty for segment shortage constraint
for j=1:nrArcs
    if(Arcs[j,3] == 2)
        for p=1:5
            @constraint(Light_RRS_model, [j=1:nrArcs], sum(z[i,j,p+3]/1000 + z[i,j,p+8]/1000 for i=1:rsNrTypes) <= d[j,p])
        end
    end
end

# solve
optimize!(Light_RRS_model)

x_values = value.(x);
z_values = value.(z)
d_values = value.(d)
obj_val = objective_value(Light_RRS_model)
# println(d_values)

println()

println("Objective value: \n", obj_val)
println()

println("Required stock: \n")
println("Type III: ", sum(x_values[1,j] for j=1:nrArcs if Arcs[j,3] == 1))
println("Type IV: ", sum(x_values[2,j] for j=1:nrArcs if Arcs[j,3] == 1))
println("Total carriages Type III: ", sum(x_values[1,j]*rsUnits[1] for j=1:nrArcs if Arcs[j,3] == 1))
println("Total carriages Type IV: ", sum(x_values[2,j]*rsUnits[2] for j=1:nrArcs if Arcs[j,3] == 1))
println()

println("Overnight arcs: \n")
for j=1:nrArcs
    if(Arcs[j,3] == 1)
        println("Overnigth arc: ", Arcs[j,:], "Num. Units(II and IV): ", x_values[:,j])
    end
end

println()
println("Execution time: ", solve_time(Light_RRS_model))

# println()
#
# println("Riding arcs: \n")
# for j=1:nrArcs
#     if(Arcs[j,3] == 2)
#         println("Riding arc: ", Arcs[j,:], "Num. Units(II and IV): ", x_values[:,j])
#     end
# end

println()
for j=1:nrArcs
    if(Arcs[j,3] == 2)
        for p=1:5
            fcDemandSat = rsCapFC[1]*x_values[1,j] + rsCapFC[2]*x_values[2,j] - Arcs[j,p+3]
            scDemandSat = rsCapSC[1]*x_values[1,j] + rsCapSC[2]*x_values[2,j] - Arcs[j,p+8]
            if (fcDemandSat<0 || scDemandSat<0)
                println("Arc: ", Arcs[j,:], "\t x: ", x_values[:,j], "\t fcDemand diff: ", fcDemandSat, "\t scDemand diff: ", scDemandSat)
            end
        end
    end
end

end  # module Light_RRSS
