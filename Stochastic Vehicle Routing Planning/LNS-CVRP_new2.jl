include("CVRPInstanceModule.jl")
include("CVRPSolutionModule.jl")

module LNSCVRP

using Gadfly, Random, Statistics

using ..CVRPInstanceModule
using ..CVRPSolutionModule

function routeGreedyFill(route::CVRPRoute, unassigned, inst::CVRPInstance)
  done = false
  while !done
    bestDelta = typemax(Float64)
    bestPos = -1
    bestCustomer = -1
    bestCustomerIdx = -1
    for i in 1:length(unassigned)
      customer = unassigned[i]
      if inst.demand[customer] + route.totalLoad <= inst.Q
        for j=2:length(route.theRoute)
          delta = inst.c[route.theRoute[j-1], customer] + inst.c[customer, route.theRoute[j]] - inst.c[route.theRoute[j-1],route.theRoute[j]]
          if (delta < bestDelta)
            bestDelta = delta
            bestCustomer = customer
            bestCustomerIdx = i
            bestPos = j
          end
        end
      end
    end
    if (bestCustomer >= 1)
      deleteat!(unassigned, bestCustomerIdx)
      route.totalLoad = route.totalLoad + inst.demand[bestCustomer]
      splice!(route.theRoute, bestPos:bestPos-1, bestCustomer)
    else
      done = true
    end
  end
end

function greedy(inst::CVRPInstance, sol::CVRPSolution)
  # println("In greedy")
  clear(sol, inst)
  while length(sol.unassigned) > 0
    #println("Unassigned customers: ", sol.unassigned)
    custIdx = rand(1:length(sol.unassigned))
    customer = sol.unassigned[custIdx]
    deleteat!(sol.unassigned, custIdx)
    # Make a new route for the customer
    newRoute = CVRPRoute(customer, inst)
    routeGreedyFill(newRoute, sol.unassigned, inst)
    push!(sol.routes,newRoute)
  end
  recalcSolCost(sol, inst)
end

function findBestInsertion(customer, sol::CVRPSolution, inst::CVRPInstance, r)
    bestDelta = typemax(Float64)
    bestPos = -1
    route = sol.routes[r]
    #println("customer ",customer)
    if inst.demand[customer] + route.totalLoad <= inst.Q
        for j=2:length(route.theRoute)
            delta = inst.c[route.theRoute[j-1], customer] + inst.c[customer, route.theRoute[j]] - inst.c[route.theRoute[j-1],route.theRoute[j]]
            if (delta < bestDelta)
                bestDelta = delta
                bestPos = j
            end
        end
    end
    return bestDelta, bestPos
end

function calcRouteInsertionCosts(inst::CVRPInstance, sol::CVRPSolution, insCostMatrix, r)
    for customer in sol.unassigned
        delta, pos = findBestInsertion(customer, sol, inst, r)
        insCostMatrix[customer,r] = delta
    end
end

function fillInsertionCostMatrix(inst::CVRPInstance, sol::CVRPSolution, insCostMatrix)
    for customer in sol.unassigned
        for r in 1:length(sol.routes)
            delta, pos = findBestInsertion(customer, sol, inst, r)
            insCostMatrix[customer,r] = delta
        end
    end
end

