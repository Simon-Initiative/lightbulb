import gleeunit/should
import gleam/time/duration
import gleam/time/timestamp
import lightbulb/providers/data_provider.{LoginContext}
import lightbulb/providers/memory_provider

pub fn login_context_round_trip_and_consume_test() {
  let assert Ok(memory) = memory_provider.start()

  let context =
    LoginContext(
      state: "state-123",
      target_link_uri: "https://tool.example.com/launch",
      issuer: "https://platform.example.com",
      client_id: "client-123",
      expires_at: timestamp.system_time() |> timestamp.add(duration.minutes(5)),
    )

  memory_provider.save_login_context(memory, context)
  |> should.equal(Ok(Nil))

  memory_provider.get_login_context(memory, "state-123")
  |> should.equal(Ok(context))

  memory_provider.consume_login_context(memory, "state-123")
  |> should.equal(Ok(Nil))

  memory_provider.get_login_context(memory, "state-123")
  |> should.equal(Error(Nil))

  memory_provider.cleanup(memory)
}
