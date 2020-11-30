#************************************************************************#
# Vehicule Routing Problem Stochastic Demanad (VRPSD)
#************************************************************************#

# import packages
using StatsBase
using Distributions
using Gadfly

# define structs for the model
mutable struct feasibleroutesStruct
    route_num::Int64       # enumeration of feasible routes
    route::Array{Int64,1}  # feasible route for a vehicule m
    demand::Array{Int64,1} # customer expected demand
    cost::Int64            # cost of feasible route
end

mutable struct recourseRouteStruct
    route_num::Int64                     # enumeration of feasible routes
    route::Array{Int64,1}                # feasible route for a vehicule m
    avg_demand::Array{Int64,1}           # customer expected demand
    deterministic_cost::Int64            # determinnistic cost of feasible route
    recourse_cost::Float64               # recourse cost of feasible route
    expected_route_cost::Float64         # expected cost of feasible route
end

# mutable struct recourseRouteStruct
#     route_num::Int64                     # enumeration of feasible routes
#     route::Array{Int64,1}                # feasible route for a vehicule m
#     avg_demand::Array{Int64,1}           # customer expected demand
#     stochastic_demand::Array{Int64,1}    # stochastic demand (Poisson distribution)
#     deterministic_cost::Int64            # determinnistic cost of feasible route
#     recourse_cost::Float64               # recourse cost of feasible route
#     expected_route_cost::Float64         # expected cost of feasible route
# end

#************************************************************************
#************************************************************************
# DATA
include("data_CVRPSD.jl")
(V, A) = size(c)
N = size(q_avg);

#************************************************************************
#************************************************************************
# Heuristic to generate feasible routes for CVRPSD
#-------------------------- Constraints implementation ------------------------
function capacity_contraint(Q, q_avg, picked_customer, capacity)
    # add capacity of next customer
    capacity +=  q_avg[picked_customer]
    if capacity <= Q
        capacity = capacity
        println("Capacity fulfill")
    else
        println("Capacity exceed")
    end
    return capacity
end
#------------Calculating cost--------------------------------------------
function cost_calculator(customer_list, customers, i)

    cost = c[1,customer_list[1]+1]

    if isempty(customers)
        cost  += c[customer_list[1]+1, customer_list[2]+1]
        cost  += c[customer_list[2]+1, customer_list[3]+1]
        cost +=  c[customer_list[3]+1, 10]

        println("Route cost (", i, " customers): ", cost)
    else
        for i in 1:(length(customer_list)-1)
            cost  += c[customer_list[i]+1, customer_list[i+1]+1]
        end
        cost += c[customer_list[4]+1, 10]
        println("Route cost (", i, " customers): ", cost)
    end
    return cost
end

# function to pick a random customer
function pick_random_cust(customers)
    if isempty(customers)
        rand_cust = 0
    else
    rand_cust = sample(customers, 1, replace = false)
    filter!(x->x≠rand_cust[1], customers)
    rand_cust = rand_cust[1]
    end
    return rand_cust, customers
end

# generate feasible routes
function feasible_route()
    customers = [1,2,3,4,5,6,7,8]
    customer_list = zeros(Int64, 5)
    customer_expected_demand = zeros(Int64, 5)
    capacity = 0
    cost = 0
    i = 1

    picked_customer, customers = pick_random_cust(customers)
    capacity = capacity_contraint(Q, q_avg, picked_customer, capacity)
    # println("cusotmers left: ", customers)
    println("Capacity: ", capacity)
    customer_list[1] = picked_customer
    customer_expected_demand[1] = q_avg[customer_list[1]]
    println("First customer: ", picked_customer)

        while (i < 5)
            if isempty(customers)
                println("Route total capacity (", i, " customers): ", capacity)
                cost = cost_calculator(customer_list, customers, i)
                println("No more cusotmers in customer_list: ", customers)
                filter!(x->x≠0, customer_list)
                filter!(x->x≠0, customer_expected_demand)
                break
            else
            next_customer, customers = pick_random_cust(customers)
            # println("Next customer: ", next_customer)
            capacity = capacity_contraint(Q, q_avg, next_customer, capacity)
            # println("Cusotmers left: ", customers)
            println("Capacity: ", capacity)

            if capacity <= Q
                i += 1
                customer_list[i] = next_customer
                customer_expected_demand[i] = q_avg[customer_list[i]]
            else
                capacity -= q_avg[next_customer]
            end
            end
        end
    if i<5
        nothing
    else
    println("Route total capacity (", i, " customers): ", capacity)
    cost = cost_calculator(customer_list, customers, i)
    end
    return customer_list, customer_expected_demand, cost
