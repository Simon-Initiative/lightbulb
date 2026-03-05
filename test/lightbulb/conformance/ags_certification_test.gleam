import gleam/dict
import gleam/dynamic
import gleam/list
import gleeunit/should
import lightbulb/services/ags

pub fn ags_fr_ags_04_missing_score_scope_rejected_test() {
  let claims = ags_claim_with_scope([ags.lineitem_scope_url])

  ags.require_can_post_scores(claims)
  |> should.equal(Error(ags.ScopeInsufficient(ags.scores_scope_url)))
}

pub fn ags_fr_ags_04_score_scope_allows_post_scores_test() {
  let claims = ags_claim_with_scope([ags.scores_scope_url])

  ags.require_can_post_scores(claims)
  |> should.equal(Ok(Nil))
}

fn ags_claim_with_scope(scope: List(String)) {
  dict.from_list([
    #(
      ags.lti_ags_claim_url,
      dynamic.properties([
        #(
          dynamic.string("scope"),
          dynamic.list(list.map(scope, dynamic.string)),
        ),
      ]),
    ),
  ])
}
