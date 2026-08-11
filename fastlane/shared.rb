# frozen_string_literal: true

# Shared release-pipeline constants and helpers, loaded by both Appfile and
# Fastfile so a value they both need (the team ID) lives in exactly one place
# instead of a hardcoded copy in each.

TEAM_ID_DEFAULT = "C36L3X7U5T"

# Resolve ENV[name] as a string ("" when unset), falling back to `default` when
# it is empty. Collapses the ENV["X"].to_s.empty? ? fallback : ENV["X"] shape
# that otherwise repeats at every env-with-default site.
def env_or(name, default = "")
  value = ENV[name].to_s
  value.empty? ? default : value
end
