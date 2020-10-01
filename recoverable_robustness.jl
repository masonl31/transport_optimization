module Q6

using Gurobi, JuMP

include("RSdata.jl")

(A,P) = size(Arcs);
S=5;

#Model
assignment1 = Model(Gurobi.Optimizer)

#the amount of train units per arc and per train unit type (stage 1)
@variable(assignment1, x[1:rsNrTypes] >=0, Int)

#stage 2 - scheduling and making sure everything is feasible and demand is fullfilled
@variable(assignment1, y[1:A,1:rsNrTypes,1:S] >=0, Int)


@objective(assignment1, Min, sum(rsCosts[j]*x[j] for j in 1:rsNrTypes))

#######################
#constraints

#flow conservation: train units entering node must be equal to train units leaving
@constraint(assignment1, [n=1:nrNodes, j=1:rsNrTypes, s=1:S], sum(y[i,j,s] for i in 1:A if Arcs[i,2]==n) - sum(y[i,j,s] for i in 1:A if Arcs[i,1]==n) == 0)


#trains can only be a certain length long
for i=1:A
    if(Arcs[i,3] == 2)
        for s=1:S
            @constraint(assignment1, sum(rsUnits[j]*y[i,j,s] for j in 1:rsNrTypes) <= maxCompLength)
        end
    end
end


#strict robust for each type
@constraint(assignment1, [i=1:A,s=1:5], sum(rsCapFC[j]*y[i,j,s] for j in 1:rsNrTypes if Arcs[i,3] == 2) >= Arcs[i,s+3]) #first class demand is satisfied for all demands
@constraint(assignment1, [i=1:A,s=1:5], sum(rsCapSC[j]*y[i,j,s] for j in 1:rsNrTypes if Arcs[i,3] == 2) >= Arcs[i,s+8]) #second class demand is satisfied for all demands

#relating stage 1 and stage 2
@constraint(assignment1, [j=1:rsNrTypes, s=1:S], sum(y[i,j,s] for i in 1:A if Arcs[i,3] == 1) <= x[j])

# solve
optimize!(assignment1)

valuesX=value.(x)
objVal = objective_value(assignment1)

println()

println("Objective value: \n", objVal)
println()

println("Required stock: \n")
println("Type III: ", valuesX[1])
println("Type IV: ", valuesX[2])
println("Total carriages Type III: ", valuesX[1]*rsUnits[1])
println("Total carriages Type IV: ", valuesX[2]*rsUnits[2])
println()

println("Overnight arcs: \n")
for j=1:A
    if(Arcs[j,3] == 1)
        println("Overnigth arc: ", Arcs[j,:], "Num. Units(III and IV): ", valuesX[:])
    end
end

println()
println("Execution time: ", solve_time(assignment1))

# println()
#
# println("Riding arcs: \n")
# for j=1:nrArcs
#     if(Arcs[j,3] == 2)
#         println("Riding arc: ", Arcs[j,:], "Num. Units(II and IV): ", x_values[:,j])
#     end
# end

println()
for j=1:A
    if(Arcs[j,3] == 2)
        for p=1:5
            fcDemandSat = rsCapFC[1]*valuesX[1] + rsCapFC[2]*valuesX[2] - Arcs[j,p+3]
            scDemandSat = rsCapSC[1]*valuesX[1] + rsCapSC[2]*valuesX[2] - Arcs[j,p+8]
            if (fcDemandSat<0 || scDemandSat<0)
                println("Arc: ", Arcs[j,:], "\t x: ", valuesX[:,j], "\t fcDemand diff: ", fcDemandSat, "\t scDemand diff: ", scDemandSat)
            end
        end
    end
end

end  # module Q6
