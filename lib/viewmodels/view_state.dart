/// The load status every data-backed screen can be in.
///
/// `idle`    — nothing requested yet (initial prompt).
/// `loading` — a request is in flight.
/// `success` — data arrived and is non-empty.
/// `empty`   — request succeeded but returned no data.
/// `error`   — request failed (network / rate limit / parse).
enum ViewState { idle, loading, success, empty, error }
