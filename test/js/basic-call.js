function foo(a, b) {
    function bar(x) {
        return x + 1;
    }
    var c = a * bar(b);
    return c;
}

var v = foo(2, 3);
log(v);
