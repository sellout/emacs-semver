{pkgs, ...}: {
  programs.emacs = {
    enable = true;
    extraConfig = ''
      (require 'semver)
    '';
    extraPackages = epkgs: [epkgs.semver];
  };
}
