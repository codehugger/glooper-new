defmodule Glooper.Repo do
  use Ecto.Repo,
    otp_app: :glooper,
    adapter: Ecto.Adapters.SQLite3
end
