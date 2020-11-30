module PartB_cutting_plane

using Gurobi
#using CPLEX
using JuMP
using Distributions

include("data_CVRPSD.jl")

nn = n+2 # number of customers + 2 (leaving and entering depot)
K = 3    # number of vehicules to serve the customers
M = 99999

# PartB = Model(Gurobi.Optimizer)
# set_time_limit_sec(PartB::Model, 600)
#
# # define variables
# @variable(PartB, x[1:nn,1:nn,1:K], Bin) #equal to 1 if the arc is traversed by vehicule k
# @variable(PartB, w[1:nn,1:K] >=0) # indicates position of node i in the route of vehicule k
#
# @objective(PartB, Min, sum(c[i,j]*x[i,j,k] for k=1:K, i=1:nn, j=1:nn))
#
# # flow constraints
# @constraint(PartB, [i=2:nn-1], sum(x[i,j,k] for k=1:K, j=1:nn if i != j) == 1) # must leave every customer once
# @constraint(PartB, [l=2:nn-1, k=1:K], sum(x[i,l,k] for i=1:nn) == sum(x[l,j,k] for j=1:nn))
# @constraint(PartB, [k=1:K], sum(x[1,j,k] for j=1:nn-1) <= 1) # must leave the depot once for each vehicule
# @constraint(PartB, [k=1:K], sum(x[i,nn,k] for i=1:nn) <= 1) # must enter the depot once for each vehicule
#
#
# #  route position of custumers served constraint
# @constraint(PartB, [i=1:nn, j=1:nn, k=1:K], w[i,k] + 1 <= w[j,k] + (1 - x[i,j,k])*M)
#
# #capacity constraints
# @constraint(PartB, [k=1:K], sum(q_avg_dep[i]*x[i,j,k] for i=1:nn, j=1:nn) <= Q) #load at node i must always be less than the capacity
#
# optimize!(PartB)
#
# println()
# println("Cost of the route (lower bound) 1st it: ",value.(sum(x[i,j,k]*c[i,j] for i=1:nn, j=1:nn, k=1:K)))
# println()

routes = zeros(Int64, 3, 6)
r,cust = size(routes)

# calculate recourse cost of the routes
function expected_recourse_cost(routes, Q, q_avg)
    r,cust = size(routes)
    recourse_costs = zeros(Float64, r)
    recourse_costs_opp = zeros(Float64, r)
    for i in 1:r
        expected_cust_demand = zeros(Int64, cust-2)
        # stochastic_demand = zeros(Int64, cust-2)
        cumulative_demand = 0
        cumulative_demand_opp = 0
        route_recourse_cost = 0.0
        route_recourse_cost_opp = 0.0

        F1 = ones(Float64,cust-2) # Probability for demand being <= than Q
        F2 = ones(Float64,cust-2) # Probability for demand being <= than 2Q
        F_failure1 = zeros(Float64,cust-2) # probability of having first failure at the ith customer
        F_failure2 = zeros(Float64,cust-2) # probability of having seconds failure at the ith customer
        F1_opp = ones(Float64,cust-2) # Probability for demand being <= than Q opposite dir route
        F2_opp = ones(Float64,cust-2) # Probability for demand being <= than 2Q opposite dir route
        F_failure1_opp = zeros(Float64,cust-2) # probability of having first failure at the ith customer opposite dir route
        F_failure2_opp = zeros(Float64,cust-2) # probability of having seconds failure at the ith customer opposite dir route

        if i<3
            for j in 1:cust-2
                # demand = rand(Poisson(q_avg[routes[i,j+1]]))
                # stochastic_demand[j] = demand
                expected_cust_demand[j] = q_avg[routes[i,j+1]]
                cumulative_demand += expected_cust_demand[j]
                # println(cumulative_demand)
                F1[j] = cdf.(Poisson(cumulative_demand), Q)
                F2[j] = cdf.(Poisson(cumulative_demand), 2*Q)
                # if demand > expected_cust_demand[j]
                #     println("Higher demand: ", demand)
                # else
                #     println("Lower demand: ", demand)
                # end
                if j>1
                    F_failure1[j] = F1[j-1] - F1[j]
                    F_failure2[j] = F2[j-1] - F2[j]
                end
                # calculate recourse cost for each route
                recourse_cost = 2*c[1,routes[i,j+1]+1]*F_failure1[j]
                # println(recourse_cost)
                route_recourse_cost += recourse_cost
            end
            expected_cust_demand_opp = reverse(expected_cust_demand)
            route_opp = reverse(routes[i,:])
            println()
            println(expected_cust_demand_opp)
            println(route_opp)
            println()
            for j in 1:cust-2
                cumulative_demand_opp += expected_cust_demand_opp[j]
                F1_opp[j] = cdf.(Poisson(cumulative_demand_opp), Q)
                F2_opp[j] = cdf.(Poisson(cumulative_demand_opp), 2*Q)
                if j>1
                    F_failure1_opp[j] = F1_opp[j-1] - F1_opp[j]
                    F_failure2_opp[j] = F2_opp[j-1] - F2_opp[j]
                end
                # calculate recourse cost for each route opposite direction
                recourse_cost_opp = 2*c[1,route_opp[j+1]+1]*F_failure1_opp[j]
                route_recourse_cost_opp += recourse_cost_opp
            end
            # println()
            # println("Customer expected demand: ", expected_cust_demand)
            # println("Customers real demand: ", stochastic_demand)
            # println("cumulative demand: ", cumulative_demand)
            # println("Probability for demand being <= than Q: ", F1)
            # println("Probability for demand being <= than 2Q: ", F2)
            # println("Probability of having the first failure at customer jth: ", F_failure1)
            # println("Probability of having the second failure at customer jth: ", F_failure2)
            # println()
            # println("Route recourse cost: ", route_recourse_cost)

            recourse_costs[i] = route_recourse_cost
            recourse_costs_opp[i] = route_recourse_cost_opp
        else
            route_recourse_cost = 0.0
            recourse_costs[i] = route_recourse_cost
            recourse_costs_opp[i] = route_recourse_cost
        end
        println()
        println("Recourse cost route ", i, " : ", recourse_costs[i])
        println("Recourse cost opposite direction route ", i, " : ", recourse_costs_opp[i])
    end
    return recourse_costs, recourse_costs_opp
