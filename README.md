EtudeJS
=======

What is this?
-------------

A JavaScript interpreter written in Ruby.  
It is planned to become a super-fast JavaScript engine featuring JIT,
hidden class, type inference or escape analysis and so on, but
currently this is just a super-slow, rubbish toy interpreter.


Prerequisites
-------------

Requires racc.
> $ gem install racc


Bulid
-----

> $ make


Run
---

> $ make testparse
> $ make testcodegen
> $ make testinterp


Author
------

Yoshitaro Makise


License
-------

BSD License

