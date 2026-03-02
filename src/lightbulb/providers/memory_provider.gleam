/// Memory Provider is an in-memory data provider for Lightbulb.
///
/// Warning: Data stored in this provider is not persistent and will be lost!
///
/// This module can be used to quickly get up and running with Lightbulb
/// without needing a database or external storage. It's also useful for testing
/// and development purposes. It's important to note that this provider is not
/// suitable for production use, as it does not persist data across restarts.
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/order.{Lt}
import gleam/otp/actor.{type StartError}
import gleam/pair
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import lightbulb/deployment.{type Deployment}
import lightbulb/errors.{NonceExpired, NonceInvalid, NonceReplayed}
import lightbulb/jwk.{type Jwk}
import lightbulb/nonce.{type Nonce, Nonce}
import lightbulb/providers/data_provider.{
  type DataProvider,
  type LaunchContextProvider,
  type LoginContext,
  type ProviderError,
  LaunchContextInvalid,
  LaunchContextNotFound,
  LaunchContextProvider,
  ProviderActiveJwkNotFound,
  ProviderCreateNonceFailed,
  ProviderDeploymentNotFound,
  ProviderRegistrationNotFound,
  from_parts,
}
import lightbulb/providers/memory_provider/tables.{type Table}
import lightbulb/registration.{type Registration}
import youid/uuid

const call_timeout = 5000

pub type MemoryProvider =
  Subject(Message)

type State {
  State(
    dispatch: fn(Message) -> Nil,
    jwks: List(Jwk),
    active_jwk_kid: String,
    nonces: List(Nonce),
    used_nonces: List(String),
    login_contexts: dict.Dict(String, LoginContext),
    registrations: Table(Registration),
    deployments: Table(Deployment),
  )
}

pub type NonceValidation {
  ValidNonce
  ExpiredNonce
  ReplayedNonce
  InvalidNonce
}

