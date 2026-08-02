{pkgs, ...}: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        myriad-dreamin.tinymist
      ];
      userSettings = {
        "tinymist.serverPath" = "${pkgs.tinymist}/bin/tinymist";
      };
      keybindings = [
        {
          key = "shift+enter";
          command = "workbench.action.terminal.sendSequence";
          args.text = "\\\r\n";
          when = "terminalFocus";
        }
      ];
    };
  };
}
