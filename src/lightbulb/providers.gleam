import lightbulb/providers/data_provider.{type DataProvider}
import lightbulb/providers/http_provider.{type HttpProvider}

/// Represents a pluggable set of providers used by lightbulb.
pub type Providers {
  Providers(data: DataProvider, http: HttpProvider)
}
