{
  description = "Real-time audio in NixOS";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    disko.url = "github:nix-community/disko";
  };
  outputs = { self, nixpkgs, disko }: {
    nixosModules.ez-disko-vps = import ./default.nix;
    nixosModules.default = self.nixosModules.ez-disko-vps;
  };
}
