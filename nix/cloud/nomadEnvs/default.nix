{
  inputs,
  cell,
}: {
  infra = {
    database = inputs.bitte-cells.mariadb.nomadJob.default cell.constants.infra;
  };

  prod = {
    # matomo = import ./matomo {
    #   inherit inputs cell;
    #   inherit (cell.constants.prod) namespace;
    # };
    matomo = inputs.cells.matomo.jobs.default cell.constants.prod;
  };
}
