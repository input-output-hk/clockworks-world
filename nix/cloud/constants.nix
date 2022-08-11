{ inputs
, cell
,
}: {
  infra = {
    namespace = "infra";
    datacenters = [ "eu-central-1" ];
  };
  prod = {
    domain = "cw.iog.io";
    namespace = "prod";
    datacenters = [ "eu-central-1" ];
  };
}
