defmodule WithRetry.MixProject do
  use Mix.Project

  def project do
    [
      app: :with_retry,
      description:
        "Additional `with_retry` code block used for writing with statements that have retry logic.",
      version: "1.0.0",
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      # dialyzer: [ignore_warnings: "dialyzer.ignore-warnings", plt_add_deps: true],

      # Docs
      name: "with_retry",
      source_url: "https://github.com/IanLuites/with_retry",
      homepage_url: "https://github.com/IanLuites/with_retry",
      docs: [
        main: "readme",
        extras: ["README.md", "LICENSE.md"]
      ]
    ]
  end

  def package do
    [
      name: :with_retry,
      maintainers: ["Ian Luites"],
      licenses: ["MIT"],
      files: [
        # Elixir
        "lib/with_retry",
        "lib/with_retry.ex",
        "mix.exs",
        "README*",
        "LICENSE*"
      ],
      links: %{
        "GitHub" => "https://github.com/IanLuites/with_retry"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Dev / Test
      {:analyze, "~> 0.1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", optional: true, runtime: false, only: :dev}
    ]
  end
end
