{
  config,
  lib,
  pkgs,
  ...
}: let
  codeDir = "${config.home.homeDirectory}/Code";

  # Path under ~/Code -> clone URL.
  # Local directory names intentionally differ from some remote names.
  repos = {
    "56kcloud/56k-slides" = "git@github.com:acp-io/56k-slides.git";
    "56kcloud/acp-website" = "git@github.com:56kcloud/56kcloud-website.git";
    "56kcloud/acpe-handbook" = "git@github.com:56kcloud/acpe-handbook.git";
    "56kcloud/acpe-odoo-assistant" = "git@github.com:56kcloud/56k-odoo-assistant.git";
    "56kcloud/agentic-workflows" = "git@github.com:acp-io/agentic-workflows.git";
    "56kcloud/apn-automation" = "git@github.com:56kcloud/apn-automation.git";
    "56kcloud/aws-competencies" = "git@github.com:56kcloud/aws-competencies.git";
    "56kcloud/aws-inventory" = "git@github.com:56kcloud/aws-inventory.git";
    "56kcloud/hyperstratus" = "git@github.com:56kcloud/hyperstratus.git";
    "56kcloud/iem-group-aws-migration" = "git@github.com:acp-io/iem-group-aws-migration.git";
    "edeltech/edeltech-website" = "git@github.com:edeltech/edeltech-website.git";
    "jpgehrig/stratus-local-os" = "git@github.com:jpgehrig/stratus-local-os.git";
  };

  cloneOne = path: url: ''
    if [ ! -e ${lib.escapeShellArg "${codeDir}/${path}"}/.git ]; then
      echo "code-repos: cloning ${url} -> ~/Code/${path}"
      if ! ${pkgs.git}/bin/git clone --recurse-submodules ${lib.escapeShellArg url} \
           ${lib.escapeShellArg "${codeDir}/${path}"}; then
        echo "code-repos: WARNING failed to clone ${url} (skipping)" >&2
      fi
    fi
  '';
in {
  # Clones any repo in the list above that isn't present yet. Existing
  # checkouts are never touched: no fetch, no pull, no reset. Removing an
  # entry here does NOT delete the local clone.
  #
  # Requires a usable SSH agent/key at activation time; individual failures
  # warn and are skipped rather than aborting the rebuild.
  home.activation.cloneCodeRepos = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg codeDir}
    ${lib.concatStrings (lib.mapAttrsToList cloneOne repos)}
  '';
}
