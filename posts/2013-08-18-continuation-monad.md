---
title: CPS and Continuation Monad
tags: haskell, continuation, monad, CPS
---

I recently stumbled across an article on FPComplete: "The Mother of all
Monads"[1].
To completely grasp what it's all about, I thought I should first look into continuation
monad's definition in Haskell and explore how it's come about. I would give my two cents in this article.

On wikipedia[2] it reads, 

    A function written in "continuation-passing style(CPS)" takes an extra argument:
    an explicit "continuation" i.e. a function of one argument. 
    When the CPS function has computed its result value, it "returns" it by calling
    the continuation function with this value as the argument.

The technique to convert a function to its CPS counterpart is to __make up a lambda as a new continuation__ at every descending level:

    -- factorial
    fact :: Int -> Int
    fact n
        | n <= 1 = n
        | otherwise = n * (fact (n - 1))

    -- factorial in CPS
    factCPS :: Int -> (Int -> a) -> a
    factCPS n k
        | n <= 1 = k n
        | otherwise = factCPS (n - 1) $ \x -> k (n * x)


Here's how it'll span:

    factCPS 3 show                                  -- k == show
    factCPS 2 $ \x -> show (3 * x)                  -- k == \x -> show (3 * x)
    factCPS 1 $ \y -> (\x -> show (3 * x)) (2 * y)  -- k == \y -> ...
    (\y -> (\x -> show (3 * x)) (2 * y)) 1
    (\x -> show (3 * x)) (2 * 1))
    show (3 * (2 * 1))


Every function can be turned into CPS. Here's a contrived example:

    sq :: Int -> Int
    sq n = n ^ 2

    -- dSq n == 2 * (n ^ 2)
    dSq :: Int -> Int
    dSq n = 2 * (sq n)

    -- bDsq n == 2 * (n ^ 2) > 10 * n
    bDsq :: Int -> Bool
    bDsq n = dSq n > 10 * n

    -- squareCPS n k == k $ n ^ 2
    sqCPS :: Int -> (Int -> a) -> a
    sqCPS n k = k $ n ^ 2

    -- doubleSquareCPS n k == k $ 2 * (n ^ 2)
    dSqCPS :: Int -> (Int -> a) -> a
    dSqCPS n k = sqCPS n $ \i -> k (2 * i)


    -- bigDoubleSquareCPS n k == k $ 2 * (n ^ 2) > 10 * n
    bDsqCPS :: Int -> (Bool -> a) -> a
    bDsqCPS n k = dSqCPS n $ \i -> k (i > 10 * n)

Like `factCPS`, a lambda is created as a new continuation at every descending level.
A pattern can be observed:

    outterFunc n k = innerFunc (p n) $ \x -> k (q n x)

where `\x -> k (q n x)` is a continuation devised for `innerFunc`.
`p`, `q` are functions that contains the logic that `outterFunc` knows about, e.g:

    factCPS n k =
        | n <= 1 = k n
        | otherwise =
            let p n' = n' - 1
                q n' a = n' * a
            in  factCPS (p n) \i -> k (q n i)

    bDsqCPS n k = 
        let p = id
            q n' a = a > 10 * n'
        in  dSqCPS (p n) $ \i -> k (q n i)


Examples above are nesting functions. With a little twist, a sequential program block acts the same as a nesting function.
Since the rest of code follows a statement can be seen as a big function that takes the
output of the statement as the input. This logic applies recursively to
every statement all the way down:

    -- a sequential code block
    funcS :: n -> b
    funcS n =
        a = func1 n  -- func1 :: n -> a
        func2 a      -- func2 :: a -> b

    -- converted to a nesting function
    run f n k = k . f n
    funcN n =
        run func1 n (\a -> func2 a)
    
For example, `bDsq` in sequential form would be:

    bDsqS n =
        n1 = n ^ 2      -- n1 == Sq n, innermost computation
        n2 = n1 * 2     -- n2 == dSq n
        n2 > n * 10

`bDsq`'s innermost computation `Sq` turns out to be the first statement. Every
following statement __adds up a layer of computation__ to form an outer nested function.

The sequential `bDsqS` gets converted to a nesting `bDsqN`:
    
    bDsqN n =
        run (^ 2) n (\i1 ->
            run (* 2) i1 (\i2 -> i2 > n * 10))
 

The CPS version of a nesting-converted function `funcN` would be:

    funcNCPS :: n -> (b -> r) -> r
    funcNCPS n k = 
        run func1 n (\a ->    --- func1 :: n -> a
            run func2 a k)    --- func2 :: a -> b

Look at `run func1 n` and `run func2 a`: 

    run func1 n :: (a -> r) -> r
    run func2 a :: (b -> r) -> r

* They are computations that each of which expects a continuation and passes the result to it.
* The latter sits inside the continuation passed to the former, therefore `a`
  is a bound variable which represents the result of the former.

__Continuation Monad__ captures this idea and use `Cont` to encapsulate such
computation:

    -- a context in which a computation expects a "continuation".
    newtype Cont r a = Cont { runCont :: (a -> r) -> r } 

The following pseudo is somewhat sloppy, but I hope the idea is correct.
As we only care about how computations interact with continuations, not the
computations themselves, we wrap a computation as a `Cont`.

    m = Cont (run func1 n)           -- m :: Cont r a

    f = \a -> Cont (run func2 a)     -- f :: a -> Cont r b

Substitute them for what's in `funcNCPS`:

    funcNCPS n = \k ->               -- funcNCPS :: n -> (b -> r) -> r
        runCont m (\a -> runCont(f a) k))

Observing that `funcNCPS n` is a computation expecting a continuation, so why not wrap it as a
`Cont`:

    m' = Cont (funcNCPS n)           -- m' :: Cont r b
       = Cont $ \k ->
           runCont m (\a -> runCont(f a) k))

There you go. This is what `>>=` of `Cont` is defined as:

    (>>=) :: Cont r a -> (a -> Cont r b) -> Cont r b
    m >>= f =
       = Cont $ \k ->
           runCont m (\a -> runCont(f a) k))


This article: "The Continuation Monad]"[4] has a few examples of how continuation monad helps in real world applications.



###Reference###

1. [Mother of All Monads](https://www.fpcomplete.com/school/advanced-haskell-1/the-mother-of-all-monads)
2. [Continuation-passing style](http://en.wikipedia.org/wiki/Continuation-passing_style)
3. [Haskell/Continuation passing style](http://en.wikibooks.org/wiki/Haskell/Continuation_passing_style)
4. [The Continuation Monad](http://www.haskellforall.com/2012/12/the-continuation-monad.html)
5. [Tutorial to disassemble the Haskell Cont monad?](http://stackoverflow.com/questions/3322540/tutorial-to-disassemble-the-haskell-cont-monad)




