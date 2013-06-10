---
title: Builder and CanBuildFrom in map
tags: scala, Builder, CanBuildFrom
---

In the collection library, `CanBuildFrom` is a way of getting `Builder`. Many 
functions in implementation traits like `TraversableLike` use `CanBuildFrom` to 
get the right kind of `Builder` to create an adequate collection.


In previous posts, there's a trivial function `foo` in `QLike` which looks like:

    trait QLike[+A, +Repr]
      extends HasNewBuilderRepr[A, Repr] {
      def foo[B, That](q: B)(implicit cbf: CBF[Repr, B, That]): Int = 0
      ...
    }

In [this post](./2013-05-11-polyglot-canbuildfrom.html), I stated that the 
found implicit `CBF` will then help 
to infer `foo`'s type parameter `That` but we couldn't really tell in the case
because `That` is not used anywhere. A better example is `map` in 
`TraversableLike`. Likewise, I implement `map` for the Q collection.


    trait QLike[+A, +Repr]
      extends HasNewBuilderRepr[A, Repr] {
      ...

      // cast 'this' to Repr
      def repr: Repr = this.asInstanceOf[Repr]

      def map[B, That](f: A => B)(implicit bf: CBF[Repr, B, That]): That = {
        val b = bf(repr)  // Budr[B, That]
        for (x <- this) b += f(x)
        b.result
      }
    }

`Repr`, as it appears so often in the code as a type parameter, I haven't 
really talked about it yet. Conventionally, It names the _initial_ type that 
__Repr__esents the underlying storage. That is, if running `Q2(1, 2, 3)` in 
REPL: 
    
    scala> Q1(1,2,3)
    res0: Q1[Int] = QArrBuf@7e5ccc

`Q2[Int]` is the type argument for _Repr_s appearing in relevant 
traits/classes, e.g.

    HasNewBuilderRepr[A, Repr]  --->   HasNewBuilderRepr[Int, Q2[Int]]
    QLike[A, Repr]              --->   QLike[Int, Q2[Int]]

Here in `QLike` there is `def repr` as _"this" object typed as_ `Repr`. `repr` 
can be passed into functions that want `Repr`.

Following `repr` is `map`'s definition. At the beginning, a `Budr` is obtained 
by calling `apply` on the implicit `CBF`. `apply` and other relevant snippets
are following:

    trait CBF[-Fr, -Elm, +To] {
      def apply(from: Fr): Budr[Elm, To]
    }
  
    trait QFac[CC[X] <: Q1[X] with QTmpl[X, CC]]
      extends QCompanion[CC] {
      ...
  
      class GCBF[A] extends CBF[CC[_], A, CC[A]] {
        def apply(from: Coll) = from.genericBuilder[A]
      }
      ...
    }

    trait QCompanion[+CC[_]] {
      type Coll = CC[_] 
      ...
    }

    object Q1 extends QFac[Q1] {
      // was CBF[Q1[_], A, Q1[A]]
      implicit def cbf[A]: CBF[Coll, A, Q1[A]] =
        reusableGCBF.asInstanceOf[GCBF[A]]
      ...
    }


There's a twist in the nested class `GCBF` that extends CBF.
`Coll` preserves `QCompanion`'s type parameter. For instance, `Coll` in 
`QCompanion[Q1]` would be `Q1[_]` or `Q1[Any]`.

`genericBuilder` is a newly added members in `QTmpl` that calls a companion
object's `newBuilder`:

    trait QTmpl[+A, +CC[X] <: Q1[X]]
      extends HasNewBuilderRepr[A, CC[A] @uncheckedVariance] {
  
      def companion: QCompanion[CC]
      protected[this] def newBuilderRepr: Budr[A, CC[A]] = companion.newBuilder[A]
  
      def genericBuilder[B]: Budr[B, CC[B]] = companion.newBuilder[B]
    }

Comparing `newBuilderRepr` with `genericBuilder`, the latter is a polymorphic
method that gives a `Budr` for _elements of another type_.

To dot to i's and cross the t's, it's easier to look at a real case. 

    scala> Q2(1, 2, 3) map ("s" * _)
    res9: Q1[String] = QArrBuf@1f68406c

In this case, `QLike` is parameterized as QLike[Int, Q2[Int]], so `Repr` 
is `Q2[Int]`. Leave `That` untouched at the moment, the parameterized _map_ is:

    def repr: Q2[Int] = ...

    def map[String, That](f: Int => String)
      (implicit bf: CBF[Q2[Int], String, That]): That = {
      val b = bf(repr)  // Budr[String, That]
      ...
    }


As object Q2 doesn't provide an implicit `CBF`, implicit lookup searches the
companion object of Q2's superclass, Q1, and happily finds one. 

    required: CBF[Q2[Int], String, Any]
              =>  apply(from: Q2[Int]): Budr[String, Any]

    found:    CBF[Q1[_], String, Q1[String]]
              =>  apply(from: Coll), _Coll_ is Q1[_] 
              =>  apply(from: Q1[Any]): Budr[String, Q1[String]] =
                    from.genericBuilder[String] 

As what's found conforms what's required in terms of variance.
It's perfectly legal to pass `repr: Q2[Int]` to 
`apply(from: Q1[Any]): Budr[String, Q1[String]]`.
Therefore _`from` is actually an `Q2[Int]` object_. It dynamically
dispatches to `Q2[Int].genericBuilder[String]` and successively
`Q2.newBuilder[String]` which is returned as `val b: Budr[String, Q1[String]]`.

Then the following steps are simple. 
Run the mapping function on all elements in the current Q2 collection. Copy 
results into `Budr b` elements. Eventually `Budr b` gives a Q1 collection.

