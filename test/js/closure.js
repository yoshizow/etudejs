function make_inc() {
    var count = 0;
    function inc() {
        count = count + 1;
        return count;
    }
    return inc;
}

var fn = make_inc();
log(fn());  // => 1
log(fn());  // => 2

/*

  

 */
