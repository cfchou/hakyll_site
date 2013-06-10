---
title: Venture out on CanBuildFrom
---

In this post, I'll loosely follow how the collection library uses `CanBuildFrom` 
and create a trivial collection trait.

Because nearly every class/trait inherits/mixes in many classes/traits, the
first thing must be understood is the hierarchy and linearization of
classes/traits. It's been explained in detail in Section 12.6 in [Programming in
Scala](http://http://www.artima.com/shop/programming_in_scala_2ed). 

I will create a trivial collection class called `Q` which bears no usefulness
but can be used for demonstration. A couple of entities will also be created to
cosmetically mimic the Scala collection library 2.10.

Roughly speaking, I try to imitate the class hierarchy of
`scala.collection.immutable.Traversable`. The mapping looks somewhat like:

    QLike   ---     TraversableLike
    Q1      ---     Traversable
    QFac    ---     GenTraversableFactory
    CBF     ---     CanBuildFrom
    GCBF    ---     GenericCanBuildFrom

`QLike`, as many XXXLike's in the collection library(so called __implementation
traits__), provides the default and
general implementation for many functions which make use of `CBF/CanBuildFrom`.

    class CBF[-Fr, -Elm, +To]

    trait QLike[+A, +Repr] {
      def foo[B, That](q: B)(implicit cbf: CBF[Repr, B, That]): Int = 0
    }

    trait Q1[+A] extends QLike[A, Q1[A]]
    object Q1 {
      def apply[A](a: A): Q1[A] = new Q1[A] {}
    }

As `CBF` is not really used at the moment(`foo` always returns 0), it doesn't have
any member.

The code can be tested in REPL:

    scala> val q1 = Q1(10)
    q1: Q1[Int] = Q1$$anon$1@36536500
    scala> q1.foo(5)
    <console>:13: error: could not find implicit value for parameter cbf: CBF[Q1[Int],Int,Any]
                  q1.foo(5)
                        ^

Besides the fact that it evidently needs an implicit `CBF`, there's one more 
thing worth noting. When `q1.foo(5)` is called, `CBF`'s type parameters are: 

    Repr    -->     Q1[Int]  // derived from selector's context
    B       -->     Int      // inferred from argument 5
    That    -->     Any      // no information, hence a wildcard-like type 

Based on the rule for implicit lookup, it tries `Q1`'s companion object but with
no luck. To remedy this, I will provide `CBF` in `Q1`'s companion. Moreover,
whatever `B` is inferred to, I'd like to get an `CBF` for it. E.g.

    scala> q1.foo(5)            // B --> Int
    scala> q1.foo("string")     // B --> String

I copy a technique that's used in the collection library:

    import scala.language.higherKinds

    trait QFac[CC[_]] {
      class GCBF[A] extends CBF[CC[_], A, CC[A]]

      // CBF[CC[_], Nothing, CC[Nothing]]
      lazy val reusableGCBF = new GCBF[Nothing] 
    }

    object Q1 extends QFac[Q1] {
      implicit def cbf[A]: CBF[Q1[_], A, Q1[A]] =
        reusableGCBF.asInstanceOf[GCBF[A]]

      def apply[A](a: A): Q1[A] = new Q1[A] {}
    }

`QFac` is the factory that's derived by `Q1`'s companion. It has a special
`CBF` called `reusableGCBF` which type is essentially `CBF[CC[_], Nothing, CC[Nothing]]`

_cbf[A]_ in object _Q1_ is a polymorphic method. When implicit lookup happens, 
it is tried to match the implicit `CBF` required.
It is done by casting `reusableGCBF`. For instance, If `q1.foo("a string")` is called,
the required implicit is of type `CBF[Q1[Int], String, Any]`. `reusableGCBF` is casted from  
`CBF[Q1[_], Nothing, Q1[Nothing]]` to  `CBF[Q1[_], String, Q1[String]]` in order to
conform.

    required: CBF[Q1[Int], String, Any]

    found:    CBF[Q1[_], String, Q1[String]]
    
The variance check for `CBF[-Fr, -Elm, +To]` is valid as shown below. The arrow sign means "conform to".

    variance      required      conformance     found
    ---------     ---------     -----------     -------  
    -Fr           Q1[Int]       --->            Q1[_]
    -Elm          String        <-->            String
    +To           Any           <---            Q[String]
    ---------------------------------------------------  
    result        required      <---            found

    Note that `-Fr` allows because `Q1[+A]` is covariant. 

Now run `foo` in REPL:

    scala> q1.foo("a string")
    res1: Int = 0

    scala> q1.foo(5)
    res0: Int = 0



What's interesting but not shown here, is that the found implicit will then help 
to infer foo's type parameter `That`. I'll try a more sophisticated example to
demonstrate it in [another post](./2013-05-13-canbuildfrom-and-builder.html).


[Gist](https://gist.github.com/cfchou/5704938)


###Reference###
* [How are Scala collections able to return the correct collection type from a map operation?](http://stackoverflow.com/questions/5200505/how-are-scala-collections-able-to-return-the-correct-collection-type-from-a-map/5200633#5200633)

    This particular discussion has nicely explained the implicit resolution for
CanBuildFrom in the wild and is definitely worth reading.


