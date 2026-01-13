{ pkgs, ... }:
let
in
{
  home.packages = [
    pkgs.devenv
    pkgs.direnv
    pkgs.minio-warp
    pkgs.graphviz
    pkgs.awscli2
    pkgs.s3cmd
    pkgs.grpcurl
    pkgs.lsof
  ];
}
