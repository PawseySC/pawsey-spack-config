#include <stddef.h>
#include <stdio.h>

int main() {
    size_t size = sizeof(int); // Use size_t from stddef.h
    ptrdiff_t diff = (char*)(&size + 1) - (char*)(&size); // Use ptrdiff_t from stddef.h

    printf("Size of int: %zu\n", size);
    printf("Pointer difference: %td\n", diff);

    return 0;
}

