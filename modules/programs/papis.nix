{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.programs.papis;

  defaultLibraries = lib.remove null (
    lib.mapAttrsToList (n: v: if v.isDefault then n else null) cfg.libraries
  );

  settingsIni = (lib.mapAttrs (n: v: v.settings) cfg.libraries) // {
    settings = cfg.settings // {
      "default-library" = lib.head defaultLibraries;
    };
  };

in
{
  meta.maintainers = [ ];

  options.programs.papis = {
    enable = lib.mkEnableOption "papis";

    package = lib.mkPackageOption pkgs "papis" { nullable = true; };

    settings = mkOption {
      type =
        with types;
        attrsOf (oneOf [
          bool
          int
          str
        ]);
      default = { };
      example = lib.literalExpression ''
        {
          editor = "nvim";
          file-browser = "ranger"
          add-edit = true;
        }
      '';
      description = ''
        Configuration written to
        {file}`$XDG_CONFIG_HOME/papis/config`. See
        <https://papis.readthedocs.io/en/latest/configuration.html>
        for supported values.
      '';
    };

    libraries = mkOption {
      type = types.attrsOf (
        types.submodule (
          { config, name, ... }:
          {
            options = {
              name = mkOption {
                type = types.str;
                default = name;
                readOnly = true;
                description = "This library's name.";
              };

              isDefault = mkOption {
                type = types.bool;
                default = false;
                example = true;
                description = ''
                  Whether this is a default library. There must be exactly one
                  default library.
                '';
              };

              settings = mkOption {
                type =
                  with types;
                  attrsOf (oneOf [
                    bool
                    int
                    str
                  ]);
                default = { };
                example = lib.literalExpression ''
                  {
                    dir = "~/papers/";
                  }
                '';
                description = ''
                  Configuration for this library.
                '';
              };
            };
          }
        )
      );
      description = "Attribute set of papis libraries.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.libraries == { } || lib.length defaultLibraries == 1;
        message =
          "Must have exactly one default papis library, but found "
          + toString (lib.length defaultLibraries)
          + lib.optionalString (lib.length defaultLibraries > 1) (
            ", namely " + lib.concatStringsSep "," defaultLibraries
          );
      }
    ];

    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    xdg.configFile."papis/config" = lib.mkIf (cfg.libraries != { }) {
      text = lib.generators.toINI { } settingsIni;
    };
  };
}
