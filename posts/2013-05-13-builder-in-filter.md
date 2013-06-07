---
title: Builder in Filter
---

_Builder_ is not only useful for creating a collection as what's been shown in
[the previous post](./2013-05-12-builder-basics.html). It's also heavily used
in functions of _implementation traits_, such as _filter_ in TraversableLike: 

    trait TraversableLike[+A, +Repr] extends ...
    {
        def filter(p: A => Boolean): Repr = ???
        def partition(p: A => Boolean): (Repr, Repr) = ???
        ...
    }

No implicit _CanBuildFrom_ is needed as the type of collection involved in the
results is still Repr. 

    scala> Seq(1,2,3) filter (_ > 2)
    res4: Seq[Int] = List(3)

In this case, filtering _Seq(1, 2, 3)_ gives a _Seq[Int]_. Internally, 
__newBuilder[Int]: Builder[Int, Seq[Int]]__ in Seq's companion object is used 
to create the result.

On the basis of [previous discussion](./2013-05-12-builder-basics.html), 
I'll implement _filter_ for the Q collection.
More entities will be added to follow the collection library's pattern to add 
some abstractions, namely:

    HasNewBuilderRepr   ---      HasNewBuilder
    QTmpl               ---      GenericTraversableTemplate


The first abstraction added is _HasNewBuilderRepr_, provides _Budr[A, Repr]_ that
builds _Repr_ out of _Repr_. That is, the two collections are of the same type,
so are their elements.


    trait HasNewBuilderRepr[+A, +Repr] {
      /** The builder that builds instances of Repr */
      protected[this] def newBuilderRepr: Budr[A, Repr]
    }


In addition, _QTmpl_ is added. It is intended to be mixed in to _Q1_ or _Q2_ 
trait. It's default implementation for _newBuilderRepr_ is simply pointing to 
_newBuilder_ in companion objects which derives _QCompanion_. The suspicious 
_@uncheckedVariance_ is ignored for now. Plus, QFac changes a bit to have
a proper type bound; trait Q1/Q2 change to tell their own companion objects.


    import scala.annotation.unchecked.uncheckedVariance

    trait QTmpl[+A, +CC[X] <: Q1[X]] 
      extends HasNewBuilderRepr[A, CC[A] @uncheckedVariance] {

      def companion: QCompanion[CC]

      protected[this] def newBuilderRepr: Budr[A, CC[A]] =
        companion.newBuilder[A]
    }

    trait QFac[CC[X] <: Q1[X] with QTmpl[X, CC]]
      extends QCompanion[CC] { ...  }

    trait Q1[+A]
      extends QLike[A, Q1[A]]
      with QTmpl[A, Q1] {
      override def companion: QCompanion[Q1] = Q1
    }

    trait Q2[+A]
      extends Q1[A]
      with QLike[A, Q2[A]]
      with QTmpl[A, Q2] {
      override def companion: QCompanion[Q2] = Q2
    }



Now adding _filter_ for Q collection:

    trait QLike[+A, +Repr]
      extends HasNewBuilderRepr[A, Repr] {
      ...

      // support for-comprehension
      def foreach[U](f: A => U): Unit

      def filter(p: A => Boolean): Repr = {
        val bdr = newBuilderRepr
        for (x <- this)
          if (p(x)) bdr += x
        bdr.result
      }
    }

The implementation of _filter_ makes use of for-comprehension to apply
the predicate _p_ to every element. Therefore, _foreach_ has to be supported as
well. The implementation appears in _QArrBuf_:

    class QArrBuf[A] (initialSize: Int)
      extends Q2[A]
      with Budr[A, QArrBuf[A]] {
      ...

      def foreach[U](f: A => U): Unit = array.take(size0).foreach { e =>
        f(e.asInstanceOf[A])
      }
    }

Try it in REPL:

    scala> Q1(1, 2, 3) filter (_ > 1) foreach (println _)
    2
    3
    scala> Q2("aaaaa", "b", "cc") filter { s => s.length > 1 } foreach (println
    _)
    aaaaa
    cc