pub type Message {
  Shutdown
  GetActiveJwk(reply_with: Subject(Result(Jwk, Nil)))
  GetAllJwks(reply_with: Subject(List(Jwk)))
  CreateJwk(jwk: Jwk)
  SetActiveJwk(kid: String)
  CreateNonce(reply_with: Subject(Result(Nonce, Nil)))
  InsertNonce(nonce: Nonce)
  ValidateNonce(value: String, reply_with: Subject(NonceValidation))
  SaveLoginContext(
    context: LoginContext,
    reply_with: Subject(Result(Nil, Nil)),
  )
  GetLoginContext(
    state: String,
    reply_with: Subject(Result(LoginContext, Nil)),
  )
  ConsumeLoginContext(state: String, reply_with: Subject(Result(Nil, Nil)))
  CleanupExpiredNonces
  CreateRegistration(
    registration: Registration,
    reply_with: Subject(Result(#(Int, Registration), Nil)),
  )
  GetRegistration(
    id: Int,
    reply_with: Subject(Result(#(Int, Registration), Nil)),
  )
  GetRegistrationBy(
    issuer: String,
    client_id: String,
    reply_with: Subject(Result(#(Int, Registration), Nil)),
  )
  GetAllRegistrations(reply_with: Subject(List(#(Int, Registration))))
  DeleteRegistration(id: Int)
  CreateDeployment(
    deployment: Deployment,
    reply_with: Subject(Result(#(Int, Deployment), Nil)),
  )
  GetDeployment(
    issuer: String,
    client_id: String,
    deployment_id: String,
    reply_with: Subject(Result(#(Int, Deployment), String)),
  )
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  // The dispatch function is a safe way to send messages to the actor. Messages will be
  // processed in the order they are received after the current operation is completed.
  let State(dispatch, ..) = state

  case message {
    Shutdown -> actor.stop()

    GetActiveJwk(reply_with) -> {
      case state.jwks {
        [] -> actor.send(reply_with, Error(Nil))
        [jwk, ..] -> actor.send(reply_with, Ok(jwk))
      }

      actor.continue(state)
    }

    GetAllJwks(reply_with) -> {
      actor.send(reply_with, state.jwks)

      actor.continue(state)
    }

    CreateJwk(jwk) -> {
      // if this is the first JWK, set it as the active JWK
      case state.jwks == [] {
        True -> dispatch(SetActiveJwk(jwk.kid))
        False -> Nil
      }

      actor.continue(State(..state, jwks: [jwk, ..state.jwks]))
    }

    SetActiveJwk(kid) -> {
      actor.continue(State(..state, active_jwk_kid: kid))
    }

    CreateNonce(reply_with) -> {
      let nonce =
        Nonce(
          uuid.v4_string(),
          timestamp.system_time() |> timestamp.add(duration.minutes(5)),
        )

      actor.send(reply_with, Ok(nonce))
      actor.continue(State(..state, nonces: [nonce, ..state.nonces]))
    }

    InsertNonce(nonce) -> {
      actor.continue(State(..state, nonces: [nonce, ..state.nonces]))
    }

    ValidateNonce(value, reply_with) -> {
      case list.contains(state.used_nonces, value) {
        True -> {
          actor.send(reply_with, ReplayedNonce)
          actor.continue(state)
        }

        False -> {
          let maybe_nonce = list.find(state.nonces, fn(nonce) { nonce.nonce == value })

          let nonces =
            list.filter(state.nonces, fn(nonce) { nonce.nonce != value })

          case maybe_nonce {
            Ok(nonce) -> {
              case timestamp.compare(timestamp.system_time(), nonce.expires_at) {
                Lt -> {
                  actor.send(reply_with, ValidNonce)
                  actor.continue(State(
                    ..state,
                    nonces: nonces,
                    used_nonces: [value, ..state.used_nonces],
                  ))
                }

                _ -> {
                  actor.send(reply_with, ExpiredNonce)
                  actor.continue(State(..state, nonces: nonces))
                }
              }
            }

            Error(_) -> {
              actor.send(reply_with, InvalidNonce)
              actor.continue(state)
            }
          }
        }
      }
    }

    SaveLoginContext(context, reply_with) -> {
      actor.send(reply_with, Ok(Nil))
      actor.continue(State(
        ..state,
        login_contexts: dict.insert(state.login_contexts, context.state, context),
      ))
    }

    GetLoginContext(state_key, reply_with) -> {
      actor.send(reply_with, dict.get(state.login_contexts, state_key))
      actor.continue(state)
    }

    ConsumeLoginContext(state_key, reply_with) -> {
      actor.send(reply_with, dict.get(state.login_contexts, state_key) |> result.map(fn(_) { Nil }))
      actor.continue(State(
        ..state,
        login_contexts: dict.delete(state.login_contexts, state_key),
      ))
    }

    CleanupExpiredNonces -> {
      let now = timestamp.system_time()

      let nonces =
        list.filter(state.nonces, fn(nonce) {
          case timestamp.compare(now, nonce.expires_at) {
            Lt -> True
            _ -> False
          }
        })

      actor.continue(State(..state, nonces: nonces))
    }

    CreateRegistration(registration, reply_with) -> {
      let #(updated_registrations, record) =
        tables.insert(state.registrations, registration)

      actor.send(reply_with, Ok(record))

      actor.continue(State(..state, registrations: updated_registrations))
    }

    GetRegistration(id, reply_with) -> {
      let record = tables.get(state.registrations, id)

      actor.send(reply_with, record)

      actor.continue(state)
    }

    GetRegistrationBy(issuer, client_id, reply_with) -> {
      let record =
        tables.get_by(state.registrations, fn(registration) {
          registration.issuer == issuer && registration.client_id == client_id
        })

      actor.send(reply_with, record)

      actor.continue(state)
    }

    GetAllRegistrations(reply_with) -> {
      actor.send(reply_with, state.registrations.records)

      actor.continue(state)
    }

    DeleteRegistration(id) -> {
      let updated_registrations = tables.delete(state.registrations, id)

      actor.continue(State(..state, registrations: updated_registrations))
    }

    CreateDeployment(deployment, reply_with) -> {
      let #(updated_deployments, record) =
        tables.insert(state.deployments, deployment)

      actor.send(reply_with, Ok(record))

      actor.continue(State(..state, deployments: updated_deployments))
    }

    GetDeployment(issuer, client_id, deployment_id, reply_with) -> {
      let deployment_record_result = {
        use #(registration_id, _registration) <- result.try(
          tables.get_by(state.registrations, fn(registration) {
            registration.issuer == issuer && registration.client_id == client_id
          })
          |> result.replace_error("Registration not found"),
        )

        tables.get_by(state.deployments, fn(deployment) {
          deployment.registration_id == registration_id
          && deployment.deployment_id == deployment_id
        })
        |> result.replace_error("Deployment not found")
      }

      actor.send(reply_with, deployment_record_result)

      actor.continue(state)
    }
  }
}

pub fn start() -> Result(MemoryProvider, StartError) {
  let init = fn(self) {
    let state =
      State(
        dispatch: process.send(self, _),
        jwks: [],
        active_jwk_kid: "",
        nonces: [],
        used_nonces: [],
        login_contexts: dict.new(),
        registrations: tables.new(),
        deployments: tables.new(),
      )

    let selector = process.new_selector() |> process.select(self)

    Ok(
      actor.initialised(state)
      |> actor.selecting(selector)
      |> actor.returning(self),
    )
  }

  actor.new_with_initialiser(call_timeout, init)
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

pub fn cleanup(actor) {
  process.send(actor, Shutdown)
}

pub fn data_provider(memory_provider) -> Result(DataProvider, ProviderError) {
  let launch_context_provider: LaunchContextProvider =
    LaunchContextProvider(
      save_login_context: fn(context) {
        save_login_context(memory_provider, context)
        |> result.replace_error(LaunchContextInvalid)
      },
      get_login_context: fn(state_key) {
        get_login_context(memory_provider, state_key)
        |> result.replace_error(LaunchContextNotFound)
      },
      consume_login_context: fn(state_key) {
        consume_login_context(memory_provider, state_key)
        |> result.replace_error(LaunchContextNotFound)
      },
    )

  Ok(
    from_parts(
      fn() {
        create_nonce(memory_provider)
        |> result.replace_error(ProviderCreateNonceFailed)
      },
      fn(nonce) {
        case validate_nonce_detailed(memory_provider, nonce) {
          ValidNonce -> Ok(Nil)
          ExpiredNonce -> Error(NonceExpired)
          ReplayedNonce -> Error(NonceReplayed)
          InvalidNonce -> Error(NonceInvalid)
        }
      },
      launch_context_provider,
      fn(issuer, client_id) {
        get_registration_by(memory_provider, issuer, client_id)
        |> result.map(pair.second)
        |> result.replace_error(ProviderRegistrationNotFound)
      },
      fn(issuer, client_id, deployment_id) {
        get_deployment(memory_provider, issuer, client_id, deployment_id)
        |> result.map(pair.second)
        |> result.replace_error(ProviderDeploymentNotFound)
      },
      fn() {
        get_active_jwk(memory_provider)
        |> result.replace_error(ProviderActiveJwkNotFound)
      },
    ),
  )
}

pub fn get_active_jwk(actor) {
  process.call(actor, call_timeout, GetActiveJwk)
}

pub fn get_all_jwks(actor) {
  process.call(actor, call_timeout, GetAllJwks)
}

pub fn create_jwk(actor, jwk) {
  process.send(actor, CreateJwk(jwk))
}

pub fn create_nonce(actor) {
  process.call(actor, call_timeout, CreateNonce)
}

pub fn insert_nonce(actor, nonce: Nonce) {
  process.send(actor, InsertNonce(nonce))
}

fn validate_nonce_detailed(actor, value: String) {
  process.call(actor, call_timeout, ValidateNonce(value, _))
}

pub fn validate_nonce(actor, value) {
  case validate_nonce_detailed(actor, value) {
    ValidNonce -> Ok(Nil)
    _ -> Error(Nil)
  }
}

pub fn save_login_context(actor, context: LoginContext) {
  process.call(actor, call_timeout, SaveLoginContext(context, _))
}

pub fn get_login_context(actor, state_key: String) {
  process.call(actor, call_timeout, GetLoginContext(state_key, _))
}

pub fn consume_login_context(actor, state_key: String) {
  process.call(actor, call_timeout, ConsumeLoginContext(state_key, _))
}

pub fn cleanup_expired_nonces(actor) {
  process.send(actor, CleanupExpiredNonces)
}

pub fn create_registration(actor, registration) {
  process.call(actor, call_timeout, CreateRegistration(registration, _))
}

pub fn list_registrations(actor) {
  process.call(actor, call_timeout, GetAllRegistrations)
}

pub fn get_registration(actor, id) {
  process.call(actor, call_timeout, GetRegistration(id, _))
}

pub fn get_registration_by(actor, issuer, client_id) {
  process.call(actor, call_timeout, GetRegistrationBy(issuer, client_id, _))
}

pub fn delete_registration(actor, id) {
  process.send(actor, DeleteRegistration(id))

  Ok(id)
}

pub fn create_deployment(actor, deployment) {
  process.call(actor, call_timeout, CreateDeployment(deployment, _))
}

pub fn get_deployment(actor, issuer, client_id, deployment_id) {
  process.call(actor, call_timeout, GetDeployment(
    issuer,
    client_id,
    deployment_id,
    _,
  ))
}
