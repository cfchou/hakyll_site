---
title: Solving Knapsack Problem in Haskell (Continued)
tags: haskell, knapsack problem, branch and bound, discrete optimization, coursera
---

Continuing my solution to the knapsack problem, I also implement _branch and
bound(BB)_ algorithm presented in the course. The result in the end was 
surprising: large test data sets, to whom _dynamic programming(DP)_ was not applicable, could be 
solved within seconds. An open question then is: what are the characteristics of 
data that make BB particularly suitable?


My first version of BB was darn slow. Even BB had the potential to drop many
unnecessary computations, on each node the estimation function just took too
much time. The naive idea was that given _n_ is the total number of items, a
_n-level_ tree will be built. For a level _i_ node the estimation function 
in the worst case could go through `n - i` items before return. 


The other problem was precision lost due to calculation on float numbers. This
is worse than inefficiency, because the optimal wouldn't be accurate at all. Such
float point calculation happens in three places:

1. Sorting items with their worth per kilo -- dividing one's value with its weight.
2. Adding part of weight of an item to complete an estimation.
3. Comparing with an estimation.


The inefficiency can be improved by by optimizing the estimation function:

1. Looking at items in a descending oder of their worth to build a tree.
2. Filter out items that have weights that are larger than the whole capacity.
3. Caching some metrics during estimation on a node, then its children can
   make use them to calculate as little as possible and of course update them 
   if necessary.
4. One immediate benefit is, for the child that represents a selecting item, 
   its estimation is exactly the same as the parent's.


For the precision lost problem, the best way to avoid it is not to use floats 
at all. I.e. 

* When comparing `v1/w1` with `v2/w2`, comparing `v1*w2` with `v2*w1` instead. 
* Using a fraction(nominator/denominator) instead of a float.


###Conclusion###

Due to the lack of experience, I found it quite difficult to debug my program 
in Haskell. There are many corner cases in my algorithm which could be easily
observed in imperative languages by embedding lots of "printf"s. In Haskell,
the closest thing I've found is `Debug.trace`. But laziness makes the execution
order of a program difficult to reason about. Therefore, the benefit of `trace` 
is limited.

As to the aspect of design pattern, my program is a bit messy since too many states 
are carried around. This is where _reader/state monads_ are good at. Moreover, I don't 
make use of _type class_ which could have been helpful.


Overall, this course _Discrete Optimization_ on Coursera is very well taught. 
Comparing to many people that can efficiently solve the problem like a whiz, 
I'm not a programming super star. But the sense of achievement was immense. 
I'm very glad for using Haskell here and probably will continue using 
it(or change to Scala) for the following assignments.

















