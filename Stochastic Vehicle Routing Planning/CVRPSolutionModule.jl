module CVRPSolutionModule

using Gadfly

using ..CVRPInstanceModule

export CVRPRoute, CVRPSolution, clear, recalcRouteCost, plotSol, recalcSolCost, plotSolution

mutable struct CVRPRoute
  cost::Float64
  totalLoad::Int32
  theRoute::Array{Int32,1}
end

mutable struct CVRPSolution
  cost::Float64
  routes::Array{CVRPRoute,1}
  unassigned::Array{Int32,1}
end

function clear(sol::CVRPSolution, inst::CVRPInstance)
  sol.cost = 0
  sol.routes = []
  sol.unassigned = collect(1:inst.n)
end

# constructor for CVRPRoute
# Creates a route with one customer
CVRPRoute(customer, inst::CVRPInstance) = CVRPRoute(inst.c[inst.nn, customer] + inst.c[customer, inst.nn],inst.demand[customer],[inst.nn, customer, inst.nn])
# Creates an empty route
CVRPRoute(inst::CVRPInstance) = CVRPRoute(0,0,[inst.nn, inst.nn])

function recalcRouteCost(route::CVRPRoute, inst::CVRPInstance)
  cost = 0
  if length(route.theRoute) >= 2
    for i=2:length(route.theRoute)
      cost += inst.c[route.theRoute[i-1], route.theRoute[i]]
    end
  end
  route.cost = cost
end

function recalcSolCost(sol::CVRPSolution, inst::CVRPInstance)
    sol.cost = 0;
    for r in sol.routes
        recalcRouteCost(r, inst)
        sol.cost += r.cost
    end
end

function plotSolution(sol::CVRPSolution, inst::CVRPInstance)
  # Plot coordinates:
  p = plot(
        layer(x=inst.coords[:,1], y=inst.coords[:,2], Geom.point, Theme(default_color=colorant"red")),
        Coord.cartesian(fixed=true), Theme(panel_fill=colorant"white", background_color=colorant"white")
    )
  # Plot Routes:
  for r in sol.routes
    pathX = Vector{Float64}()
    pathY = Vector{Float64}()
    for node in r.theRoute
      push!(pathX, inst.coords[node,1])
      push!(pathY, inst.coords[node,2])
    end
    append!(p.layers, layer(x=pathX, y=pathY, Geom.path))
  end
  display(p)
end

end
