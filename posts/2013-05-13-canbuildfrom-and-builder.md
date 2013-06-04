---
title: CanBuildFrom and Builder
---

Following [the previous post](./2013-05-12-venture-out-on-canbuildfrom.html),
I would like to have a really functioning CanBuildFrom instead of a do-nothing 
demonstration. Which means it'll be able to build a collection.

Since my approach is to mimic collection library, at least cosmetically. Some understanding
of how collections are organized in the library is necessary. For that [this
discussion](http://stackoverflow.com/questions/1722137/scala-2-8-collections-design-tutorial?lq=1)
does a fantastic job. The pictures are copied here as they are very helpful.
 
![legend](../images/collection_legend.png)
![collection.immutable](../images/collection_immutable.png)


* Concrete classes are all leaf nodes.
* For a trait A, there's a most-derived concrete class that builds the
  underlying object exposes the trait A as type.

        scala> val sq = Seq(10,11)
        sq: Seq[Int] = List(10, 11)

* A method on that object might return an object typed as anther trait which 
  appears on the path from trait A to the root trait `Traversable`. As to which 
  trait the returned object exposes or how to control which trait the returned 
  object exposes, it's related to the function, CanBuildFrom and Builder.

        scala> val it: Iterable[Int] = sq.map (_+1)
        it: Iterable[Int] = List(11, 12)

* In fact, it might even be able to return an object exposes a trait derived
  from A, or a trait on a complete different path.
        
        scala> val lsq: LinearSeq[Int] = sq.map (_+1).toList
        lsq: scala.collection.immutable.LinearSeq[Int] = List(11, 12)

        scala> val m = Map(1 -> "no1", 2 -> "no2")
        m: scala.collection.immutable.Map[Int,String] = Map(1 -> no1, 2 -> no2)

        scala> val sqOfMap: Seq[(Int, String)] = m.toSeq
        sqOfMap: Seq[(Int, String)] = ArrayBuffer((1,no1), (2,no2))




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







###Reference###
[Scala 2.8 collections design tutorial](http://stackoverflow.com/questions/1722137/scala-2-8-collections-design-tutorial?lq=1)
