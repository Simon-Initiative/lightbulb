import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import lightbulb/providers/http_provider.{HttpProvider}

/// A mock HTTP provider for testing purposes.
pub fn http_provider(
  callback: fn(Request(String)) -> Result(Response(String), String),
) {
  HttpProvider(send: callback)
}