function parallelInsertion(inst::CVRPInstance, sol::CVRPSolution, maxRandFactor=0.0)
    #only necessary while debugging
    recalcSolCost(sol, inst)

    nEmptyRoutes = count(r -> length(r.theRoute)==2, sol.routes)
    if nEmptyRoutes == 0
        newRoute = CVRPRoute(inst)
        push!(sol.routes,newRoute)
        nEmptyRoutes += 1
    end
    # insCostMatrix is a matrix that at position (i,r)
    # stores the cost of inserting customer i in route r.
    # The matrix is going to contain a number of unused rows, corresponding
    # to customers that already are in the solution. That is a bit inefficient
    insCostMatrix = zeros(Float64, inst.n, length(sol.routes))
    fillInsertionCostMatrix(inst, sol, insCostMatrix)
    randNoise = 1.0
    while !isempty(sol.unassigned)
        #println("Unassigned: ", sol.unassigned)
        # perhaps this part could be written more nicely using "findmin"
        bestDelta = typemax(Float64)
        bestCust = -1
        bestRoute = -1
        for c in sol.unassigned
            for r in 1:length(sol.routes)
                if (maxRandFactor>0.0)
                    randNoise = 1 + maxRandFactor*rand()
                end
                if insCostMatrix[c,r]*randNoise < bestDelta
                    bestDelta = insCostMatrix[c,r]*randNoise
                    bestCust = c
                    bestRoute = r
                end
            end
        end
        if bestDelta == typemax(Float64)
            # It is a bug if this happen:
            throw("error in parallelInsertion. Could not find customer to insert")
        end
        #println("Inserting customer ", bestCust, " into route ", bestRoute, ", delta = ", bestDelta)
        #find insertion position
        delta, pos = findBestInsertion(bestCust, sol::CVRPSolution, inst, bestRoute)
        # remove bestCustomer from array of unassigned customers
        filter!(c -> c != bestCust, sol.unassigned)
        sol.routes[bestRoute].totalLoad += inst.demand[bestCust]
        splice!(sol.routes[bestRoute].theRoute, pos:pos-1, bestCust)
        costBefore = sol.routes[bestRoute].cost
        recalcRouteCost(sol.routes[bestRoute],inst)
        costAfter = sol.routes[bestRoute].cost
        if maxRandFactor == 0.0 && (abs(costAfter - costBefore - bestDelta) > 0.001)
            println("costAfter", costAfter, ", costBefore", costBefore, ", bestDelta:", bestDelta)
            println("Delta cost does not match reality")
           throw("Delta cost does not match reality")
        end
        # recalculate cost of inserting customers on the route that was changed
        calcRouteInsertionCosts(inst, sol, insCostMatrix, bestRoute)
        # Did we insert into an empty route (the new route would have length 3 then)
        if (length(sol.routes[bestRoute].theRoute) == 3)
            nEmptyRoutes -= 1
        end
        if nEmptyRoutes == 0
            # There are no more empty routes. Add a new empty route
            newRoute = CVRPRoute(inst)
            push!(sol.routes,newRoute)
            nEmptyRoutes += 1
            # add column to insertion cost matrix (this looks inefficient)
            insCostMatrix = [insCostMatrix zeros(inst.n,1)]
            # calculate insertion costs on the new route
            calcRouteInsertionCosts(inst, sol, insCostMatrix, length(sol.routes))
        end
        #display(insCostMatrix)
    end
    recalcSolCost(sol, inst)
end