end

# recourse_costs = zeros(Float64, r)
# recourse_costs_opp = zeros(Float64, r)
# recourse_costs, recourse_costs_opp = expected_recourse_cost(routes, Q, q_avg)
# println(recourse_costs)
# println(recourse_costs_opp)
# println()
# println("Cost of the route (upper bound) 1st it: ",value.(sum(x[i,j,k]*c[i,j] for i=1:nn, j=1:nn, k=1:K)) + recourse_costs[1] + recourse_costs[2] + recourse_costs[3])
# println()

routes
recourse_costs = zeros(Float64, 13, r)
recourse_costs_opp = zeros(Float64, 13, r)

# 1st iterations
routes[1,:] = [0 5 4 2 6 0]
routes[2,:] = [0 7 1 8 3 0]
println("Routes 1st it: ", routes)

recourse_costs[1,:], recourse_costs_opp[1,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[1,:])
println(recourse_costs_opp[1,:])
println()

println()
println("Cost of the route (lower bound) 1st it: ", 280)
println("Cost of the route (upper bound) 1st it: ",280 + recourse_costs[1,1] + recourse_costs[1,2] + recourse_costs[1,3])
println()

# 2nd iterations
routes[1,:] = [0 3 8 1 6 0]
routes[2,:] = [0 2 4 5 7 0]
println("Routes 2nd it: ", routes)

recourse_costs[2,:], recourse_costs_opp[2,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[2,:])
println(recourse_costs_opp[2,:])
println()

println()
println("Cost of the route (lower bound) 2st it: ", 285)
println("Cost of the route (upper bound) 2st it: ",285 + recourse_costs[2,1] + recourse_costs[2,2] + recourse_costs[2,3])
println()

# 3nd iterations
routes[1,:] = [0 7 1 3 8 0]
routes[2,:] = [0 6 5 4 2 0]
println("Routes 3rd it: ", routes)

recourse_costs[3,:], recourse_costs_opp[3,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[3,:])
println(recourse_costs_opp[3,:])
println()

println()
println("Cost of the route (lower bound) 3rd it: ", 285)
println("Cost of the route (upper bound) 3rd it: ",285 + recourse_costs[3,1] + recourse_costs[3,2] + recourse_costs[3,3])
println()
# #
# # 4th iterations
routes[1,:] = [0 3 8 1 7 0]
routes[2,:] = [0 6 5 2 4 0]
println("Routes 4th it: ", routes)

recourse_costs[4,:], recourse_costs_opp[4,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[4,:])
println(recourse_costs_opp[4,:])
println()

