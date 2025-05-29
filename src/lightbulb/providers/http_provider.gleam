import gleam/http/request.{type Request}
import gleam/http/response.{type Response}

/// Represents an HTTP provider that can send requests and receive responses.
pub type HttpProvider {
  HttpProvider(send: fn(Request(String)) -> Result(Response(String), String))
}
