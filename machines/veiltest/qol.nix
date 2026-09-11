{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  environment.homeBinInPath = true;

  environment.enableAllTerminfo = true;

  programs.git = {
    enable = true;
    lfs.enable = true;
    config.alias = {
      st = "status";
      ci = "commit";
      co = "checkout";
      cl = "clone";
      d = "diff";
      dc = "diff --cached";
      l = "log";
      lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cD) %C(bold blue)<%an>%Creset' --abbrev-commit";
    };
  };

  programs.ssh.extraConfig = ''
    Host github hub gh
      HostName github.com
      User git
  '';

  programs.neovim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
    defaultEditor = true;
  };

  environment.etc."inputrc".text = ''
    "\e[Z": menu-complete
    "\e\e[C": forward-word
    "\e\e[D": backward-word
    "\e[A": history-search-backward
    "\e[B": history-search-forward
  '';

  environment.etc.nixpkgs.source = pkgs.path;
  environment.etc.flake-src.source = inputs.self;
  nix = {
    settings = {
      trusted-users = [ "@wheel" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };
}