println()
println("Cost of the route (lower bound) 4th it: ", 288.96)
println("Cost of the route (upper bound) 4th it: ", 288.96 + recourse_costs[4,1] + recourse_costs[4,2] + recourse_costs[4,3])
println()
#
# 5th iterations
routes[1,:] = [0 6 1 3 8 0]
routes[2,:] = [0 5 4 2 7 0]
println("Routes 5th it: ", routes)

recourse_costs[5,:], recourse_costs_opp[5,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[5,:])
println(recourse_costs_opp[5,:])
println()

println()
println("Cost of the route (lower bound) 5th it: ", 290)
println("Cost of the route (upper bound) 5th it: ", 290 + recourse_costs[5,1] + recourse_costs[5,2] + recourse_costs[5,3])
println()
#
# # 6th iterations
routes[1,:] = [0 6 4 2 5 0]
routes[2,:] = [0 3 8 1 7 0]
println("Routes 6th it: ", routes)

recourse_costs[6,:], recourse_costs_opp[6,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[6,:])
println(recourse_costs_opp[6,:])
println()

println()
println("Cost of the route (lower bound) 6th it: ", 290.96)
println("Cost of the route (upper bound) 6th it: ", 290.96 + recourse_costs[6,1])
println()
#
# 7th iterations
routes[1,:] = [0 6 2 5 4 0]
routes[2,:] = [0 3 8 1 7 0]
println("Routes 7th it: ", routes)

recourse_costs[7,:], recourse_costs_opp[7,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[7,:])
println(recourse_costs_opp[7,:])
println()

println()
println("Cost of the route (lower bound) 7th it: ", 290.96)
println("Cost of the route (upper bound) 7th it: ", 290.96 + recourse_costs[7,1])
println()
#
# # 8th iterations
routes[1,:] = [0 3 8 1 7 0]
routes[2,:] = [0 2 5 4 6 0]
println("Routes 8th it: ", routes)

recourse_costs[8,:], recourse_costs_opp[8,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[8,:])
println(recourse_costs_opp[8,:])
println()

println()
println("Cost of the route (lower bound) 8th it: ", 293.96)
println("Cost of the route (upper bound) 8th it: ", 293.96 + recourse_costs[8,2])
println()
#
# # 9th iterations
routes[1,:] = [0 3 8 6 1 0]
routes[2,:] = [0 7 4 2 5 0]
println("Routes 9th it: ", routes)

recourse_costs[9,:], recourse_costs_opp[9,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[9,:])
println(recourse_costs_opp[9,:])
println()

println()
println("Cost of the route (lower bound) 9th it: ", 302)
println("Cost of the route (upper bound) 9th it: ", 302 + recourse_costs[9,1] + recourse_costs[9,2] + recourse_costs[9,3])
println()
#
# # 10th iterations
routes[1,:] = [0 7 5 2 4 0]
routes[2,:] = [0 8 3 6 1 0]
println("Routes 10th it: ", routes)

recourse_costs[10,:], recourse_costs_opp[10,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[10,:])
println(recourse_costs_opp[10,:])
println()

println()
println("Cost of the route (lower bound) 10th it: ", 303)
println("Cost of the route (upper bound) 10th it: ", 303 + recourse_costs[10,1] + recourse_costs[10,2] + recourse_costs[10,3])
println()

# 12th iterations
routes[1,:] = [0 2 5 4 7 0]
routes[2,:] = [0 8 3 6 1 0]
println("Routes 11th it: ", routes)

recourse_costs[11,:], recourse_costs_opp[11,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[11,:])
println(recourse_costs_opp[11,:])
println()
#
# println()
println("Cost of the route (lower bound) 11th it: ", 306)
println("Cost of the route (upper bound) 11th it: ", 306 + recourse_costs[11,1])
# println()

# 13th iterations
routes[1,:] = [0 5 4 2 6 0]
routes[2,:] = [0 3 8 1 7 0]
println("Routes 13th it: ", routes)

recourse_costs[12,:], recourse_costs_opp[12,:] = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs[12,:])
println(recourse_costs_opp[12,:])
println()
#
# println()
println("Cost of the route (lower bound) 13th it: ", 306.09)
println("Cost of the route (upper bound) 13th it: ", 280 + recourse_costs[12,1] + recourse_costs[12,2] + recourse_costs[12,3])
# println()

# adding recourse costs to the model
PartB_recourse = Model(Gurobi.Optimizer)
set_time_limit_sec(PartB_recourse::Model, 600)

