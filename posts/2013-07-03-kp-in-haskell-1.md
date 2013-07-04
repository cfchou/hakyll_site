---
title: Solving Knapsack Problem in Haskell
tags: haskell, knapsack problem, dynamic programming, discrete optimization, coursera
---

[tl;dr](http://stackoverflow.com/questions/17346161/anything-prevents-optimizing-tail-recursion)

The first assignment of the course Discrete Optimization is to solve a _0-1 
knapsack problem_. For every data set, a valid output would be a optimal value 
and the combination of items that produce it. This can be approached by 
two algorithms presented in the lecture. One is _dynamic programming(DP)_, the 
other is _branch and bound(BB)_.

My first attempt was to use DP as I had done a similar task before. To sharpen
my functional programming skill and to get more fun(or frustration), I decided
to give Haskell a go.

I had done a preliminary implementation to get the optimal using the [array
package](http://hackage.haskell.org/package/array) in the past. This time I chose to use 
the [vector package](http://hackage.haskell.org/package/vector). The upside of
it is its likeness to list so that I have all the good old friends like 
map/filter/fold/zip/......, etc., in place. 

    import Data.Vector (Vector, (!))
    import qualified Data.Vector as V


###Whole Table###

While building a table in DP, I saw the benefit of _laziness_ in Haskell. 
Say I have a function `initTable` which builds a table row by row, 
I can do something like

    // create table 
    let tbl = initTable k vs ws tbl
    in  ...

    initTable :: Int -> Vector Int -> Vector Int -> Vector (Vector Int) -> Vector (Vector Int)

`k` is the knapsack's capacity `vs` and `ws` are values and weights of items.
`tbl` is the table being built. This code relies on two fact:

1. The values in every row being built only depend on the values in previous 
rows, `tbl` can safely refer to itself. 
2. Since `initTable` is __not strict on its variables__, only part of
`tbl`("dependee" if you like) gets evaluated inside `initTable`.  


That's all very well if the problem is small or you like to easily backtrack
what items can be selected into the knapsack.


###One Row###
For problems like trying to fit 1000 items in a knapsack of max weight of 
1000000, the memory usage can easily go up to GBs. A more sensible way is to
rely on the fact that the values in every row being built only depend on the
values in _the previous row_. Therefore, all other previous rows can be thrown
away and only a constant size memory is used on the way. 

    let row = initRow k vs ws

    initRow k vs ws = itbl 1 $ V.replicate (k + 1) 0
        where n = V.length vs
              itbl i row
                   | i > n = row
                   | otherwise = itbl (i + 1) $
                                      V.generate (k + 1) gen
                   where gen w = ...  -- generate value base on row


`itbl` is the helper that creates a new row based on a given one and it behaves 
in a tail-recursive fashion. However, the memory consumption keeps growing 
as proceeding to the next row. It seems that nothing is thrown away and
garbage-collected. 

Turned out that it was where I got bitten by _laziness_. Since
`Vector.replicate/Vector.generate` don't get fully evaluated, a lager _thunk_
just gets carried into `itbl` every recursion. Virtually nothing is thrown away.

The way to deal with this problem is obvious -- forcing 
`Vector.replicate/Vector.generate` fully evaluated to a value.

I was suggested two ways[1]. One was to use the `DeepSeq.($!!)` instead of `($)`.
The other was to use `Vector.Unbxed` module instead of `Vector`. I chose the
former and it worked very well. 


###Tracking Items###

Whilst one-row solution saves me the memory, it is impossible to backtrack what
items are selected. As the result, I do bookkeeping for the chosen items on the 
way of building a row. An useful data structure here is lined list.

Note that in the worst scenario, the linked lists would still cover all items 
and the memory consumption would still be large. In fact, 2 out of 6 data sets 
drained the memory on my 32-bit Linux box during submission. I'm sure there are some 
optimization techniques that can remedy this problem, but I didn't investigate 
more as I thought BB might be able to tackle this.




###Reference###
1. [Anything prevents optimizing tail-recursion?](http://stackoverflow.com/questions/17346161/anything-prevents-optimizing-tail-recursion)






