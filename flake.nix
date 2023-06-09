rec {
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
  outputs = args: let
    systems = {
      "x86_64-linux" =
        if builtins ? fetchClosure
        then
          builtins.fetchClosure {
            fromPath = "/nix/store/a6gvbcvw9mwg73p9plfxc820gr8i1hdr-busybox-static-x86_64-unknown-linux-musl-1.36.0";
            toPath = "/nix/store/w5xia890vqqxka41ka8d0mbbzzs4ycwr-busybox-static-x86_64-unknown-linux-musl-1.36.0";
            fromStore = "https://cache.nixos.org";
          }
        else args.nixpkgs.legacyPackages.x86_64-linux.pkgsStatic.busybox;
      "x86_64-darwin" = {};
      "aarch64-linux" = {};
      "aarch64-darwin" = {};
    };
  in {
    apps =
      builtins.mapAttrs (system: busybox: {
        default = {
          type = "app";
          program = let
            drv = derivation {
              name = "tools";
              inherit system;
              builder = busybox + "/bin/sh";
              args = [
                "-c"
                ''
                  export PATH=${busybox}/bin
                  cat <<'EOF' > $out
                  #!/bin/sh
                  set -eou pipefail
                  export NIX_CONFIG='experimental-features = nix-command flakes fetch-closure'
                  function buildtime(){
                    nix derivation show "$1" | \
                      jq '.[].inputDrvs|to_entries[]|"\(.key)^\(.value|join(","))"' -r | \
                      xargs nix build --dry-run --json 2>/dev/null | \
                      jq '.[].outputs[]' -r
                  }
                  function uncached(){
                    local success
                    while read storePath; do
                      success=
                      for store in "$@"; do
                        if nix path-info --store "$store" "$storePath" >/dev/null 2>&1 ; then
                          success=1
                        fi
                      done
                      [ -z "$success" ] && echo "$storePath"
                    done
                  }
                  function buildtime_uncached(){
                    local drv="$1"
                    shift
                    buildtime "$drv" | uncached "$@"
                  }
                  "$@"
                  EOF
                  chmod +x $out
                ''
              ];
            };
          in "${drv}";
        };
      })
      systems;
  };
}