function regretInsertion(inst::CVRPInstance, sol::CVRPSolution)
    maxRandFactor=0.0
    #only necessary while debugging
    recalcSolCost(sol, inst)

    # ensure that there always is an empty route:
    nEmptyRoutes = count(r -> length(r.theRoute)==2, sol.routes)
    if nEmptyRoutes == 0
        newRoute = CVRPRoute(inst)
        push!(sol.routes,newRoute)
        nEmptyRoutes += 1
    end
    # insCostMatrix is a matrix that at position (i,r)
    # stores the cost of inserting customer i in route r.
    # The matrix is going to contain a number of unused rows, corresponding
    # to customers that already are in the solution. That is a bit inefficient
    insCostMatrix = zeros(Float64, inst.n, length(sol.routes))
    fillInsertionCostMatrix(inst, sol, insCostMatrix)
    randNoise = 1.0
    while !isempty(sol.unassigned)
        #println("Unassigned: ", sol.unassigned)
        bestRegret = typemin(Float64)
        bestCust = -1
        overallBestRoute = -1
        for c in sol.unassigned
            bestRouteForCust = -1
            bestInsertion = secondBestInsertion = typemax(Float64)
            for r in 1:length(sol.routes)
                if (maxRandFactor>0.0)
                    randNoise = 1 + maxRandFactor*rand()
                end
                if insCostMatrix[c,r]*randNoise < bestInsertion
                    secondBestInsertion = bestInsertion
                    bestInsertion = insCostMatrix[c,r]*randNoise
                    bestRouteForCust = r
                elseif insCostMatrix[c,r]*randNoise < secondBestInsertion
                    secondBestInsertion = insCostMatrix[c,r]*randNoise
                end
            end
            if bestRouteForCust == -1
                throw("regretInsertion: No feasible route for customer. This should not happen")
            end
            if (secondBestInsertion-bestInsertion) > bestRegret
                bestRegret = secondBestInsertion-bestInsertion
                bestCust = c
                overallBestRoute = bestRouteForCust
            end
        end
        #println("Inserting customer ", bestCust, " into route ", bestRoute, ", delta = ", bestDelta)
        #find insertion position
        delta, pos = findBestInsertion(bestCust, sol::CVRPSolution, inst, overallBestRoute)
        # remove bestCustomer from array of unassigned customers
        filter!(c -> c != bestCust, sol.unassigned)
        sol.routes[overallBestRoute].totalLoad += inst.demand[bestCust]
        splice!(sol.routes[overallBestRoute].theRoute, pos:pos-1, bestCust)
        recalcRouteCost(sol.routes[overallBestRoute],inst)
        # recalculate cost of inserting customers on the route that was changed
        calcRouteInsertionCosts(inst, sol, insCostMatrix, overallBestRoute)
        # Did we insert into an empty route (the new route would have length 3 then)
        if (length(sol.routes[overallBestRoute].theRoute) == 3)
            nEmptyRoutes -= 1
        end
        if nEmptyRoutes == 0
            # There are no more empty routes. Add a new empty route
            newRoute = CVRPRoute(inst)
            push!(sol.routes,newRoute)
            nEmptyRoutes += 1
            # add column to insertion cost matrix (this looks inefficient)
            insCostMatrix = [insCostMatrix zeros(inst.n,1)]
            # calculate insertion costs on the new route
            calcRouteInsertionCosts(inst, sol, insCostMatrix, length(sol.routes))
        end
        #display(insCostMatrix)
    end
    recalcSolCost(sol, inst)
end


# <custToBeRemoved> contains the customers that we wish to remove
# we iterate through the routes of the solution and deletes customers as
# we see them
function removeCustomers(inst::CVRPInstance, sol::CVRPSolution, custToBeRemoved::BitSet)
    for route in sol.routes
        filter!(x -> !in(x,custToBeRemoved), route.theRoute)
        route.totalLoad = sum(c -> inst.demand[c], route.theRoute)
    end
end

function randomDestroy(inst::CVRPInstance, sol::CVRPSolution, amount)
    # Create a set of unassigned customers from the array in sol
    unassigned = BitSet(sol.unassigned)
    # assignedCust will be a vector of the customers that are planned in the
    # solution
    assignedCust = setdiff(BitSet(1:inst.n), unassigned)
    #  assignedCustArray is an array of the assigned customers
    assignedCustArray = collect(assignedCust)
    custToBeRemoved = BitSet()
    nRemoved = 0
    while (nRemoved + length(unassigned) < amount) && (length(assignedCustArray) > 0)
        # pick a random customer from assignedCustArray
        index = rand(1:length(assignedCustArray))
        push!(custToBeRemoved, assignedCustArray[index])
        push!(sol.unassigned, assignedCustArray[index])
        nRemoved += 1
        # this removes the element at <index> from the array
        # it is faster than deleteat (but harder to understand and reorders the array)
        assignedCustArray[index] = assignedCustArray[lastindex(assignedCustArray)]
        pop!(assignedCustArray)
    end
    #println("custToBeRemoved:", custToBeRemoved)
    #println("assignedCustArray:", assignedCustArray)
    removeCustomers(inst,sol,custToBeRemoved)
end

function calcNToRemove(n, relMin, relMax, absMin, absMax)
    minRem = max(absMin, round(relMin*n))
    minRem = min(minRem, n-1);
	maxRem = min(absMax, round(relMax*n));
	maxRem = min(maxRem, n-1);

	# In some cases we would end up with iMin > iMax so we need the following
	if (minRem > maxRem)
		minRem = maxRem;
    end

	return rand(minRem:maxRem)
end

