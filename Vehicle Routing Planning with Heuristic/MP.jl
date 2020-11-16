using Gurobi
using JuMP

include("data.jl")


a =
[
0	0	0	0	0	0	0	0	0	0	1	0	0	0	1	0	0	0	0	0	0	1	1	1	0
0	0	0	0	0	0	0	0	0	1	0	0	0	1	0	0	1	0	0	0	0	0	0	0	0
1	0	0	1	1	1	1	1	0	0	1	0	0	1	0	0	0	1	0	0	0	0	1	0	0
1	0	1	0	0	0	0	0	1	0	1	1	0	0	1	0	0	0	0	0	0	0	0	0	0
0	1	0	0	1	1	0	1	1	0	0	1	1	0	0	1	0	0	0	0	0	0	0	0	1
1	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	1	1	0	1	1	0	0	0	1
0	1	1	1	1	0	1	0	0	1	0	0	0	0	0	1	0	0	1	1	0	1	0	0	0
0	1	1	1	0	1	1	1	0	1	0	0	1	0	0	0	0	0	1	0	1	0	0	1	0
]

c =
[
35	19	30	28	26	25	31	32	13	37	27	13	9	13	14	10	19	16	11	10	12	21	15	20	11
]

R = length(c)

#Model
MP = Model(Gurobi.Optimizer)

@variable(MP, theta[1:R] >=0)

@objective(MP, Min, sum(c[r]*theta[r] for r=1:R))

@constraint(MP, customervisit[i=1:n], sum(a[i,r]*theta[r] for r=1:R) == 1) #each customer can only be visited once

@constraint(MP, maxroutes, sum(theta[r] for r=1:R) <= m)

optimize!(MP)


has_duals(MP)

println("Routes ", value.(theta))

#println("dual of customers ", dual.(customervisit))
#println("dual of max routes ", dual.(maxroutes))

dual1 = dual.(customervisit)
dual2 = dual.(maxroutes)
dualtoPP = [0 transpose(dual1) dual2]

c_r_hat = zeros(R)
for r in 1:R
    c_r_hat[r] = c[r] - sum(a[i,r]*dual1[i] for i=1:n) - dual2
end
#println("c_r_hat values ", value.(c_r_hat))

println("Duals to PP ", dualtoPP)
