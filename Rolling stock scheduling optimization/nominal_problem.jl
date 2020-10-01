#************************************************************************#
# Rolling Stock Scheduling
#************************************************************************#
module RSNorm
using Gurobi, JuMP
#************************************************************************
#************************************************************************
# DATA
include("RRSdataNom.jl")

#************************************************************************
#************************************************************************
# Rolling Stock  Scheduling Model
RRS_model = Model(Gurobi.Optimizer)
nrArcs = size(Arcs, 1);

###################
# Define decision variables
@variable(RRS_model, x[1:rsNrTypes, 1:nrArcs], lower_bound=0, Int)  # Flow per Arc and per RS type
@variable(RRS_model, z[1:rsNrTypes, 1:nrArcs], lower_bound=0, Int) # indicate how many passengers without seat when traveling an arc A^r

###################
# Objective: minimizing costs by summing costs of overnight arcs (3 column is 1)
###################
@objective(RRS_model, Min, sum(rsCosts[i]*x[i,j] for i=1:rsNrTypes, j=1:nrArcs if Arcs[j,3]==1) + sum(z[i,j] for i=1:rsNrTypes, j=1:nrArcs if Arcs[j,3]==2))


###################
# Constraints:
###################

# Flow conservation for each type of RS units (separate constraints per rs type)
@constraint(RRS_model, cFlowCons[i=1:rsNrTypes, j=1:nrNodes], sum(x[i,k] for k=1:nrArcs if Arcs[k,1] == j) - sum(x[i,k] for k=1:nrArcs if Arcs[k,2] == j) == 0)

for j=1:nrArcs
    if(Arcs[j,3]==2)
        # Capacity contraint
        @constraint(RRS_model, sum(x[i,j]*rsUnits[i] for i=1:rsNrTypes) <= maxCompLength) # Maximum legth of train units on traintrip arcs
        # First class demand constraint
        @constraint(RRS_model, sum(x[i,j]*rsCapFC[i] + z[i,j] for i=1:rsNrTypes) >= Arcs[j,4]) # satify demand in first class
        # Second class demand constraint
        @constraint(RRS_model, sum(x[i,j]*rsCapSC[i] + z[i,j] for i=1:rsNrTypes) >= Arcs[j,5]) # satify demand in second class
    end
end

optimize!(RRS_model)

x_values = value.(x);
z_values = value.(z);
obj_val = objective_value(RRS_model)
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
        println("Overnigth arc: ", Arcs[j,:], "\t Num. Units(II and IV): ", x_values[:,j])
    end
end

println()
println("Execution time: ", solve_time(RRS_model))

# println()
#
# println("Riding arcs: \n")
# for j=1:nrArcs
#     if(Arcs[j,3] == 2)
#         println("Riding arc: ", Arcs[j,:], "Num. Units(II and IV): ", x_values[:,j])
#     end
# end

for j=1:nrArcs
    if(Arcs[j,2] == 1)
        fcDemandSat = rsCapFC[1]*x_values[1,j] + rsCapFC[2]*x_values[2,j] - Arcs[j,4]
        scDemandSat = rsCapSC[1]*x_values[1,j] + rsCapSC[2]*x_values[2,j] - Arcs[j,5]
        if (fcDemandSat<0 || scDemandSat<0)
            println("Arc", Arcs[j,:], "x: ", x_values[:,j], "fcDemand diff: ", fcDemandSat, "scDemand diff: ", scDemandSat)
        end
    end
end

end