end

function create_feasible_routes()
    num_feasible_routes = 20
    feasible_routes = Vector{feasibleroutesStruct}(undef,0)
    for i in 1:num_feasible_routes
        println()
        customer_list, customer_expected_demand, cost = feasible_route()
        println()
        println("List of customers visited: ", customer_list)
        println("Customers expected demands: ", customer_expected_demand)
        route = feasibleroutesStruct(i, customer_list, customer_expected_demand, cost)
        push!(feasible_routes, route)
    end
    return feasible_routes
end

feasible_routes = create_feasible_routes()
println(feasible_routes)

function expected_recourse_cost(feasible_routes, Q)
    recourse_routes = Vector{recourseRouteStruct}(undef,0)
    for i in 1:length(feasible_routes)
        expected_cust_demand = feasible_routes[i].demand
        # stochastic_demand = zeros(Int64, length(expected_cust_demand))
        cumulative_demand = 0
        total_recourse_cost = 0.0
        expected_route_cost = 0.0
        F1 = ones(Float64,length(expected_cust_demand)) # Probability for demand being <= than Q
        F2 = ones(Float64,length(expected_cust_demand)) # Probability for demand being <= than 2Q
        F_failure1 = zeros(Float64,length(expected_cust_demand)) # probability of having first failure at the ith customer
        F_failure2 = zeros(Float64,length(expected_cust_demand)) # probability of having seconds failure at the ith customer

        for j in 1:length(expected_cust_demand)
            # demand = rand(Poisson(expected_cust_demand[j]))
            # stochastic_demand[j] = demand
            cumulative_demand += expected_cust_demand[j]

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
            recourse_cost = 2*c[1,feasible_routes[i].route[j]+1]*F_failure1[j]
            # println(recourse_cost)
            total_recourse_cost += recourse_cost
        end
        # calculate expected route cost: deterministic cost + recourse cost per route
        expected_route_cost = feasible_routes[i].cost + total_recourse_cost
        # println()
        # println("Customer expected demand: ", expected_cust_demand)
        # println("Customers real demand: ", stochastic_demand)
        # println("cumulative demand: ", cumulative_demand)
        # println("Probability for demand being <= than Q: ", F1)
        # println("Probability for demand being <= than 2Q: ", F2)
        # println("Probability of having the first failure at customer jth: ", F_failure1)
        # println("Probability of having the second failure at customer jth: ", F_failure2)
        # println()
        # println("Recourse cost: ", total_recourse_cost)
        # println("Deterministic route cost: ", feasible_routes[i].cost)
        # println("Expected route cost: ", expected_route_cost)
        # recourse_route = recourseRouteStruct(i, feasible_routes[i].route, expected_cust_demand, stochastic_demand, feasible_routes[i].cost, total_recourse_cost, expected_route_cost)
        recourse_route = recourseRouteStruct(i, feasible_routes[i].route, expected_cust_demand, feasible_routes[i].cost, total_recourse_cost, expected_route_cost)
        push!(recourse_routes, recourse_route)
    end
    return recourse_routes
end

recourse_routes = expected_recourse_cost(feasible_routes, Q)
println()
println(recourse_routes)
