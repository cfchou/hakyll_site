---
title: Builder and CanBuildFrom 
---

In the collection library, _CanBuildFrom_ creates _Builder_. Many functions in
implementation traits like TraversableLike use _CanBuildFrom_ to generate the
right kind of _Builder_ to create a suitable collection.





Following previous posts, there's a trivial function _foo_ in QLike which looks like:

  trait QLike[+A, +Repr]
    extends HasNewBuilderRepr[A, Repr] {
    def foo[B, That](q: B)(implicit cbf: CBF[Repr, B, That]): Int = 0
    ...
  }

In [this post](), I stated that the found implicit _CBF_ will then help 
to infer foo's type parameter `That`. 


I'll try a more sophisticated example to
demonstrate it in [another post](./2013-05-13-canbuildfrom-and-builder.html).



http://stackoverflow.com/questions/5200505/how-are-scala-collections-able-to-return-the-correct-collection-type-from-a-map/5200633#5200633
