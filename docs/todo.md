- [ ] Replace bril dep with gleam/time
- [ ] Replace error code string representaitons with structured error types (enums or structs) for
      better handling and testability.
  - e.g. `core.nonce.invalid`, `core.nonce.expired`, `core.nonce.replayed` for nonce validation
    errors should instead be represented as a `NonceError` enum with variants for each case, so
    clients can handle them explicitly rather than relying on string matching. There should also
    be a function to convert these structured errors into the appropriate string messages.
