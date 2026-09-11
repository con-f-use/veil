{
  writeShellApplication,

  coreutils,
  jq,
  libargon2,
  mkpasswd,
  openssh,
}:
writeShellApplication {
  name = "veil";
  runtimeInputs = [
    coreutils
    jq
    libargon2
    mkpasswd
    openssh
  ];
  text = builtins.readFile ./veil.sh;
  checkPhase = "";
}
