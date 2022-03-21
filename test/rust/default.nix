{ pkgs
, theta-rust-src ? ../../rust
}:

let
  inherit (pkgs) theta;

  theta-rust = builtins.filterSource
    (path: type:
      type != "directory" || builtins.baseNameOf path != "target")
    theta-rust-src;

  # Set up the *source* for the Rust test code:
  #
  #  1. Set up Cargo.lock and Cargo.toml (see above)
  #  2. Copy over Theta modules used for testing
  #  3. Copy over non-generated Rust files (src/*rs)
  #  4. Run theta rust for each module in modules
  #
  # Once these four steps are done, we have a directory that we can
  # build and test with Naersk, including the *.rs files *generated by
  # Theta*.
  #
  # This definitely feels like a bit of a hack, but I couldn't figure
  # out a better way to deal with building *generated* Rust code in
  # Nix, or for depending on a Rust library also packaged with Nix (ie
  # theta-rust).
  theta-generated-rust = pkgs.stdenv.mkDerivation {
    name = "theta-generated-rust";
    src = ./.;

    installPhase = ''
      mkdir -p $out

      # Theta's Rust support library
      cp -r ${theta-rust} $out/theta-rust

      cp $src/Cargo.toml $out/Cargo.toml
      cp $src/Cargo.lock $out

      # Copy over Rust source for tests (src/*.rs from this directory)
      mkdir -p $out/src
      cp $src/src/*.rs $out/src

      # Copy over Theta modules
      mkdir -p $out/modules
      cp $src/modules/*.theta $out/modules
      export THETA_LOAD_PATH=$out/modules

      # Generate Rust code for each Theta module
      for module_name in $out/modules/*.theta
      do
        module=$(basename $module_name .theta)
        echo "$module.theta ⇒ $module.rs"
        ${theta}/bin/theta rust -m $module > $out/src/$module.rs
      done
    '';
  };
in pkgs.naersk.buildPackage {
  src = theta-generated-rust;

  # Without this, the theta-rust directory created in
  # theta-generated-rust (cp -r ${theta-rust} $out/theta-rust) gets
  # filtered out by Naersk.
  copySources = ["theta-rust"];

  remapPathPrefix = true;
  doCheck = true;
}