mutable struct LNSStat
    elapsedTime::Array{Float64}
    attemptObj::Array{Float64}
    curObj::Array{Float64}
    bestObj::Array{Float64}
    acceptThreshold::Array{Float64}
end
LNSStat() = LNSStat(Array{Float64}(undef,0),Array{Float64}(undef,0),Array{Float64}(undef,0),Array{Float64}(undef,0),Array{Float64}(undef,0))

function plotConvergenceGraph(stat::LNSStat)
    p = plot(
        layer(x=stat.elapsedTime, y=stat.acceptThreshold, Geom.path,  Theme(default_color=colorant"green", line_width=0.5mm)),
        layer(x=stat.elapsedTime, y=stat.curObj, Geom.point,  Theme(default_color=colorant"red", point_size=0.5mm)),
        layer(x=stat.elapsedTime, y=stat.attemptObj, Geom.point, Theme(default_color=colorant"orange", point_size=0.5mm)),
        layer(x=stat.elapsedTime, y=stat.bestObj, Geom.path,  Theme(default_color=colorant"blue", line_width=0.5mm))
        )
    display(p)
end

function repair(inst::CVRPInstance, sol::CVRPSolution)
    random = rand(0:1)
    #random = 1
    if random > 0.5
        #println("par")
        parallelInsertion(inst, sol, 0.0)
    end
    if random <= 0.5
        # println("regret")
        regretInsertion(inst, sol)
    end
end

function LNS(inst::CVRPInstance, x::CVRPSolution, timeLimit, destroyMaxRel, destroyMaxAbs, startThreshold, seed)
    Random.seed!(seed)
    timeStart = time()
    iter = 0
    # xStar = x*
    xStar = deepcopy(x)
    elapsedSeconds = 0
    stat = LNSStat()
    while elapsedSeconds < timeLimit
        iter+=1
        # xPrime = x'
        xPrime = deepcopy(x)
        nRem = calcNToRemove(inst.n, 0.1, destroyMaxRel, 10, destroyMaxAbs)
        randomDestroy(inst, xPrime, nRem )
        repair(inst, xPrime)

        if (iter % 1000 == 0)
            # println(iter, ": curSol: ", x.cost, ", attempted: ", xPrime.cost, ", best: ", xStar.cost, ", elapsed: ", elapsedSeconds, ", Threshold: ", startThreshold*(1-elapsedSeconds/timeLimit))
        end
        attemptedObj = xPrime.cost
        # @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        # Below we have defined an acceptance criterion that only accepts improving solutions.
        #
        # you need to change this to  the record to record acceptance criterion
        # See slidesfrom lecture 5
        # c(x')  is called "xprime.cost" in the Julia code
        # c(x*)  is called "xStar.cost" in the Julia code
        # You should define T based on the parameter "startThreshold" as well as "elapsedSeconds" and "timeLimit"
        # T should start at "startThreshold" and decrease linearly to 0 as "elapsedSecond"s approaches "timeLimit"
        #
        # In order to get plots like the ones shown in the lecture you need to set accThreshold
        # as the highest cost solution that would be accepted in this iteration. This is going to define the green line
        # on the plots.
        # @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        record_to_record = (attemptedObj - xStar.cost) / xStar.cost
        T = startThreshold*(1 - (elapsedSeconds/timeLimit))
        accThreshold = xStar.cost*(T+1)
        if record_to_record < T
            # accThreshold = max(x.cost, attemptedObj)
            # println("Criteria accepted")
            # x = deepcopy(xPrime)
            x = deepcopy(xPrime)
        end
        # if accThreshold > x.cost
        #     accThreshold = x.cost
        # end
        bestImproved = false
        if x.cost < xStar.cost
            xStar = deepcopy(x)
            # println(iter, ":New best solution: ", xStar.cost)
            bestImproved = true
        end

        # accThreshold = x.cost+100 # <- this should be changed
        # if (xPrime.cost < x.cost)
        #     x = deepcopy(xPrime)
        # end
        # bestImproved = false
        # if (x.cost < xStar.cost)
        #     xStar = deepcopy(x)
        #     println(iter, ":New best solution: ", xStar.cost)
        #     bestImproved = true
        # end
        if iter % 100 == 0 || bestImproved
            push!(stat.elapsedTime, elapsedSeconds)
            push!(stat.attemptObj, attemptedObj)
            push!(stat.curObj, x.cost)
            push!(stat.bestObj, xStar.cost)
            push!(stat.acceptThreshold, accThreshold)
        end
        elapsedSeconds = time() - timeStart
    end
    # println("Time spent: $elapsedSeconds (time limit was: $timeLimit)")

    return xStar, stat
