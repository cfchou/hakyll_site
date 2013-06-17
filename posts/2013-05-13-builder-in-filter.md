---
title: Builder in Filter
tags: scala, Builder
---

`Builder` is not only useful in creating a collection as what's been shown in
[the previous post](./2013-05-12-builder-basics.html). It's also heavily used
in functions of _implementation traits_, such as `filter` in `TraversableLike`: 

    trait TraversableLike[+A, +Repr] extends ...
    {
        def filter(p: A => Boolean): Repr = ???
        def partition(p: A => Boolean): (Repr, Repr) = ???
        ...
    }

`Repr`, it appears very often in the code as a type parameter. Conventionally, 
It names the _initial_ type that __Repr__esents the underlying storage. That 
is, if running `Q1(1, 2, 3)` in REPL: 
    
    scala> Q1(1,2,3)
    res0: Q1[Int] = QArrBuf@7e5ccc

`Q1[Int]` is the type argument for _Repr_s appearing in relevant 
traits/classes in Q1[+A]'s type hierarchy, e.g.

    QLike[A, Repr]              --->   QLike[Int, Q1[Int]]


No implicit `CanBuildFrom` is needed in `filter` as the type of collection 
involved in the results is still `Repr`. 

    scala> Seq(1,2,3) filter (_ > 2)
    res4: Seq[Int] = List(3)

In this case, `filter` over `Seq(1, 2, 3)` gives a `Seq[Int]`. Internally, 
since `Repr` is `Seq[Int]`, `newBuilder[Int]: Builder[Int, Seq[Int]]` in Seq's 
companion object is used to create the result.

On the basis of [previous discussion](./2013-05-12-builder-basics.html), 
I'll implement `filter` for the Q collection.
More entities will be added to follow the collection library's structure to add 
some abstractions, namely:

    HasNewBuilderRepr   ---      HasNewBuilder
    QTmpl               ---      GenericTraversableTemplate


The first abstraction added is `HasNewBuilderRepr`. It provides `Budr[A, Repr]` 
that builds `Repr` out of `Repr`. That is, the two collections are of the same type,
so are their elements.


    trait HasNewBuilderRepr[+A, +Repr] {
      /** The builder that builds instances of Repr */
      protected[this] def newBuilderRepr: Budr[A, Repr]
    }


In addition, `QTmpl` is added. It is intended to be mixed in to Q1 or Q2 trait.
Its default implementation for `newBuilderRepr` is simply pointing to
`newBuilder` in corresponding companion objects which derives `QCompanion`.
The suspicious `@uncheckedVariance` is ignored for now. Plus, `QFac` changes a
bit to have a proper type bound; trait Q1 and Q2 implement `def companion` to
mark what their own companion objects are.


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



Now add `filter` for Q collection:

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

The implementation of `filter` makes use of _for-comprehension_ to apply
the predicate `p` to every element. Therefore, `foreach` has to be supported as
well. The implementation appears in `QArrBuf`:

    class QArrBuf[A] (initialSize: Int)
      extends Q2[A]
      with Budr[A, QArrBuf[A]] {
      ...

      def foreach[U](f: A => U): Unit = array.take(size0).foreach { e =>
        f(e.asInstanceOf[A])
      }
    }

To conclude, `filter`:

1. Use `newBuilderRepr` to get `bdr: Budr`. 
2. Use _for-comprehension_ to apply the predicate to elements. Copy those
   return true to `bdr` by `+=()`
3. In the end, calling `result()` on `bdr` to give the new collection in
   the question. 

Try it in REPL:

    scala> Q1(1, 2, 3) filter (_ > 1) foreach (println _)
    2
    3
    scala> Q2("aaaaa", "b", "cc") filter { s => s.length > 1 } foreach (println
    _)
    aaaaa
    cc




[Gist](https://gist.github.com/cfchou/5715447)