# define variables
@variable(PartB_recourse, x[1:nn,1:nn,1:K], Bin) #equal to 1 if the arc is traversed by vehicule k
@variable(PartB_recourse, w[1:nn,1:K] >=0) # indicates position of node i in the route of vehicule k
@variable(PartB_recourse, z[1:K] >=0)

@objective(PartB_recourse, Min, sum(c[i,j]*x[i,j,k] for k=1:K, i=1:nn, j=1:nn) + sum(z[k] for k=1:K))

# flow constraints
@constraint(PartB_recourse, [i=2:nn-1], sum(x[i,j,k] for k=1:K, j=1:nn if i != j) == 1) # must leave every customer once
@constraint(PartB_recourse, [l=2:nn-1, k=1:K], sum(x[i,l,k] for i=1:nn) == sum(x[l,j,k] for j=1:nn))
@constraint(PartB_recourse, [k=1:K], sum(x[1,j,k] for j=1:nn-1) <= 1) # must leave the depot once for each vehicule
@constraint(PartB_recourse, [k=1:K], sum(x[i,nn,k] for i=1:nn) <= 1) # must enter the depot once for each vehicule


#  route position of custumers served constraint
@constraint(PartB_recourse, [i=1:nn, j=1:nn, k=1:K], w[i,k] + 1 <= w[j,k] + (1 - x[i,j,k])*M)

#capacity constraints
@constraint(PartB_recourse, [k=1:K], sum(q_avg_dep[i]*x[i,j,k] for i=1:nn, j=1:nn) <= Q) #load at node i must always be less than the capacity

