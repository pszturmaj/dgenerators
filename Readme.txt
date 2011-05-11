Generator function must have exactly one OUT argument which is used to return values.
OUT argument may occupy any position in the argument list.

generator() takes function or delegate reference and its arguments. Then it
creates a generator and converts it to a range. Under the hood it uses core.thread.Fiber.

The whole thing is pretty straightforward and simple. With some eventual syntactic
sugar it may become even more clean and nice to use.

Example:
------------
module main;

import std.stdio;
import generators;

void genSquares(out int result, int from, int to)
{
    foreach (x; from .. to + 1)
    {
        yield!result(x * x);
    }
}

void main(string[] argv)
{
    foreach (sqr; generator(&genSquares, 10, 20))
        writeln(sqr);
}

Known issues:
----------------
* Exceptions don't work. Fiber.call() should rethrow them, but it's not happening.
  I don't know, but that may be a bug in Fiber class.