`map` a function over a Q2 collection gives a Q1 collection? This doesn't sound 
good enough.
_map_ in Q collection can do more to retain the collection's dynamic type. I 
would expect Q2's `map` to return a Q2 collection instead of Q1. This flaw is 
due to no suitable `CBF` in Q2 companion so one in Q1 companion is used.  This 
can be fixed:

    object Q2 extends QFac[Q2] {
      implicit def cbf[A]: CBF[Coll, A, Q2[A]] =
        reusableGCBF.asInstanceOf[GCBF[A]]
      ...
    }

Test it in REPL:

    scala> Q2(1, 2, 3) map ("s" * _)
    res0: Q2[String] = QArrBuf@b98df1f

The _implicit lookup_ would find it instead and give a `Budr[String,
Q2[String]]`

    found:    CBF[Q2[_], String, Q2[String]]
              =>  apply(from: Coll), _Coll_ is Q2[_] 
              =>  apply(from: Q2[Any]): Budr[String, Q2[String]] =
                    from.genericBuilder[String] 



###Difference between map and filter###
Note the difference between `map` and
[filter](./2013-05-13-builder-in-filter.html) in what's returned. 
When `filter/map` a predicate/function over a collection A to get a collection 
B:

* `filter`:
    + static type(underlying storage's type) doesn't change.
    + dynamic type(the type of collection and type of elements) doesn't change.
* `map`:
    + static type may change but should have a good reason.
    + dynamic type
        - the type of collection may change but should have a good reason.
        - the type of elements can change depending on the mapping function.

These differences lead to different way of getting `Budr`. Specifically, 
`filter` doesn't need an implicit `CBF` as it always builds the same collection.

    def filter(p: A => Boolean): Repr = {
      val bdr = newBuilderRepr
      ...
    }

On the other hand, because `map` might be supplied with a customized implicit 
`CBF` rather than the one found in a companion object, what `map` can do is 
to pass the original collection as `from: Repr`, to `CBF`'s `apply(from)`.
This customized `CBF` can work on original collection's `Budr` if it
wants. 


###to[CC[_]]###
There are situations where an implicit `CBF`'s `apply` doesn't use the original
collection. 


One such case is `TraversableLike`'s `to[CC[_]]` which is now added to
QLike as well. 

    trait QLike[+A, +Repr]
      extends HasNewBuilderRepr[A, Repr] {

      ...
      def to[CC[_]]
        (implicit bf: CBF[Nothing, A, CC[A @uncheckedVariance]])
        : CC[A @uncheckedVariance] = {
        val b = bf()  // Budr[A, CC[A @ uncheckedVariance]]
        for (x <- this)
          b += x
        b.result
      }
    }

What it does is to converts this Q collection into another by copying all 
elements. This _apply_ called on _CBF_ doesn't require _repr_ as an argument 
here. It implies that _CBF_ can generate Budr on its own.
Another _apply_ is be added to _CBF_ to support this semantics.

    trait CBF[-Fr, -Elm, +To] {
      def apply(from: Fr): Budr[Elm, To]
      def apply(): Budr[Elm, To]
    }

    trait QFac[CC[X] <: Q1[X] with QTmpl[X, CC]]
      extends QCompanion[CC] {
  
      class GCBF[A] extends CBF[CC[_], A, CC[A]] {
        // element type is flexible
        def apply(from: Coll) = from.genericBuilder[A]
        def apply() = newBuilder[A]
      }
      ...
    }

In the case of converting Q2 to Q1:

    scala> val q2 = Q2(1, 2, 3)
    q2: Q2[Int] = QArrBuf@1c54f78

    scala> q2.to[Q1]
    res3: Q1[Int] = QArrBuf@15884bf

Implicit is looked up as such:

    required: CBF[Nothing, Int, Q1[Any]]
              =>  apply(from: Nothing): Budr[Int, Q1[Int]]

    found:    CBF[Q1[_], Int, Q1[Int]]
              =>  apply(): Budr[Int, Q1[Int]] = newBuilder[Int] 

Here is the interesting thing. _"That"_ can be decided to be _Q1[Any]_ in
what's required this time, so that implicit lookup knows Q1's companion is the 
place to look at.


Q2[Int] to Q1[Int] is simple, but how about Q2[Int] to List[Int]? 
Although List is not part of the Q hierarchy, converting to List still can be 
achieved by supplying a customized CBF.

    scala> q2.to[List]
    <console>:21: error: could not find implicit value for parameter bf:
        CBF[Nothing,Int,List[Int]] q2.to[List]

    scala> implicit def lst_cbf[A] = new CBF[Q1[A], A, List[A]] {
         |   def apply(from: Q1[A]): Budr[A, List[A]] = apply()
         |
         |   def apply(): Budr[A, List[A]] = 
         |     Q1.newBuilder[A] mapResult { oldTo =>
         |       var newTo = List.empty[A]
         |       for (x <- oldTo)
         |         newTo = newTo :+ x  // inefficient
         |       newTo
         |     }
         | }

    scala> q2.to[List]
    res4: List[Int] = List(1, 2, 3)

_lst_cbf_ allows Q1 or Q2 of any type to be converted to a List of that type.
Its _apply(from)_ doesn't use _from_ at all. Note that _lst_cbf_ bring a side
effect that _map_ over Q unexpectedly returns a List too:

    scala> q2 map ("s" * _)
    res7: List[Any] = List(s, ss, sss)

I think it's probably a better idea that I shouldn't mark lst_cbf as implicit
and only pass it explicitly when needed.










###Reference###
http://stackoverflow.com/questions/5200505/how-are-scala-collections-able-to-return-the-correct-collection-type-from-a-map/5200633#5200633
