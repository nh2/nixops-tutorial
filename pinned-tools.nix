let
  pkgs = import <nixpkgs> {};
in
  pkgs.symlinkJoin {
    name = "mynix";
    paths = [
      # Tools in here are made available to `./mynix`.
      pkgs.nix
      pkgs.nixops
    ];
  }
