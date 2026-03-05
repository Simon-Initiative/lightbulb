import gleam/string
import logging

pub type Level {
  Emergency
  Alert
  Critical
  Error
  Warning
  Notice
  Info
  Debug
}

/// Configure the Erlang logger to use the logging package defaults.
pub fn configure_backend() -> Nil {
  logging.configure()
}

/// Reduce logger output to emergency-only level.
/// Useful in tests to avoid expected-failure noise in output.
pub fn configure_quiet() -> Nil {
  logging.set_level(logging.Emergency)
}

/// Logs a message at the provided level.
pub fn log(level: Level, message: String) -> Nil {
  logging.log(to_logging_level(level), message)
}

/// Logs a message and inspected metadata at the provided level.
pub fn log_meta(level: Level, message: String, meta: a) -> Nil {
  logging.log(to_logging_level(level), message <> "\n" <> string.inspect(meta))
}

/// Logs an info message.
pub fn info(message: String) -> Nil {
  log(Info, message)
}

/// Logs an info message with metadata.
pub fn info_meta(message: String, meta: a) -> Nil {
  log_meta(Info, message, meta)
}

/// Logs a warning message.
pub fn warn(message: String) -> Nil {
  log(Warning, message)
}

/// Logs a warning message with metadata.
pub fn warn_meta(message: String, meta: a) -> Nil {
  log_meta(Warning, message, meta)
}

/// Logs an error message.
pub fn error(message: String) -> Nil {
  log(Error, message)
}

/// Logs an error message with metadata.
pub fn error_meta(message: String, meta: a) -> Nil {
  log_meta(Error, message, meta)
}

/// Logs a debug message.
pub fn debug(message: String) -> Nil {
  log(Debug, message)
}

/// Logs a debug message with metadata.
pub fn debug_meta(message: String, meta: a) -> Nil {
  log_meta(Debug, message, meta)
}

fn to_logging_level(level: Level) -> logging.LogLevel {
  case level {
    Emergency -> logging.Emergency
    Alert -> logging.Alert
    Critical -> logging.Critical
    Error -> logging.Error
    Warning -> logging.Warning
    Notice -> logging.Notice
    Info -> logging.Info
    Debug -> logging.Debug
  }
}
