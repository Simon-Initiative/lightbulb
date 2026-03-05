import gleam/dict
import gleam/dynamic
import gleeunit/should
import lightbulb/errors
import lightbulb/tool

pub fn core_fr_core_01_missing_roles_rejected_test() {
  let claims =
    base_resource_link_claims()
    |> dict.delete(tool.roles_claim)

  tool.validate_message_type(claims)
  |> should.equal(Error(errors.JwtInvalidClaim))
}

pub fn core_fr_core_03_invalid_message_type_rejected_test() {
  let claims =
    base_resource_link_claims()
    |> dict.insert(tool.message_type_claim, dynamic.string("LtiUnknownRequest"))

  tool.validate_message_type(claims)
  |> should.equal(Error(errors.MessageTypeUnsupported))
}

fn base_resource_link_claims() {
  dict.from_list([
    #(tool.version_claim, dynamic.string("1.3.0")),
    #(tool.message_type_claim, dynamic.string("LtiResourceLinkRequest")),
    #(tool.deployment_id_claim, dynamic.string("deployment-123")),
    #(
      tool.target_link_uri_claim,
      dynamic.string("https://tool.example.com/launch"),
    ),
    #(
      tool.resource_link_claim,
      dynamic.properties([#(dynamic.string("id"), dynamic.string("resource-1"))]),
    ),
    #(tool.roles_claim, dynamic.list([dynamic.string("Instructor")])),
  ])
}
