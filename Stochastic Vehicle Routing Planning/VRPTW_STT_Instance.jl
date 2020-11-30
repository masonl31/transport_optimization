module VRPTW_STT_Instance

include("genTravelTimes.jl")

using Random
using LinearAlgebra

export VRPTWSTTInstance, plotInstance, randInstance

mutable struct VRPTWSTTInstance
  # n: number of customers
  # node 1 to n are customers. node n+1 is the depot
  #nn (=n+1): number of nodes
  n::Int32
  nn::Int32
  Q::Int32
  # nScen number of scenarios
  nScen::Int32
  coords::Array{Float64,2}
  demand::Array{Int64,1}
  # cost matrix
  c::Array{Float64,2}
  # tt : deterministic travel time matrix
  # tts : scenarios for travel times
  tt::Array{Float64,2}
  tts::Array{Float64,3}
  # a: time window start, b: time window end
  a::Array{Int64,1}
  b::Array{Int64,1}
  # Coefficient of variation used to generate the travel time scenarios
  # (used for simulations with more scenarios)
  CoV::Float64
end
# default constructor
VRPTWSTTInstance() = VRPTWSTTInstance(1,2, 100,2,zeros(Int64,2,2), zeros(Int64,1), zeros(Float64,2,2), zeros(Float64,2,2), zeros(Float64,2,2,2), zeros(Int64,2), zeros(Int64,2),0.1 )


# n is the number of customers. Number of nodes is n+1 (called nn in VRPTWSTTInstance)
# nScen: number of nScenarios
# TWshift: determines how much time windows are "spread out",
# large values gives longer planning horizon and longer routes
# TWMin: min size of time windows
# TWMax: max size of time windows
function randInstance(n, Q, CoV, nScen, TWshift, TWMin, TWMax, seed)
  instance = VRPTWSTTInstance()
  instance.n = n
  nn =n+1
  instance.nn = nn
  instance.Q = Q
  instance.nScen = nScen
  instance.coords = zeros(Float64, nn,2)
  instance.demand = zeros(Int64, nn)
  instance.CoV = CoV
  Random.seed!(seed)
  # Generate random coordinates in the box (0,0) to (1000,1000)
  rand!(instance.coords, collect(0:1000))
  rand!(instance.demand, collect(1:30))
  # set demand of the depot to zero
  instance.demand[nn] = 0;

  # this is copy-paste from TSP example by ???
  instance.c = zeros(nn, nn)
  for i = 1:nn
      for j = i:nn
          d = norm(instance.coords[i,1:2] - instance.coords[j,1:2])
          instance.c[i,j] = d
          instance.c[j,i] = d
      end
  end

  instance.a = zeros(Int64,nn)
  instance.b = zeros(Int64,nn)

  latestArrivalDepot = 0
  for i=1:n
      # find expected arrival at customer i going straight from the depot to i (we use c to measure travel deterministic time for now)
      midPoint = instance.c[nn,i]
      midPoint += rand()*TWshift
      TWsize = TWMin + rand()*(TWMax-TWMin)
      instance.a[i] = max(0,floor(midPoint-TWsize/2))
      instance.b[i] = ceil(midPoint+TWsize/2)
  end

  #println("HERE!")
  (instance.tts, instance.tt) = generateTravelTimeScenarios(instance.coords, CoV, nScen)
  latestArrivalDepot = 0
  for i=1:n
      # when would we get to the depot if we depart at the end of the time
      # window and we consider the "worst" scenario
      arrivalDepot = instance.b[i] + maximum(instance.tts[i,nn,:])
      latestArrivalDepot = max(latestArrivalDepot,arrivalDepot)
      #println("HERE!")

  end
  instance.a[nn] = 0
  instance.b[nn] = ceil(latestArrivalDepot)
  return instance
end

end
