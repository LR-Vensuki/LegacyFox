// C++23 on armv7 iOS 4-7 with the static libc++: the parts Gecko leans on.
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <filesystem>
#include <format>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <thread>
#include <variant>
#include <vector>

thread_local int tls_counter = 41;

int main() {
    auto start = std::chrono::steady_clock::now();
    std::mutex m;
    std::condition_variable cv;
    bool ready = false;
    std::atomic<uint64_t> total{0};
    std::vector<std::thread> threads;
    for (int t = 0; t < 4; t++)
        threads.emplace_back([&, t] {
            tls_counter += t;
            total += static_cast<uint64_t>(tls_counter);
            std::lock_guard<std::mutex> lock(m);
            ready = true;
            cv.notify_one();
        });
    {
        std::unique_lock<std::mutex> lock(m);
        cv.wait(lock, [&] { return ready; });
    }
    for (auto &th : threads)
        th.join();

    std::variant<int, std::string> v = std::string("variant");
    std::optional<double> o = 2.5;
    int arr[] = {1, 2, 3};
    std::span<int> s(arr);
    auto shared = std::make_shared<std::map<int, std::string>>();
    (*shared)[1] = "one";

    std::string caught;
    try {
        throw std::runtime_error("exception");
    } catch (const std::exception &e) {
        caught = e.what();
    }

    std::error_code ec;
    auto tmp = std::filesystem::temp_directory_path(ec);
    auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - start);
    std::puts(std::format("c++ on armv7 ios: total={} (want 170) tls={} {} {} span={} map={} {} tmp={} {}us",
                          total.load(), tls_counter, std::get<std::string>(v), *o, s.size(),
                          (*shared)[1], caught, tmp.string(), elapsed.count()).c_str());
    return total == 170 && caught == "exception" ? 0 : 1;
}
