{ inputs
, cell
,
}:
let
  # Since dashboards will exist as either JSON already, or will
  # be converted to JSON from Nix (ex: Grafonnix), dashboard attrs
  # are expected to have values of JSON strings.
  importAsJson = file: builtins.readFile file;
  # importGrafonnixToJson = ...;
in
{
  # See examples of custom defined dashboards, ex: at bitte-cells repo
  # clockworks = importAsJson ./dashboards/clockworks.json;

  # Upstream dashboards can be imported here, instead of directly
  # imported in the hydrationProfile.  This will allow easier
  # re-export of repo related dashboards which might have downstream
  # re-use.
  # inherit (inputs.X.Y.dashboards)
  # ;
}
