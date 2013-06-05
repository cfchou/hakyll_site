---
title: CanBuildFrom and Builder
---

Following [the previous post](./2013-05-12-venture-out-on-canbuildfrom.html),
I would like to have a really functioning CanBuildFrom instead of a do-nothing 
demonstration. Which means it'll be able to build a collection.

Since my approach is to mimic collection library, at least cosmetically. Some understanding
of how collections are organized in the library is necessary. For that [this
discussion](http://stackoverflow.com/questions/1722137/scala-2-8-collections-design-tutorial?lq=1)
does a fantastic job. The pictures below are copied from [here](https://github.com/sirthias/scala-collections-charts/downloads) as they are very helpful.
 
![legend](../images/collection_legend.png)
![collection.immutable](../images/collection_immutable.png)


* For a trait A, there's a most-derived concrete class that builds the
   underlying object exposes the trait A as type.

        scala> val sq = Seq(10,11)
        sq: Seq[Int] = List(10, 11)

* A method on that object might return an object typed as anther trait which 
   appears on the path from trait A to the root trait `Traversable`. As to 
   which trait the returned object exposes or how to control which trait the 
   returned object exposes, it's related to the function, CanBuildFrom and 
   Builder.

        scala> val it: Iterable[Int] = sq.map (_+1)
        it: Iterable[Int] = List(11, 12)

* In fact, it might even be able to return an object exposes a trait derived
  deeper than A, or a trait on a complete different path. This will be discussed 
  in another post.
        
        // LinearSeq derives Seq
        scala> val lsq: LinearSeq[Int] = sq.map (_+1).toList
        lsq: scala.collection.immutable.LinearSeq[Int] = List(11, 12)

        // The underlying object changes. In this case, Map to ArrayBuffer.
        scala> val m = Map(1 -> "no1", 2 -> "no2")
        m: scala.collection.immutable.Map[Int,String] = Map(1 -> no1, 2 -> no2)

        scala> val sqOfMap = m.toSeq
        sqOfMap: Seq[(Int, String)] = ArrayBuffer((1,no1), (2,no2))


Deriving from [previous post](./2013-05-12-venture-out-on-canbuildfrom.html),
more entities are created to mimic the collection library:

    Budr        ---     Builder
    QCompanion  ---     GenericCompanion
    QArrBuf     ---     ArrayBuffer



To start, _bar()_ which return __That__ is added to _QLike_. 

    trait QLike[+A, +Repr] {
      def foo[B, That](q: B)(implicit cbf: CBF[Repr, B, That]): Int = 0
      def bar[B, That](q: B)(implicit cbf: CBF[Repr, B, That]): That = {
        val bdr = cbf()
        bdr += q
        bdr.result
      }
    }

    trait Budr[-Elm, +To] {
      def +=(elem: Elm): this.type
      def result(): To
    }

    trait CBF[-Fr, -Elm, +To] {
      def apply(): Budr[Elm, To]
    }


The newly added _Budr_ is like _collection.mutable.Builder_ but is simplified a lot.
_bar()'s_ implementation reveals the basic usage of it: 

1. Use _CBF_'s _apply()_ to provide a _Budr_. 
2. Use _+=()_ on the _Budr_ to put element into it.
3. In the end, _result()_ on the _Budr_ give the new collection of type __That__.

_GCBF_ needs to implement _apply()_ to provide _Budr_. This job is delegated to
_newBuilder_ that _Q1_'s companion object must implement.

    trait QCompanion[+CC[_]] {
      def newBuilder[A]: Budr[A, CC[A]]
    }
    trait QFac[CC[_]] extends QCompanion[CC] {

      class GCBF[A] extends CBF[CC[_], A, CC[A]] {
        def apply() = newBuilder[A]
      }
      // CBF[CC[_], Nothing, CC[Nothing]]
      lazy val reusableGCBF = new GCBF[Nothing]
    }

    trait Q1[+A] extends QLike[A, Q1[A]]

    object Q1 extends QFac[Q1] {
      implicit def cbf[A]: CBF[Q1[_], A, Q1[A]] =
      reusableGCBF.asInstanceOf[GCBF[A]]

      // Budr[A, QArr[A]] <: Budr[A, Q1[A]]
      // FIXME: newArrBuf or newArrBuf[A]?
      def newBuilder[A]: Budr[A, Q1[A]] = new QArrBuf[A]
    }


It can be seen that _QArrBuf_ plays the role of a most-derived concrete class that
builds the underlying collection. Before showing it's definition, I add another
layer of Q collection, Q2. Just like 



######################

    trait Q2[+A] extends Q1[A] with QLike[A, Q2[A]]

    object Q2 extends QFac[Q2] {
        implicit def cbf[A]: CBF[Q2[_], A, Q2[A]] =
          reusableGCBF.asInstanceOf[GCBF[A]]

        // Budr[A, QArrBuf[A]] <: Budr[A, Q2[A]]
        // FIXME: newArrBuf or newArrBuf[A]?
        def newBuilder[A] = new QArrBuf // Budr[A, Q2[A]], enforced by QCompanion
        def apply[A](a: A): Q2[A] = new Q2[A] {}
    }








It's itself a _Budr_ that 

    // mutable
    class QArrBuf[A] (initialSize: Int)
    extends Q2[A]
    with Budr[A, QArrBuf[A]] {
      protected var array: Array[AnyRef] =
        new Array[AnyRef](math.max(initialSize, 1))
      protected var size0 = 0

      def this() = this(16)

      // doesn't implement resizable array
      def +=(elem: A): this.type = {
        array(size0) = elem.asInstanceOf[AnyRef]
        size0 += 1
        this
      }
      def result(): QArrBuf[A] = this
    }





###Reference###
[Scala 2.8 collections design tutorial](http://stackoverflow.com/questions/1722137/scala-2-8-collections-design-tutorial?lq=1)
