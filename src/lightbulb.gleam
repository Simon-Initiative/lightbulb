//// # lightbulb
////
//// `lightbulb` is a Gleam library for building LTI 1.3 tool providers.
////
//// ## Recommended Module Entry Points
////
//// - Core launch and OIDC flow: `lightbulb/tool`
//// - Deep Linking 2.0: `lightbulb/deep_linking`
//// - AGS (Assignments and Grades): `lightbulb/services/ags`
//// - NRPS (Names and Roles): `lightbulb/services/nrps`
//// - OAuth service access tokens: `lightbulb/services/access_token`
//// - Provider interfaces: `lightbulb/providers/data_provider`,
////   `lightbulb/providers/http_provider`
////
//// ## Typical Integration Flow
////
//// 1. Implement a `DataProvider` and `HttpProvider`.
//// 2. Handle OIDC login using `tool.oidc_login`.
//// 3. Validate launches using `tool.validate_launch`.
//// 4. Dispatch by LTI message type and feature:
////    - Resource link launches: AGS/NRPS flows as needed.
////    - Deep-link launches: decode settings and return deep-link response JWT.
//// 5. For service calls, fetch access tokens via
////    `services/access_token.fetch_access_token`.

