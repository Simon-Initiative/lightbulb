import lightbulb/providers/data_provider.{type DataProvider}
import lightbulb/providers/http_provider.{type HttpProvider}

pub type Providers {
  Providers(data: DataProvider, http: HttpProvider)
}
