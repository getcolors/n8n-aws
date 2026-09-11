{ pkgs, ... }:
{
  languages.clojure.enable = true;
  languages.opentofu.enable = true;
  packages = with pkgs; [ ansible awscli2 babashka curl jq openssh postgresql rclone ];
}
