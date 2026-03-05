import gleam/dict
import gleam/dynamic
import gleam/list
import gleeunit/should
import lightbulb/services/nrps

pub fn nrps_fr_nrps_02_missing_scope_rejected_test() {
  let claims = nrps_claim_with_scope([])

  nrps.require_can_read_memberships(claims)
  |> should.equal(
    Error(nrps.ScopeInsufficient(nrps.context_membership_readonly_claim_url)),
  )
}

pub fn nrps_fr_nrps_02_scope_present_allows_read_memberships_test() {
  let claims =
    nrps_claim_with_scope([nrps.context_membership_readonly_claim_url])

  nrps.require_can_read_memberships(claims)
  |> should.equal(Ok(Nil))
}

fn nrps_claim_with_scope(scope: List(String)) {
  dict.from_list([
    #(
      nrps.nrps_claim_url,
      dynamic.properties([
        #(
          dynamic.string("context_memberships_url"),
          dynamic.string("https://lms.example.com/context/100/memberships"),
        ),
        #(
          dynamic.string("service_versions"),
          dynamic.list([dynamic.string("2.0")]),
        ),
        #(
          dynamic.string("scope"),
          dynamic.list(list.map(scope, dynamic.string)),
        ),
      ]),
    ),
  ])
}
