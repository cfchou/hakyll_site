---
title: Builder and CanBuildFrom in map
---

In the collection library, _CanBuildFrom_ is a way of creating _Builder_. Many 
functions in implementation traits like _TraversableLike_ use _CanBuildFrom_ to 
generate the right kind of _Builder_ to create an adequate collection.


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

'Repr', as it appears so often in the code as a type parameter, I haven't talked 
about it yet. Conventionally, It names the __initial__ type that __Repr__esents 
the underlying storage. That is, if running _Q2(1, 2, 3)_ in REPL, 
    
    scala> Q1(1,2,3)
    res0: Q1[Int] = QArrBuf@7e5ccc

_Q2[Int]_ is the type argument corresponding to _Repr_s appearing in relevant 
traits/classes, e.g.

    HasNewBuilderRepr[A, Repr]  --->   HasNewBuilderRepr[Int, Q2[Int]]
    QLike[A, Repr]              --->   QLike[Int, Q2[Int]]

Here in QLike there is _"repr"_ as the _"this" object typed as_ _Repr_. It can 
be passed into functions that want _Repr_.

Following _repr_ is _map_'s definition. At the beginning, a _Budr_ is obtained 
by calling _apply_ on the implicit _CBF_. _apply_ and other relevant snippets
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
j     ...
    }


It can be seen there's a twist in the nested class _GCBF_ that extends CBF.
_Coll_ preserves _QCompanion_'s type parameter. For instance, _Coll_ in 
_QCompanion[Q1]_ would be _Q1[_]/Q1[Any]_.

_genericBuilder_ is a newly added members in _QTmpl_ that calls a companion
object's _newBuilder_.

    trait QTmpl[+A, +CC[X] <: Q1[X]]
      extends HasNewBuilderRepr[A, CC[A] @uncheckedVariance] {
  
      def companion: QCompanion[CC]
      protected[this] def newBuilderRepr: Budr[A, CC[A]] = companion.newBuilder[A]
  
      def genericBuilder[B]: Budr[B, CC[B]] = companion.newBuilder[B]
    }

Comparing _newBuilderRepr_ with _genericBuilder_, the latter is a polymorphic
method that gives a _Budr_ for __elements of another type__.

To dot to i's and cross the t's, it's easier to look at a real case. 

    scala> Q2(1, 2, 3) map ("s" * _)
    res9: Q1[String] = QArrBuf@1f68406c

In this case, QLike is parameterized as QLike[Int, Q2[Int]], so _Repr_ is Q2[Int].
Leave _That_ untouched at the moment, the parameterized _map_ is:

    def repr: Q2[Int] = ...

    def map[String, That](f: Int => String)
      (implicit bf: CBF[Q2[Int], String, That]): That = {
      val b = bf(repr)  // Budr[String, That]
      ...
    }


As object _Q2_ doesn't provide an implicit _CBF_, implicit lookup searches the
companion object of _Q2_'s superclass, _Q1_, and happily finds one. 

    required: CBF[Q2[Int], String, Any]
              =>  apply(from: Q2[Int]): Budr[String, Any]

    found:    CBF[Q1[_], String, Q1[String]]
              =>  apply(from: Coll), _Coll_ is Q1[_] 
              =>  apply(from: Q1[Any]): Budr[String, Q1[String]] =
                    from.genericBuilder[String] 

As what's found conforms what's required in terms of variance.
It's perfectly legal to pass "_repr: Q2[Int]_" to 
"_apply(from: Q1[Any]): Budr[String, Q1[String]]_".
Therefore __"from" is actually an Q2[Int] object__. It dynamically
dispatches to _Q2[Int].genericBuilder[String]_ and in the end
_Q2.newBuilder[String]_ which is returned as "_val b: Budr[String, Q1[String]]_".

Then the following steps are simple. _Budr b_ copies(_+=_) elements in the current Q2
collection and eventually gives a Q1 collection.

_map_ a function over a Q2 collection gives a Q1 collection? This doesn't sound 
good enough.
_map_ should do its best to retain the collection's dynamic type. I would
expect _map_ to return a Q2 collection. This flaw is due to no suitable
_CBF_ in Q2 companion so _CBF_ in Q1 companion is used. This can be fixed:

    object Q2 extends QFac[Q2] {
      implicit def cbf[A]: CBF[Coll, A, Q2[A]] =
        reusableGCBF.asInstanceOf[GCBF[A]]
      ...
    }

Test it in REPL:

    scala> Q2(1, 2, 3) map ("s" * _)
    res0: Q2[String] = QArrBuf@b98df1f

