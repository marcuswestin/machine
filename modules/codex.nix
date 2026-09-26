{ ... }:
{
  # Codex reads this lower-priority system layer, while its user file stays
  # writable for trust decisions and app-generated configuration.
  environment.etc."codex/config.toml".text = builtins.readFile ../config/codex/config.toml;
}
