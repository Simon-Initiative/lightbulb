import gleam/io
import lightbulb/providers/data_provider
import lightbulb/tool

pub fn main() -> Nil {
  io.println(
    "
  Hello from lightbulb!

  Lightbulb is a Gleam library for building LTI 1.3 tools. Please refer to the
  documentation for more information: https://hexdocs.pm/lightbulb/
  ",
  )
}

/// Export tool module types and functions for convinience
pub type DataProvider =
  data_provider.DataProvider

pub const oidc_login = tool.oidc_login

pub const validate_launch = tool.validate_launch
