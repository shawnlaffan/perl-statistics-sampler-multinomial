# perl-statistics-sampler-multinomial


Implements multinomial sampling using two methods,
conditional binomial method, and Vose's version of the alias method.

The setup time for the alias method is longer than for other methods,
and the memory requirements are larger since it maintains two lists in memory,
but this is amortised when 
when generating repeated samples because only two random numbers are
needed for each draw, as compared to up to O(log n) for other methods.
This should have a pay off when, for example calculating 
bootstrap confidence intervals for a set of classes, but benchmarking
indicates that the PRNG method calls at the perl level cause
substantial slowdowns to the point that the GSL algorithm is faster
(as most of its calls are at the C level).


For more details and background, see http://www.keithschwarz.com/darts-dice-coins


## COPYRIGHT AND LICENCE

Copyright (C) 2016, Shawn Laffan

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
