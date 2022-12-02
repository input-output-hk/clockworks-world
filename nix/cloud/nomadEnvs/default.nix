{
  inputs,
  cell,
}: {
  infra = {
    database = inputs.bitte-cells.patroni.nomadCharts.default cell.constants.infra;
    matomo = inputs.cells.matomo.jobs.default cell.constants.infra;
    matterbridge = inputs.cells.matterbridge.jobs.default cell.constants.infra;
  };

  prod = {
    # matomo = import ./matomo {
    #   inherit inputs cell;
    #   inherit (cell.constants.prod) namespace;
    # };
    matomo = inputs.cells.matomo.jobs.default cell.constants.prod;
  };
}
