#************************************************************************#
# Strict Rolling Stock Scheduling
#************************************************************************#
module Strict_RRSS
using Gurobi, JuMP
#************************************************************************
#************************************************************************
# DATA
include("RSdata.jl")

#************************************************************************
#************************************************************************
# Rolling Stock  Scheduling Model
Strict_RRS_model = Model(Gurobi.Optimizer)
nrArcs = size(Arcs, 1);

###################
# Define decision variables
#the amount of train units per arc and per train unit type
@variable(Strict_RRS_model, x[1:rsNrTypes, 1:nrArcs] >=0, Int) # Flow per Arc and per RS type

###################
# Objective: minimizing costs by summing costs of overnight arcs (3 column is 1)
###################
@objective(Strict_RRS_model, Min, sum(rsCosts[i]*x[i,j] for i=1:rsNrTypes, j=1:nrArcs if Arcs[j,3]==1))

###################
# Constraints:
###################

# Flow conservation for each type of RS units (separate constraints per rs type): train units entering node must be equal to train units leaving
@constraint(Strict_RRS_model, FlowCons[i=1:rsNrTypes, j=1:nrNodes], sum(x[i,k] for k=1:nrArcs if Arcs[k,1] == j) - sum(x[i,k] for k=1:nrArcs if Arcs[k,2] == j) == 0)


for j=1:nrArcs
    if(Arcs[j,3] == 2)
        @constraint(Strict_RRS_model, sum(rsUnits[i]*x[i,j] for i=1:rsNrTypes) <= maxCompLength) # Maximum legth of train units on traintrip arcs
    end
end

#strict robust for each type
@constraint(Strict_RRS_model, [j=1:nrArcs,p=4:8], sum(rsCapFC[i]*x[i,j] for i=1:rsNrTypes if Arcs[i,3] == 2) >= Arcs[j,p])      # capacity contraint for FC
@constraint(Strict_RRS_model, [j=1:nrArcs,p=9:13], sum(rsCapSC[i]*x[i,j] for i=1:rsNrTypes if Arcs[i,3] == 2) >= Arcs[j,p])     # capacity contraint for SC

# solve
optimize!(Strict_RRS_model)

x_values = value.(x);
obj_val = objective_value(Strict_RRS_model)

#trains = DataFrame((JuMP.value.(x)))
#CSV.write(("Results.csv"), trains)

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
        println("Overnigth arc: ", Arcs[j,:], "\t Num. Units(II and IV): ", x_values[:,j])
    end
end

println()
println("Execution time: ", solve_time(Strict_RRS_model))

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
    if(Arcs[j,2] == 1)
        fcDemandSat = rsCapFC[1]*x_values[1,j] + rsCapFC[2]*x_values[2,j] - Arcs[j,4]
        scDemandSat = rsCapSC[1]*x_values[1,j] + rsCapSC[2]*x_values[2,j] - Arcs[j,5]
        if (fcDemandSat<0 || scDemandSat<0)
            println("Arc", Arcs[j,:], "\t x: ", x_values[:,j], "\t fcDemand diff: ", fcDemandSat, "\t scDemand diff: ", scDemandSat)
        end
    end
end

end  # module RSNorm