The implicit lookup would find it instead and give a Budr[String, Q2[String]].

    found:    CBF[Q2[_], String, Q2[String]]
              =>  apply(from: Coll), _Coll_ is Q2[_] 
              =>  apply(from: Q2[Any]): Budr[String, Q2[String]] =
                    from.genericBuilder[String] 





###Difference between map and filter###
Note the difference between _map_ and [_filter_]() in what's returned. 
When _filter/map_ a predicate/function over a collection A to get a collection B:

* _filter_:
    + static type(underlying storage's type) doesn't change.
    + dynamic type(the type of collection and type of elements) doesn't change.
* _map_:
    + static type may change
    + dynamic type
        - the type of collection may change but should have a good reason.
        - the type of elements can change depending on the mapping function.

These differences lead to different way of getting _Budr_. Specifically, 
_filter_ doesn't use an implicit _CBF_ as it always builds the same collection 
from its own Budr.

    def filter(p: A => Boolean): Repr = {
      val bdr = newBuilderRepr
      ...
    }

On the other hand, because _map_ might be supplied with a customized implicit 
_CBF_ rather than the one found in the companion object, what it can do is 
to pass the original collection, typed as _Repr_, to _CBF_'s apply(from). This 
customized _CBF_ may/should in turn use original collection's _Budr_. 

What follows is a "bad" example. It's bad because one, it doesn't use original
collection's Budr, and two, it doesn't make much sense:

    scala> Q2(1, 2, 3) map ("s" * _)
    res0: Q2[String] = QArrBuf@b98df1f

    scala>   implicit val bad_cbf = new CBF[Q2[_], String, Q1[String]] {
         |     def apply(from: Q2[_]): Budr[String, Q1[String]] = {
         |       // doesn't use "from"
         |       Q1.newBuilder[String]
         |     }
         |   }
    bad_cbf: CBF[Q2[_],String,Q1[String]] = $anon$1@6e99175d

    scala> Q2(1, 2, 3) map ("s" * _)
    res1: Q1[String] = QArrBuf@25ddfb6a

This _bad___cbf_ ruins the previous effort in making _map_ returning the same Q2 
collection.

Sometimes, this behaviour does make sense. For instance:

    scala> val m = Map("a"->1, "b"->2)
    m: scala.collection.immutable.Map[String,Int] = Map(a -> 1, b -> 2)

    scala> m map (_._2)
    res1: scala.collection.immutable.Iterable[Int] = List(1, 2)

It runs _map_ over a Map and returns its superclass Iterable.









There are situations where an implicit CBF doesn't use the original
collection's Budr. 


Once such case is TraversableLike's _to[CC[___]]_ which is now added to
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
elements. Calling _apply_ on _CBF_ doesn't require _repr_ as an argument here.
Another _apply_ must be added to _CBF_.

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

    scala> Q2(1,2,3).to[Q1]
    res0: Q1[Int] = QArrBuf@19dc6592

Implicit is looked up as such:

    required: CBF[Nothing, Int, Q1[Any]]
              =>  apply(from: Nothing): Budr[Int, Q1[Int]]

    found:    CBF[Q1[_], Int, Q1[Int]]
              =>  apply(): Budr[Int, Q1[Int]] = newBuilder[Int] 

Here is the interesting thing. _"That"_ can be decided to be _Q1[Any]_ in
what's required this time, so that implicit lookup knows Q1's companion is the 
place to look at.

Nevertheless, a customized _CBF_ can be supplied to outweigh Q1's _CBF_. From 
its point of view, it doesn't care(and doesn't have) the original collection 
"_from_" because it will generate a _Budr_ totally on its own.
Another concrete class _QListBuf_ is provided to help illustrate this.
It plays similar role as _QArrBuf_.

    class QListBuf[A]
      extends Q1[A]
      with Budr[A, QListBuf[A]] {

      protected var list: List[AnyRef] = List.empty[AnyRef]

      def +=(elem: A): this.type = {
        list = elem.asInstanceOf[AnyRef] +: list
        this
      }
      def result(): QListBuf[A] = this

      def foreach[U](f: A => U): Unit = list.foreach { e =>
        f(e.asInstanceOf[A])
      }
    }

Now the hierarchy of Q collection is like:

    Q1 <--- Q2 <--- QArrBuf(default)
      \
       <--- QListBuf

QArrBuf is Q's default concrete class for Q1 and Q2. QListBuf is provided as an
alternative implementation for Q1.








###Reference###
http://stackoverflow.com/questions/5200505/how-are-scala-collections-able-to-return-the-correct-collection-type-from-a-map/5200633#5200633
