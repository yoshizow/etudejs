var i = 0, j = 0;
label:
while(i < 3) {
    while(j < 3) {
        continue label;
        log(0);
    }
    log(1);
    i = i + 1;
}
