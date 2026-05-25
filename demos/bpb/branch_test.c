// branch_test.c
volatile int sum = 0;
int main() {
    for (int i = 0; i < 20; i++) {
        for (int j = 0; j < 20; j++) {
            sum += i * j;
        }
    }
    return 0;
}
