using Distributions

# function generateTravelTimeScenarios(coords::Array{Float64,2}, CoV::Float64, nScenarios::Int64)
# ** coords **: The coordinates of all nodes
# ** CoV **: Coefficient of variation. Let mu be the mean and sigma the standard
# deviation of a random variable. Then the CoV is defined as
# CoV  = sigma / mu.
# When CoV and mu are given then we can use the formula to compute sigma
# ** nScenarios **: number of scenarios to generate.
#
# The function generates nScenarios. In each scenario the travel time from i to j
# is generated using a truncated normal distrubution with mean tt[i,j]
# where tt[i,j] is the deterministic travel time.
# The distribution is truncated to avoid negative travel times.
#
# The function returns two arrays. Let's call them tts and tt
# tts is three dimensional array and
# tts[i,j,s] contain the travel time from i to j in scenario s
# tt is a two dimensional array and tt[i,j] contains the deterministic travel time from i
# to j
#
# Example of use:
# Define coordinates:
# x=[ 1.0 2; 3 4; 5 6; 1 7]   #(x now contains 4 coordinates)
#
# call function:
# (tts, tt) = generateTravelTimeScenarios(x, 0.1, 3)
#
# tts now contains 3 scenarios. I got:
# [:, :, 1] =
# 0.0      3.20657  5.61548  4.62727
# 2.48334  0.0      2.81339  3.54601
# 4.46022  2.80954  0.0      4.62714
# 5.28385  3.88083  4.27921  0.0
#
#[:, :, 2] =
# 0.0      2.64582  5.28087  4.09849
# 2.46383  0.0      2.7336   3.63096
# 5.8502   3.31921  0.0      4.65907
# 5.10318  3.2418   3.77262  0.0
#
#[:, :, 3] =
# 0.0      3.14787  4.89401  5.62015
# 2.81269  0.0      3.04322  3.59464
# 5.4526   2.26068  0.0      3.88856
# 4.42519  4.28362  3.51675  0.0
#
# and tt contains:
# 0.0      2.82843  5.65685  5.0
# 2.82843  0.0      2.82843  3.60555
# 5.65685  2.82843  0.0      4.12311
# 5.0      3.60555  4.12311  0.0

function generateTravelTimeScenarios(coords::Array{Float64,2}, CoV::Float64, nScenarios::Int64)
  nn = size(coords,1)

  # generate pure travel times (no stochasticity)
  tt = zeros(nn, nn)
  for i = 1:nn
      for j = i:nn
          d = norm(coords[i,1:2] - coords[j,1:2])
          tt[i,j] = d
          tt[j,i] = d
      end
  end
  # Generate samples
  tts = zeros(nn, nn, nScenarios)
  for s = 1:nScenarios
      for i = 1:nn
          for j = 1:nn
              # Compute standard deviation based on travel time and CoV
              sigma = tt[i,j]*CoV
              if sigma == 0
                  t = tt[i,j]
              else
                  t = rand(truncated(Normal(tt[i,j], sigma), 0, Inf))
              end
              tts[i,j,s] = t
          end
      end
  end
  return (tts, tt)
end
