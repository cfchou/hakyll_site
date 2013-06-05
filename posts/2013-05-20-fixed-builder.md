---
title: Fixed Builder
---

Builder generated from an implicit _CanBuildFrom[Repr, B, That]_ is flexible. 
But there are situations where a new type of collection is not needed and the 
type of element doesn't change. For example: 

    trait TraversableLike[+A, +Repr] extends ...
    {
        def filter(p: A => Boolean): Repr = ???
    }

In this case, using __newBuilder__ in the campanion object of the
trait in question(_Repr_) is sufficient. On the basis of [previous
discussion](./2013-05-13-canbuildfrom-and-builder.html), I'll follow the collection
library's pattern to add some abstractions, namely:

    HasNewBuilderRepr   ---      HasNewBuilder
    QTmpl               ---      GenericTraversableTemplate


First abstraction added is _HasNewBuilderRepr_, provides _Budr[A, Repr]_ that
builds _Repr_ out of _Repr_. That is, the two collections are of the same type,
so are their elements.

    trait HasNewBuilderRepr[+A, +Repr] {
      /** The builder that builds instances of Repr */
      protected[this] def newBuilderRepr: Budr[A, Repr]
    }

    trait QLike[+A, +Repr] extends HasNewBuilderRepr[A, Repr] {
        ...
      protected[this] def newBuilderRepr: Budr[A, Repr]

      def woo: Repr = {
        val bdr = newBuilderRepr
        bdr.result
      }
    }


Then _QTmpl_ is added. It is intended to be mixed in to _Q1_ and _Q2_ traits. 
It's default implementation for _newBuilderRepr_ is pointing to _newBuilder_ in
the companion object of the trait in question(Q1 or Q2). The suspicious 
_@uncheckedVariance_ is ignored for now.


    import scala.annotation.unchecked.uncheckedVariance

    trait QTmpl[+A, +CC[X] <: Q1[X]] 
      extends HasNewBuilderRepr[A, CC[A] @uncheckedVariance] {

      def companion: QCompanion[CC]

      protected[this] def newBuilderRepr: Budr[A, CC[A]] =
        companion.newBuilder[A]
    }


    trait QFac[CC[X] <: Q1[X] with QTmpl[X, CC]] extends QCompanion[CC] {
        ...
    }

It's trait _Q1_ and _Q2_'s job to tell what their companions are.

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



Try woo in REPL:

    scala> Q1(10).woo
    res0: Q1[Int] = QArrBuf@1cf6046

    scala> Q2("xx").woo
    res1: Q2[String] = QArrBuf@1489087


[Gist](https://gist.github.com/cfchou/5715447)




