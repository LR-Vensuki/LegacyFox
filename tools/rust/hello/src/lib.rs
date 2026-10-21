use std::collections::HashMap;
use std::time::{Instant, SystemTime};

#[no_mangle]
pub extern "C" fn lf_rust_hello() {
    let start = Instant::now();
    let mut map = HashMap::new();
    for i in 0..1000u32 {
        map.insert(i, i.wrapping_mul(2654435761));
    }
    let worker = std::thread::spawn(|| (1..=20u64).product::<u64>());
    let fact = worker.join().unwrap();
    let mutex = std::sync::Mutex::new(0u32);
    *mutex.lock().unwrap() += 1;
    thread_local!(static COUNT: std::cell::Cell<u32> = std::cell::Cell::new(7));
    println!(
        "hello from rust on armv7 ios: map={} 20!={} tls={} f={} now={:?} took={:?}",
        map.len(), fact, COUNT.with(|c| c.get()), 1.5f64.sqrt(),
        SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap().as_secs(),
        start.elapsed()
    );
}

#[repr(C)]
pub struct Rect { pub x: f32, pub y: f32, pub w: f32, pub h: f32 }

// The C caller passes these the way clang does for armv7 iOS; a mismatch in
// the float ABI shows up as wrong numbers here.
#[no_mangle]
pub extern "C" fn lf_rust_abi(a: u64, r: Rect, d: f64, b: u32) -> f64 {
    println!("abi: a={} r=({},{},{},{}) d={} b={}", a, r.x, r.y, r.w, r.h, d, b);
    a as f64 + (r.x + r.y + r.w + r.h) as f64 + d + b as f64
}
