using AlgoTuner


include("LNS-CVRP.jl")

function getBestKnownValues()
    instances = ["X-n125-k30.vrp", "X-n261-k13.vrp"]
    bestKnown = Dict{String,Float64}()
    for inst in instances
        bestKnown[inst] = LNSCVRP.TestLNS(inst,0.3,0.1,1)
    end
    return instances, bestKnown
end

benchmark,bestKnown = getBestKnownValues()


#Original function
#SA("TSP/tsp_fun.tsp",2,1234,1000.0,0.9999999)

function TSP_SA(seed, instance, destroyMaxRel, startThreshold)
    destroyMaxRel_value = Dict(
    1 => 0.21,
    2 => 0.23,
    3 => 0.25,
    4 => 0.27,
    5 => 0.29,
    6 => 0.31
    )
    startThreshold_value = Dict(
    1 => 0.08,
    2 => 0.07,
    3 => 0.06,
    4 => 0.05,
    5 => 0.04,
    6 => 0.03
    )
    return (LNSCVRP.TestLNS(instance, destroyMaxRel_value[destroyMaxRel],
    startThreshold_value[startThreshold], 1) - bestKnown[instance])/bestKnown[instance]
end
# TSP_SA(seed, instance, T, alpha, test) =
#         (LNS(instance,2,seed,T,alpha, test) - bestKnown[instance])/bestKnown[instance]

cmd = AlgoTuner.createRuntimeCommand(TSP_SA)

AlgoTuner.addIntParam(cmd,"destroyMaxRel",1,6)
AlgoTuner.addIntParam(cmd,"startThreshold",1,6)

#AlgoTuner.addInitialValues(cmd,[1,1,1])

AlgoTuner.tune(cmd,benchmark,7290,3,[1234,5432,5467],AlgoTuner.ShowAll)