# recourse constraints
# 1st it
@constraint(PartB_recourse, [k=1:K], recourse_costs[1,1]*(x[10,6,k] + x[6,5,k] + x[5,3,k] + x[3,7,k] + x[7,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[1,1]*(x[1,6,k] + x[6,5,k] + x[5,3,k] + x[3,7,k] + x[7,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[1,1]*(x[6,10,k] + x[5,6,k] + x[3,5,k] + x[7,3,k] + x[1,7,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[1,1]*(x[6,1,k] + x[5,6,k] + x[3,5,k] + x[7,3,k] + x[10,7,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[1,2]*(x[10,8,k] + x[8,2,k] + x[2,9,k] + x[9,4,k] + x[4,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[1,2]*(x[1,8,k] + x[8,2,k] + x[2,9,k] + x[9,4,k] + x[4,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[1,2]*(x[8,10,k] + x[2,8,k] + x[9,2,k] + x[4,9,k] + x[1,4,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[1,2]*(x[8,1,k] + x[2,8,k] + x[9,2,k] + x[4,9,k] + x[10,4,k] - 4) <= z[k])

# 2nd it
@constraint(PartB_recourse, [k=1:K], recourse_costs[2,1]*(x[10,4,k] + x[4,9,k] + x[9,2,k] + x[2,7,k] + x[7,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[2,1]*(x[1,4,k] + x[4,9,k] + x[9,2,k] + x[2,7,k] + x[7,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[2,1]*(x[4,10,k] + x[9,4,k] + x[2,9,k] + x[7,2,k] + x[1,7,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[2,1]*(x[4,1,k] + x[9,4,k] + x[2,9,k] + x[7,2,k] + x[10,7,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[2,2]*(x[10,3,k] + x[3,5,k] + x[5,6,k] + x[6,8,k] + x[8,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[2,2]*(x[1,3,k] + x[3,5,k] + x[5,6,k] + x[6,8,k] + x[8,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[2,2]*(x[3,10,k] + x[5,3,k] + x[6,5,k] + x[8,6,k] + x[1,8,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[2,2]*(x[3,1,k] + x[5,3,k] + x[6,5,k] + x[8,6,k] + x[10,8,k] - 4) <= z[k])

# 3rd it
@constraint(PartB_recourse, [k=1:K], recourse_costs[3,1]*(x[1,8,k] + x[8,2,k] + x[2,4,k] + x[4,9,k] + x[9,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[3,1]*(x[10,8,k] + x[8,2,k] + x[2,4,k] + x[4,9,k] + x[9,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[3,1]*(x[8,1,k] + x[2,8,k] + x[4,2,k] + x[9,4,k] + x[10,9,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[3,1]*(x[8,10,k] + x[2,8,k] + x[4,2,k] + x[9,4,k] + x[1,9,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[3,2]*(x[1,7,k] + x[7,6,k] + x[6,5,k] + x[5,3,k] + x[3,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[3,2]*(x[10,7,k] + x[7,6,k] + x[6,5,k] + x[5,3,k] + x[3,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[3,2]*(x[7,1,k] + x[6,7,k] + x[5,6,k] + x[3,5,k] + x[10,3,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[3,2]*(x[7,10,k] + x[6,7,k] + x[5,6,k] + x[3,5,k] + x[1,3,k] - 4) <= z[k])

# 4th it
@constraint(PartB_recourse, [k=1:K], recourse_costs[4,2]*(x[10,7,k] + x[7,6,k] + x[6,3,k] + x[3,5,k] + x[5,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[4,2]*(x[1,7,k] + x[7,6,k] + x[6,3,k] + x[3,5,k] + x[5,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[4,2]*(x[7,10,k] + x[6,7,k] + x[3,6,k] + x[5,3,k] + x[1,5,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[4,2]*(x[7,1,k] + x[6,7,k] + x[3,6,k] + x[5,3,k] + x[10,5,k] - 4) <= z[k])

# 5th it
@constraint(PartB_recourse, [k=1:K], recourse_costs[5,1]*(x[10,7,k] + x[7,2,k] + x[2,4,k] + x[4,9,k] + x[9,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[5,1]*(x[1,7,k] + x[7,2,k] + x[2,4,k] + x[4,9,k] + x[9,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[5,1]*(x[7,10,k] + x[2,7,k] + x[4,2,k] + x[9,4,k] + x[1,9,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[5,1]*(x[7,1,k] + x[2,7,k] + x[4,2,k] + x[9,4,k] + x[10,9,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[5,2]*(x[10,6,k] + x[6,5,k] + x[5,3,k] + x[3,8,k] + x[8,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[5,2]*(x[1,6,k] + x[6,5,k] + x[5,3,k] + x[3,8,k] + x[8,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[5,2]*(x[6,10,k] + x[5,6,k] + x[3,5,k] + x[8,3,k] + x[1,8,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[5,2]*(x[6,1,k] + x[5,6,k] + x[3,5,k] + x[8,3,k] + x[10,8,k] - 4) <= z[k])

# 6th it
@constraint(PartB_recourse, [k=1:K], recourse_costs[6,1]*(x[10,7,k] + x[7,5,k] + x[5,3,k] + x[3,6,k] + x[6,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[6,1]*(x[1,7,k] + x[7,5,k] + x[5,3,k] + x[3,6,k] + x[6,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[6,1]*(x[7,10,k] + x[5,7,k] + x[3,5,k] + x[6,3,k] + x[1,6,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[6,1]*(x[7,1,k] + x[5,7,k] + x[3,5,k] + x[6,3,k] + x[10,6,k] - 4) <= z[k])

# 7th it
@constraint(PartB_recourse, [k=1:K], recourse_costs[7,1]*(x[1,7,k] + x[7,3,k] + x[3,6,k] + x[6,5,k] + x[5,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[7,1]*(x[10,7,k] + x[7,3,k] + x[3,6,k] + x[6,5,k] + x[5,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[7,1]*(x[7,1,k] + x[3,7,k] + x[6,3,k] + x[5,6,k] + x[10,5,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[7,1]*(x[7,10,k] + x[3,7,k] + x[6,3,k] + x[5,6,k] + x[1,5,k] - 4) <= z[k])

# 8th it
@constraint(PartB_recourse, [k=1:K], recourse_costs[8,2]*(x[10,3,k] + x[3,6,k] + x[6,5,k] + x[5,7,k] + x[7,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[8,2]*(x[1,3,k] + x[3,6,k] + x[6,5,k] + x[5,7,k] + x[7,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[8,2]*(x[3,10,k] + x[6,3,k] + x[5,6,k] + x[7,5,k] + x[1,7,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[8,2]*(x[3,1,k] + x[6,3,k] + x[5,6,k] + x[7,5,k] + x[10,7,k] - 4) <= z[k])

# 9th it
@constraint(PartB_recourse, [k=1:K], recourse_costs[9,1]*(x[1,4,k] + x[4,9,k] + x[9,7,k] + x[7,2,k] + x[2,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[9,1]*(x[10,4,k] + x[4,9,k] + x[9,7,k] + x[7,2,k] + x[2,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[9,1]*(x[4,1,k] + x[9,4,k] + x[7,9,k] + x[2,7,k] + x[10,2,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[9,1]*(x[4,10,k] + x[9,4,k] + x[7,9,k] + x[2,7,k] + x[1,2,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[9,2]*(x[1,8,k] + x[8,5,k] + x[5,3,k] + x[3,6,k] + x[6,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[9,2]*(x[10,8,k] + x[8,5,k] + x[5,3,k] + x[3,6,k] + x[6,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[9,2]*(x[8,1,k] + x[5,8,k] + x[3,5,k] + x[6,3,k] + x[10,6,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[9,2]*(x[8,10,k] + x[5,8,k] + x[3,5,k] + x[6,3,k] + x[1,6,k] - 4) <= z[k])

# 10th it
@constraint(PartB_recourse, [k=1:K], recourse_costs[10,1]*(x[1,9,k] + x[9,4,k] + x[4,7,k] + x[7,2,k] + x[2,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[10,1]*(x[10,9,k] + x[9,4,k] + x[4,7,k] + x[7,2,k] + x[2,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[10,1]*(x[9,1,k] + x[4,9,k] + x[7,4,k] + x[2,7,k] + x[10,2,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[10,1]*(x[9,10,k] + x[4,9,k] + x[7,4,k] + x[2,7,k] + x[1,2,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[10,2]*(x[1,8,k] + x[8,6,k] + x[6,3,k] + x[3,5,k] + x[5,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[10,2]*(x[10,8,k] + x[8,6,k] + x[6,3,k] + x[3,5,k] + x[5,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[10,2]*(x[8,10,k] + x[6,8,k] + x[3,6,k] + x[5,3,k] + x[1,5,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[10,2]*(x[8,1,k] + x[6,8,k] + x[3,6,k] + x[5,3,k] + x[10,5,k] - 4) <= z[k])

# 11th it
@constraint(PartB_recourse, [k=1:K], 0.044*(x[1,2,k] + x[2,7,k] + x[7,8,k] + x[8,10,k] - 3) <= z[k])
@constraint(PartB_recourse, [k=1:K], 0.044*(x[10,2,k] + x[2,7,k] + x[7,8,k] + x[8,1,k] - 3) <= z[k])
@constraint(PartB_recourse, [k=1:K], 0.044*(x[2,1,k] + x[7,2,k] + x[8,7,k] + x[10,8,k] - 3) <= z[k])
@constraint(PartB_recourse, [k=1:K], 0.044*(x[2,1,k] + x[7,2,k] + x[8,7,k] + x[10,8,k] - 3) <= z[k])
@constraint(PartB_recourse, [k=1:K], 0.285*(x[1,6,k] + x[6,5,k] + x[5,3,k] + x[3,10,k] - 3) <= z[k])
@constraint(PartB_recourse, [k=1:K], 0.285*(x[10,6,k] + x[6,5,k] + x[5,3,k] + x[3,1,k] - 3) <= z[k])
@constraint(PartB_recourse, [k=1:K], 0.25*(x[6,1,k] + x[5,6,k] + x[3,5,k] + x[10,3,k] - 3) <= z[k])
@constraint(PartB_recourse, [k=1:K], 0.25*(x[6,10,k] + x[5,6,k] + x[3,5,k] + x[1,3,k] - 3) <= z[k])

# 12th it
@constraint(PartB_recourse, [k=1:K], recourse_costs[11,1]*(x[1,3,k] + x[3,6,k] + x[6,5,k] + x[5,8,k] + x[8,10,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs[11,1]*(x[10,3,k] + x[3,6,k] + x[6,5,k] + x[5,8,k] + x[8,1,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[11,1]*(x[3,1,k] + x[6,3,k] + x[5,6,k] + x[8,5,k] + x[10,8,k] - 4) <= z[k])
@constraint(PartB_recourse, [k=1:K], recourse_costs_opp[11,1]*(x[3,10,k] + x[6,3,k] + x[5,6,k] + x[8,5,k] + x[1,8,k] - 4) <= z[k])

optimize!(PartB_recourse)


println("Traversed arcs:")
for k=1:K
    for i=1:nn
        for j=1:nn
            if value.(x[i,j,k]) == 1
                println("from ", i, "to ", j, "   with vehicle ", k)
            end
        end
    end
end

println()
println("Cost of the new route (lower bound): ",value.(sum(c[i,j]*x[i,j,k] for k=1:K, i=1:nn, j=1:nn) + sum(z[k] for k=1:K)))
println()

end  # module PartB
