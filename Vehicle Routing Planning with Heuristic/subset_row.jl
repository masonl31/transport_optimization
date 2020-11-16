using Gurobi
using JuMP

a =
[
0	1	1	1	1	0	0	0	0	0	0	0
1	1	1	0	0	0	0	0	0	0	0	1
0	0	1	0	0	1	0	0	0	1	0	0
1	1	0	0	0	1	0	0	0	1	1	1
0	0	0	1	0	0	1	0	1	1	0	1
0	0	0	0	0	0	1	1	1	0	0	0
0	0	0	0	1	0	1	1	0	0	0	0
0	0	0	0	0	0	0	1	1	0	0	0
]

theta =
[
0	0	0.66667	0.333333333	0	0	0	1	0	0.333333333	0.333333333	0.333333333
]

N,R = size(a)


#Model
Subset_row_cuts = Model(Gurobi.Optimizer)

@variable(Subset_row_cuts, b[r=1:R, i=1:N, j=1:N, k=1:N], Bin)
@variable(Subset_row_cuts, sr[i=1:N,j=1:N,k=1:N] >= 0)

# @objective(Subset_row_cuts, Max, sum(b[r,i,j,k]*theta[r] for r=1:R, i=1:N, j=1:N, k=1:N))

@objective(Subset_row_cuts, Max, sum(sr[i,j,k] for i=1:N, j=1:N, k=1:N))

@constraint(Subset_row_cuts, [r=1:R,i=1:N,j=1:N,k=1:N; (a[i,r] + a[j,r] + a[k,r]) < 2 && i != j != k], b[r,i,j,k] == 0)

@constraint(Subset_row_cuts, [i=1:N,j=1:N,k=1:N], sum(b[r,i,j,k] for r=1:R if i == j) == 0)
@constraint(Subset_row_cuts, [i=1:N,j=1:N,k=1:N], sum(b[r,i,j,k] for r=1:R if i == k) == 0)
@constraint(Subset_row_cuts, [i=1:N,j=1:N,k=1:N], sum(b[r,i,j,k] for r=1:R if j == k) == 0)


@constraint(Subset_row_cuts, [i=1:N,j=1:N,k=1:N], sr[i,j,k] == sum(b[r,i,j,k]*theta[r] for r=1:R))

# just 3 customers
# @constraint(Subset_row_cuts,  sum(b[r,i,j,k] for )<= 3)

optimize!(Subset_row_cuts)

# x = sum(b[r,1,3,5]*theta[r] for r=1:R)
# println("h", value.(b[12,1,3,5]))
# println(value.(b))
println(value.(sr))

function most_violated()
    ct = 0
    for i in 1:N
        for j in 1:N
            for k in 1:N
                if value.(sr[i,j,k]) > 1.1
                    ct += 1
                    println("Customers: ", i,j,k)
                    println("SR calue: ", value.(sr[i,j,k]))
                    println("Customer combination of violated SR: ", ct)
                end
            end
        end
    end
    println("Total violated SR: ", ct/6)
end
most_violated()
