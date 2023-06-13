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
      "aarch64-linux" = args.nixpkgs.legacyPackages.aarch64-linux.pkgsStatic.busybox;
      "x86_64-darwin" = args.nixpkgs.legacyPackages.x86_64-darwin.pkgs.busybox;
      "aarch64-darwin" = args.nixpkgs.legacyPackages.aarch64-darwin.pkgs.busybox;
    };
  in {
    apps =
      builtins.mapAttrs (system: busybox: let
        pkgs = args.nixpkgs.legacyPackages.${system};
        script = ''
            set -eu
            set -o pipefail
            export NIX_CONFIG='experimental-features = nix-command flakes fetch-closure'

            # The installable's build-closure.
            build_closure(){
              nix derivation show "$1" | \
                jq '.[]|[(.inputDrvs|to_entries[]|"\(.key)^\(.value|join(","))"),.inputSrcs[]][]' -r | \
                nix build --stdin --dry-run --json 2>/dev/null | \
                jq '.[]| if has("outputs") then (.outputs[]) else (.path) end' -r
            }

            # The intstallable's run-closure.
            run_closure(){
              nix derivation show "$1" | \
                jq '.[].outputs[][]' -r
            }

            uncached(){
              local success
              if [ "$#" -eq 0 ]; then
                set -- $(nix show-config | sed -n "s/^substituters = \(.*\)/\1/p");
                echo "info: no substituters provided, using these from nix config: $@" >&2
              fi
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

            build_closure_uncached(){
              if [ "$#" -eq 0 ] ; then set -- - ; fi
              if [ "$1" = "-" ]; then
                shift
                while read drv; do
                   build_closure "$drv" | uncached "$@"
                done
              else
                local drv="$1"
                shift
                build_closure "$drv" | uncached "$@"
              fi
            }

            run_closure_uncached(){
              if [ "$#" -eq 0 ] ; then set -- - ; fi
              if [ "$1" = "-" ]; then
                shift
                while read drv; do
                   run_closure "$drv" | uncached "$@"
                done
              else
                local drv="$1"
                shift
                run_closure "$drv" | uncached "$@"
              fi
            }
            verbose(){
              set -x
              "$@"
            }
            "$@"
            EOF
            chmod +x $out
        '';
        drvAttrs = {
          name = "tools";
          inherit system;
          builder = busybox + "/bin/sh";
        };
      in {
        default = {
          type = "app";
          program = "${derivation (drvAttrs // {

            args = ["-c" ''
              export PATH=${busybox}/bin:"$PATH"
              cat <<'EOF' > $out
              #!${pkgs.bash}/bin/bash
              export PATH=${with pkgs; lib.makeBinPath [ bash jq gnused gitMinimal nixUnstable ]}
              ${script}
            ''];
          })}";
        };
        bare = {
          type = "app";
          program = "${derivation (drvAttrs // {

            args = ["-c" ''
              export PATH=${busybox}/bin:"$PATH"
              cat <<'EOF' > $out
              ${script}
            ''];
          })}";
        };
      })
      systems;
  };
}
