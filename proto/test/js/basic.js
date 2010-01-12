var gvar = 123;

function foo(a, b) {
    function bar(a) {
        return a + 1;
    }
    var lvar = a+2*3+4, lvar2;
    // one-line comment
    lvar3 = lvar*(bar(b)/-2);
    /* multi-line
      comment */
}

foo(1, 2);