end

# returns a vector with the best objective value found in each repetition
function TestLNS(instance::CVRPInstance, destroyMaxRel::Float64, startThreshold::Float64, repetitions::Int64, timeLimitPerCust::Float64 = 0.05)
    n = instance.n
    startSol = CVRPSolution(0,[],[])
    Random.seed!(1)
    greedy(instance, startSol)

    # parameters for LNS(..)
    # 1) instance
    # 2) starting solution
    # 3) time limit in seconds
    # 4) degree of destruction (i.e. 0.4 = up to 40% percent)
    # 5) maximum number of customers to destroy (keep at 50 for now)
    # 6) Starting threshold for record to record travel 0.05 = 5%
    # 7) seed (used to get different results in repeated runs)
    bestSol = deepcopy(startSol)
    objectiveValues = Array{Float64}(undef,0)
    stat = LNSStat()
    for i=1:repetitions
        stat = LNSStat()
        sol = deepcopy(startSol)
        # println("LNS... run $i out of $repetitions")
        # last parameter is the seed
        sol,stat = LNS(instance, sol, timeLimitPerCust*n, destroyMaxRel, 50, startThreshold, i)
        push!(objectiveValues,sol.cost)
        if sol.cost < bestSol.cost
            bestSol = deepcopy(sol)
        end
    end
    println()
    println("best solution from $repetitions repetitions:", findmin(objectiveValues)[1])
    println("Average objective value:", mean(objectiveValues))
    println("Standard deviation:", std(objectiveValues))

    #plotConvergenceGraph(stat)
    # comment this line  in if you wish to plot the solution
    # plotSolution(bestSol, instance)

    return findmin(objectiveValues)[1]
    # return objectiveValues
end

function testAll(destroyMaxRel::Float64, startThreshold::Float64, repetitions::Int64, timeLimitPerCust::Float64 = 0.05)
    allfiles = ["X-n101-k25.vrp", "X-n106-k14.vrp", "X-n110-k13.vrp" ,"X-n115-k10.vrp",
        "X-n120-k6.vrp", "X-n125-k30.vrp", "X-n129-k18.vrp", "X-n134-k13.vrp", "X-n139-k10.vrp",
        "X-n143-k7.vrp", "X-n148-k46.vrp", "X-n153-k22.vrp", "X-n157-k13.vrp", "X-n162-k11.vrp",
        "X-n167-k10.vrp", "X-n256-k16.vrp", "X-n261-k13.vrp", "X-n280-k17.vrp", "X-n294-k50.vrp",
        "X-n303-k21.vrp"]
    results = []
    for instance in allfiles
        objectiveValues = TestLNS("Data/$instance", destroyMaxRel, startThreshold, repetitions, timeLimitPerCust)
        push!(results, (instance, mean(objectiveValues)) )
    end
    return results
end

# original code
function TestLNS(filename::String, destroyMaxRel::Float64, startThreshold::Float64, repetitions::Int64, timeLimitPerCust::Float64 = 0.05)
    instance = readInstance("$filename", true)
    return TestLNS(instance, destroyMaxRel, startThreshold, repetitions, timeLimitPerCust)
end

#LNSCVRP.TestLNS("Data/X-n101-k25.vrp",0.3,0.1,1)

# TestLNS for the tuning
# function TestLNS(filename::String, destroyMaxRel::Float64, startThreshold::Float64, repetitions::Int64, timeLimitPerCust::Float64 = 0.05)
#     instance = readInstance("Data/$filename", true)
#     return TestLNS(instance, destroyMaxRel, startThreshold, repetitions, timeLimitPerCust)
# end

end
