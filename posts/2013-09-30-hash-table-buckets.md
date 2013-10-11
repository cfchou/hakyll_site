---
title: Number of Buckets in Hash Tables
tags: algorithms, hash table, coursera
---

Why should the number of buckets in a hash table be prime?

This question was raised when I read some material about hash table on
coursera.  It's taught in many text books that the length of a hash table
should be a prime number. While it is an widely accepted point, not much
information out there tells me the reason why. Fortunately, a discussion on
Stackoverflow leads me to this blog post[1]. The statement made is:

    If suppose your hashCode function results in the following hashCodes among 
    others {x , 2x, 3x, 4x, 5x, 6x...}, then all these are going to be
    clustered in just m number of buckets, where 
        m = table_length/GreatestCommonFactor(table_length, x)

Obviously we want the size of the cluster to be as big as possible.
Therefore(quote),

    Simply make m equal to the table_length by making 
    GreatestCommonFactor(table_length, x) equal to 1, i.e by making 
    table_length coprime with x. And if x can be just about any number then 
    make sure that table_length is a prime number.

As to how "m = table_length/GreatestCommonFactor(table_length, x)" came about,
the author just says "it is trivial to verify/derive this". Here I'd like to
elaborate it.



First look at an example. Let the set of 'n' hashCodes be 

    { 12, 24, 36, 48, 60, 72, 84, 96, ......, nx }, where x = 12

If we have table length l = 8, then the corresponding bucket indexes are

    {  4,  0,  4,  0,  4,  0,  4,  0, ...... }

Note that the index is 0 whenever hashCode is __the multiple of LCM(x, l)__[2].

    LCM(12, 8) == 24

If we have table length l = 7, then the corresponding bucket indexes are

    {  5,  3,  1,  6,  4,  2,  0,  5, ...... }
    LCM(12, 7) == 84

So the indexes start over every "LCM(x, l) / x" hashCodes. Which means the 
cluster size 'm' is

    m = LCM(x, l) / x
    
Here a formula is used to express LCM in terms of GCD[2][3]:
    
    LCM(x, l) = | x * l | / GCD(x, l)
            
Therefore
            
    m = (x * l / GCD(x, l)) / x
      = l / GCD(x, l) 
                      
And that's the author's formula for 'm'. From that we'll conclude 'l' is best
to be coprime with x.

In implementation of HashCode function, x is chose to be a prime number. That's
to make sure 'x' and 'l' to be coprime even when an user inadvertently has a
table size of non-prime 'l'.
                      
                      
###Reference

1. [Hash table lengths and prime numbers](http://srinvis.blogspot.mx/2006/07/hash-table-lengths-and-prime-numbers.html)
2. LCM -- [least common multiple](http://en.wikipedia.org/wiki/Least_common_multiple)
3. GCD -- greatest common factor




