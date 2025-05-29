import gleam/httpc
import gleam/result
import gleam/string
import lightbulb/providers/http_provider.{HttpProvider}

/// An HTTP provider that uses the `httpc` module to send requests.
pub fn http_provider() {
  HttpProvider(send: fn(req) {
    httpc.send(req)
    |> result.map_error(fn(e) {
      "Error sending HTTP request: " <> string.inspect(e)
    })
  })
}
