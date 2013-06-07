---
title: Builder and CanBuildFrom in map
---

In the collection library, _CanBuildFrom_ creates _Builder_. Many functions in
implementation traits like TraversableLike use _CanBuildFrom_ to generate the
right kind of _Builder_ to create an adequate collection.



Following previous posts, there's a trivial function _foo_ in QLike which looks like:

  trait QLike[+A, +Repr]
    extends HasNewBuilderRepr[A, Repr] {
    def foo[B, That](q: B)(implicit cbf: CBF[Repr, B, That]): Int = 0
    ...
  }

In [this post](), I stated that the found implicit _CBF_ will then help 
to infer foo's type parameter _That_ but we couldn't really tell in this case
as _That_ is not used anywhere. A better example is _map_ in TraversableLike.
Likewise, I implement _map_ for the Q collection.


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

'Repr', as it appears so often in the code as type parameters, I haven't talk 
about it yet. It is the __initial__ type that __Repr__esents the underlying object. 
If running _Q2(1, 2, 3)_ in REPL, 
    
    scala> Q1(1,2,3)
    res0: Q1[Int] = QArrBuf@7e5ccc

_Q2[Int]_ is the type argument for _Repr_ appear in relevant 
traits/classes, e.g.

    HasNewBuilderRepr[A, Repr]  ---   HasNewBuilderRepr[Int, Q2[Int]]
    QLike[A, Repr]              ---   QLike[Int, Q2[Int]]

And here we have _repr_ as the _this pointer typed as_ _Repr_ which can be passed
into functions that want _Repr_.

Next 














###Reference###
http://stackoverflow.com/questions/5200505/how-are-scala-collections-able-to-return-the-correct-collection-type-from-a-map/5200633#5200633
