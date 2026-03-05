//// # HTTP Provider Interface
////
//// Transport abstraction used by service modules for outbound HTTP calls.
////
//// ## Example
////
//// ```gleam
//// import gleam/httpc
//// import gleam/result
//// import gleam/string
//// import lightbulb/providers/http_provider.{HttpProvider}
////
//// pub fn http_provider() -> HttpProvider {
////   HttpProvider(send: fn(req) {
////     httpc.send(req)
////     |> result.map_error(fn(error) {
////       "HTTP transport error: " <> string.inspect(error)
////     })
////   })
//// }
//// ```

import gleam/http/request.{type Request}
import gleam/http/response.{type Response}

/// Represents an HTTP provider that can send requests and receive responses.
pub type HttpProvider {
  HttpProvider(send: fn(Request(String)) -> Result(Response(String), String))
}
