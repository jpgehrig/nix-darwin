{
  lib,
  username,
  useremail,
  useremailWork,
  ...
}: let
  # Public half of the 1Password SSH key "GitHub JP's MBP".
  # Safe to commit; the private key stays in the vault.
  sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBEAoKENKgXb2fqgDJAJcMuwddbVJdmxeQ1mo7BQaCHm";

  # 1Password's SSH agent socket (fixed path, set by the desktop app).
  onePasswordAgent = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
in {
  # `programs.git` generates ~/.config/git/config — remove any stale ~/.gitconfig
  home.activation.removeExistingGitconfig = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    rm -f ~/.gitconfig
  '';

  # Lets `git log --show-signature` verify your own commits locally.
  # GitHub verifies independently from the key registered on your account.
  home.file.".config/git/allowed_signers".text = ''
    ${useremail} ${sshPublicKey}
    ${useremailWork} ${sshPublicKey}
  '';

  # Route all SSH auth through the 1Password agent (Touch ID per use).
  # enableDefaultConfig = false silences an HM deprecation warning; the
  # defaults worth keeping are set explicitly below.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      compression = false;
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      hashKnownHosts = false;
      userKnownHostsFile = "~/.ssh/known_hosts";
      controlMaster = "no";
      controlPath = "~/.ssh/master-%r@%n:%p";
      controlPersist = "no";
      extraOptions.IdentityAgent = ''"${onePasswordAgent}"'';
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;

    # Work repos commit under the work identity. Generated into the Nix store
    # rather than read from ~/work/.gitconfig, so it cannot silently go missing.
    includes = [
      {
        condition = "gitdir:~/work/";
        contents.user.email = useremailWork;
      }
    ];

    settings = {
      user = {
        name = username;
        email = useremail;
        # SSH public key from the 1Password item "GitHub JP's MBP".
        # The private half never leaves the vault; signing goes through the
        # 1Password SSH agent and prompts for Touch ID.
        signingkey = sshPublicKey;
      };

      # Sign every commit and tag with the SSH key above.
      gpg = {
        format = "ssh";
        ssh.allowedSignersFile = "~/.config/git/allowed_signers";
      };
      commit.gpgsign = true;
      tag.gpgsign = true;

      # Always reach GitHub over SSH, even when a remote is cloned via HTTPS.
      url."git@github.com:".insteadOf = "https://github.com/";

      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;

      alias = {
        br = "branch";
        co = "checkout";
        st = "status";
        ls = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate";
        ll = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate --numstat";
        cm = "commit -m";
        ca = "commit -am";
        dc = "diff --cached";
        amend = "commit --amend -m";
        update = "submodule update --init --recursive";
        foreach = "submodule foreach";
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options.features = "side-by-side";
  };
}
