// hello.cpp
#include <iostream>
#include <vector>

// 간단한 연산을 수행하여 CPU 작업을 시뮬레이션하는 함수
long long perform_computation(int iterations) {
    long long sum = 0;
    for (int i = 0; i < iterations; ++i) {
        sum += i * 2;
    }
    return sum;
}

int main() {
    // 프로그램 시작을 알리는 메시지 출력
    std::cout << "Hello, Simulator! Starting computation..." << std::endl;

    // 연산 횟수 설정 (이 값을 조절하여 프로그램 실행 시간 변경 가능)
    int computation_iterations = 20000000;
    
    // 설정된 횟수만큼 연산 수행
    long long result = perform_computation(computation_iterations);

    // 프로그램 종료와 결과 출력
    std::cout << "Computation finished. Result: " << result << std::endl;
    std::cout << "Goodbye!" << std::endl;

    return 0;
}