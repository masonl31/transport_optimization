using StatsBase

#************************************************************************#
# Vehicule Routing Problem Time Windows (VRPTW)
#************************************************************************#
# module heuristic_routes
# define structs for the model
# route struct
mutable struct feasibleroutesStruct
    route_num::Int64      # enumeration of feasible routes
    route::Array{Int64,1} # feasible route for a vehicule m
    cost::Int64           # cost of feasible route
end

#************************************************************************
#************************************************************************
# DATA
include("data.jl")
(V, A) = size(c)
N = size(q);

#************************************************************************
#************************************************************************
# Heuristic to generate feasible routes
#-------------------------- Constraints implementation ------------------------
function capacity_contraint(Q, q, picked_customer, capacity)
    capacity +=  q[picked_customer]
    if capacity <= Q
        capacity = capacity
    else
        # println(capacity)
        # println("capacity exceed")
        capacity = capacity
    end
    cust_served = picked_customer
    return capacity
end

function time_windows_constraint(t, e, l, cust_served, next_customer, cust_arrival_time, customer_list, capacity, i)
    cust_arrival_time += t[cust_served+1, next_customer+1]
    if (cust_arrival_time <= l[next_customer+1])

        if ((e[next_customer+1] > cust_arrival_time))
            cust_arrival_time = e[cust_served+1]
        else
            cust_arrival_time = cust_arrival_time
        end
        customer_list[i+1] = next_customer
        cust_served = next_customer
        capacity = capacity_contraint(Q, q, next_customer, capacity)
        # println("customer on time:", next_customer)
        # println("customer arrrival: ", cust_arrival_time)
        # println("customer latest time: ", l[next_customer+1])
        if capacity <= 10
            i += 1
        end
    else
        # println()
        # println("customer late:", next_customer)
        # println("customer arrrival late: ", cust_arrival_time)
        # println("customer latest time: ", l[next_customer+1])
        cust_arrival_time -= t[cust_served+1, next_customer+1]
        # println("customer arrrival before: ", cust_arrival_time)
    end
    return next_customer, cust_served, cust_arrival_time, customer_list, capacity, i
end
#------------Calculating cost--------------------------------------------
function cost_calculator(customer_list, capacity, customers)

    cost = c[1,customer_list[1]+1]

    if isempty(customers)
        cost  += c[customer_list[1]+1, customer_list[2]+1]
        cost +=  c[customer_list[2]+1, 10]
        println("Route cost (2 customers): ", cost)
        # println(cost)
    else
        for i in 1:(length(customer_list)-1)
            cost  += c[customer_list[i]+1, customer_list[i+1]+1]
            # println(cost)
        end
        cost += c[customer_list[3]+1, 10]
        # cost += c[customer_list[2]+1, 10]
        println("Route cost (3 customers): ", cost)
    end
    return cost
end

# function to pick a random customer
function pick_random_cust(customers)
    if isempty(customers)
        # println("Customer array empty")
        rand_cust = 0
    else
    rand_cust = sample(customers, 1, replace = false)
    filter!(x->x≠rand_cust[1], customers)
    rand_cust = rand_cust[1]
    # println(customers)
    end
    return rand_cust, customers
end

# generate feasible routes
function feasible_route()
    customers = [1,2,3,4,5,6,7,8]
    customer_list = zeros(Int64, 3)
    capacity = 0
    cost = 0

    picked_customer, customers = pick_random_cust(customers)
    capacity = capacity_contraint(Q, q, picked_customer, capacity)
    customer_list[1] = picked_customer
    cust_arrival_time = t[1, picked_customer+1]
    # println("First customer: ", picked_customer)
    # println("First cust arrival time: ", cust_arrival_time)
    cust_served = picked_customer
    i = 1

        while (i < 3)
            if isempty(customers)
                break
            else
            next_customer, customers = pick_random_cust(customers)
            # println("Next customer: ", next_customer)
            # println("Capacity: ", capacity)
            # next_customer, capacity = capacity_contraint(Q, q, next_customer, capacity)
            # println(capacity)
            next_customer, cust_served, cust_arrival_time, customer_list, capacity, i = time_windows_constraint(t, e, l, cust_served, next_customer, cust_arrival_time, customer_list, capacity, i)
            end
        end
    if isempty(customers)
        cust_arrival_time += t[customer_list[2]+1, 10]
        println("Route total time (2 customers): ", cust_arrival_time)
        cost = cost_calculator(customer_list, capacity, customers)
    else
        cust_arrival_time += t[customer_list[3]+1, 10]
        println("Route total time (3 customers): ", cust_arrival_time)
        cost = cost_calculator(customer_list, capacity, customers)
    end
    return customer_list, cost
end

num_feasible_routes = 30
feasible_routes = Vector{feasibleroutesStruct}(undef,0)
for i in 1:num_feasible_routes
    println()
    customer_list, cost = feasible_route()
    println()
    println(customer_list)
    route = feasibleroutesStruct(i, customer_list, cost)
    push!(feasible_routes, route)
end
println(feasible_routes)
