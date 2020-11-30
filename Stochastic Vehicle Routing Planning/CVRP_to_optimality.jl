module PartB_to_optimality

using Gurobi
#using CPLEX
using JuMP
using Distributions

include("data_CVRPSD.jl")

nn = n+2 # number of customers + 2 (leaving and entering depot)
K = 3    # number of vehicules to serve the customers
M = 99999

PartB = Model(Gurobi.Optimizer)
set_time_limit_sec(PartB::Model, 600)

# define variables
@variable(PartB, x[1:nn,1:nn,1:K], Bin) #equal to 1 if the arc is traversed by vehicule k
@variable(PartB, w[1:nn,1:K] >=0) # indicates position of node i in the route of vehicule k

@objective(PartB, Min, sum(c[i,j]*x[i,j,k] for k=1:K, i=1:nn, j=1:nn))

# flow constraints
@constraint(PartB, [i=2:nn-1], sum(x[i,j,k] for k=1:K, j=1:nn if i != j) == 1) # must leave every customer once
@constraint(PartB, [l=2:nn-1, k=1:K], sum(x[i,l,k] for i=1:nn) == sum(x[l,j,k] for j=1:nn))
@constraint(PartB, [k=1:K], sum(x[1,j,k] for j=1:nn-1) <= 1) # must leave the depot once for each vehicule
@constraint(PartB, [k=1:K], sum(x[i,nn,k] for i=1:nn) <= 1) # must enter the depot once for each vehicule


#  route position of custumers served constraint
@constraint(PartB, [i=1:nn, j=1:nn, k=1:K], w[i,k] + 1 <= w[j,k] + (1 - x[i,j,k])*M)

#capacity constraints
@constraint(PartB, [k=1:K], sum(q_avg_dep[i]*x[i,j,k] for i=1:nn, j=1:nn) <= Q) #load at node i must always be less than the capacity

optimize!(PartB)

println()
println(value.(w))
routes = zeros(Int64, 3, 6)
r,cust = size(routes)

println("Traversed arcs:")
for k=1:K
    for i=1:nn
        for j=1:nn
            if value.(x[i,j,k]) == 1
                println("from ", i, "to ", j, "   with vehicule ", k)
            end
        end
    end
end
println()
println("Cost of the route (lower bound): ",value.(sum(x[i,j,k]*c[i,j] for i=1:nn, j=1:nn, k=1:K)))
println()
routes[1,:] = [0 5 4 2 6 0]
routes[2,:] = [0 7 1 8 3 0]
println("Routes: ", routes)

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

recourse_costs = zeros(Float64, r)
recourse_costs_opp = zeros(Float64, r)
recourse_costs, recourse_costs_opp = expected_recourse_cost(routes, Q, q_avg)
println(recourse_costs)
println(recourse_costs_opp)
println()
println("Cost of the route (upper bound): ",value.(sum(x[i,j,k]*c[i,j] for i=1:nn, j=1:nn, k=1:K)) + recourse_costs[1] + recourse_costs[2] + recourse_costs[3])
println()

end
