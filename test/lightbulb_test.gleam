import gleeunit
import lightbulb/utils/logger

pub fn main() -> Nil {
  logger.configure_quiet()
  gleeunit.main()
}
