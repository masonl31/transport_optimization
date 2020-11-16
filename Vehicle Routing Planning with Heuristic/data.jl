n = 8 #number of customers
m = 3 #number of routes that can be selected
Q = 10 #vehicle capacity
q = [3 4 3 3 4 4 3 3] #customer demand
q1 = [0 3 4 3 3 4 4 3 3 0] #customer demand
e = [0 8 6 4 6 5 6 5 4 0] #earliest time
l = [24 16 6 20 6 19 18 19 20 24] #latest time

#travel cost
c =
[
 0   7   5   3   3   4   5   4   3   0 ;
 7   0   3   5   4  11  12  10  10   7 ;
 5   3   0   5   2   9   9   8   9   5 ;
 3   5   5   0   4   6   8   7   5   3 ;
 3   4   2   4   0   6   7   6   6   3 ;
 4  11   9   6   6   0   2   2   2   4 ;
 5  12   9   8   7   2   0   1   4   5 ;
 4  10   8   7   6   2   1   0   4   4 ;
 3  10   9   5   6   2   4   4   0   3 ;
 0   7   5   3   3   4   5   4   3   0
]

#travel time
t =
[
  0   8   6   4   4   5   6   5   4   0 ;
  8   0   4   6   5  12  13  11  11   8 ;
  6   4   0   6   3  10  10   9  10   6 ;
  4   6   6   0   5   7   9   8   6   4 ;
  4   5   3   5   0   7   8   7   7   4 ;
  5  12  10   7   7   0   3   3   3   5 ;
  6  13  10   9   8   3   0   2   5   6 ;
  5  11   9   8   7   3   2   0   5   5 ;
  4  11  10   6   7   3   5   5   0   4 ;
  0   8   6   4   4   5   6   5   4   0
]
