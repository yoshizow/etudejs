var i;

i = 3;
do {
    log(0);
    i = i - 1;
    continue;
    log(1);
} while(i > 0);

i = 3;
while (i > 0) {
    log(0);
    i = i - 1;
    continue;
    log(1);
}

for (i = 3; i > 0; i = i - 1) {
    log(0);
    continue;
    log(1);
}
