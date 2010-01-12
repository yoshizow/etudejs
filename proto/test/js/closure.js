function make_inc() {
    var count = 0;
    function inc() {
        count = count + 1;
        return count;
    }
    return inc;
}

var fn = make_inc();
var a = fn();  // => 1
var b = fn();  // => 2

/*

  

 */
