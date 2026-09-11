Veil
====

> [!CAUTION]
> The contents of this repos is purely for education.
> This is not a safe or secure product to use.
> It comes with no warranties, implied or otherwise, nor support or
> guarantee of fitness for purpose.
> Do not use this!
> Rather learn from it, when you're making your own, or trying to
> understand other tools.

Simple education-only secret side-loading and deployment tool for
[NixOS](https://nixos.org).

Many newcomers to nix struggle with secret management tools and deployment.
They also tend to struggle with writing NixOS modules as well
as nix-packaging software.
It does not help that most NixOS modules in nixpkgs are quiet large.
They do a lot of things and require domain knowledge and familiarity with
the special style-requirements & best practices in nixpkgs - all things beginners rarely have.
Secret management tools tend to be inaccessible in a similar way.

It's very common not to understand the lingo, the basic concepts and
to struggle seeing the forest for the trees.

Veil aims to be as simple as possible, to demonstrate the concepts that
most of these tools are based on and cut anything that might confuse
a beginner at NixOS deployment and secret management.

> [!IMPORTANT]
> Essentially, every nix secret tool is "just" about declaring how to get the secret,
> how to manage what can access it and how to store it securely.


Required Reading
================

You should have a working knowledge of these things:

- [Nix language](https://nixcloud.io/tour)
- [Packaging with nix](https://nix.dev/tutorials/packaging-existing-software)
- [NixOS Module System](https://nix.dev/tutorials/module-system/a--module/)
  ([2](https://nix.dev/tutorials/module-system/deep-dive))
- How to lookup existing NixOS modules, functions and pacakges from
  [nixpkgs](https://github.com/NixOS/nixpkgs):
  * [Option Search](https://search.nixos.org/options?channel=unstable)
  * [Package Search](https://search.nixos.org/packages?channel=unstable)
  * [Function Search](https://noogle.dev)
- [Shell Scripting](https://github.com/dylanaraps/pure-bash-bible)
- [Secure Shell (SSH)](https://wiki.archlinux.org/title/OpenSSH)

Usage
=====

Say you want to provision a new NixOS machine that requires secrets.
Say you want to keep track of these secrets, in case you need to provision
the same or similar machines again.
The
["Installation"](https://nixos.org/manual/nixos/stable/#sec-installation)
section in NixOS manual tells you to boot a live
medium.
You dutifully partition disks, you create file systems, you mount those.
Then you write a NixOS configuration, you want to install.
Veil allows you to declare secret files.
It also allows you to declare which user and group on the system should
own them, and specify a command or script to receive them.

```nix
# File: configuration.nix
{ config, lib, pkgs, ... }: {
  # So the tool knows where to deploy to
  veil.deployUser = "me";
  veil.deployHost = config.networking.ipv4.address[0].address;

  # Actual secret definition
  veil.secrets.somesecret = {
    target = "/var/lib/secrets/somesecret";       # <-- we reference this later
    script = "gopass -o show somePath/someSecret";    # or: script = builtins.readFile ./some/file.sh;
    user = "me";
    group = "admin";
  };

  # Using the secret:
  services.forgejo = {
    enable = true;
    database.passwordFile = config.veil.secrets.somesecret.target;
    # `config` is self-referential and refers to this config, so we
    # refer to the same path defined ~10 lines above

    # Note: If the files is needed before the first boot, there's ways
    # to solve this, but we treat it as out of scope for now.
    # Usually, they're not really and you can just comment out the
    # consumer at first or restart the service after the file is pushed.
  };

  # ...
}
```

You install the system and let it boot.

You run:

```
veil push <config-name>
```

Veil runs the scripts for all secrets and puts their output in the
target location on the system, with the desired ownership.
If the secret changes, you run the script again and notify consumers
of the secret to reload it, if necessary - which could be part of the
script.

For convenience, veil can parse the configuration and deploy the
configuration for you:

```
veil deploy <confg-name>
```

Which is mostly equivalent to running:

```
nixos-rebuild switch \
  --option 'extra-experimental-features' 'nix-command flakes' \
  --flake './#nixosConfigurations."<config-name>"' \
  --target-host 'me@<some-ip-address>' \
  --use-remote-sudo \
  --ask-sudo-password
```

Just more convenient, thanks to getting the necessary data from the
NixOS configuration and the veil module options declared.
This is where proper deployment tools like colmena get really elaborate.


Principle of Operation
======================

The core flow of data is as follows:

1. The user runs the `veil` shell script and supplies the name of a
   NixOS configuration from a flake in the current directory or above
   it (nix searches upwards in the file system hierarchy).
2. The shell script calls nix to get data about said configuration.
   Most of this data is declared in the configuration via the `veil` 
   NixOS module options.
3. This data includes at least one string,
   most likely a short shell snippet that is written to a temporary 
   file and interpreted as an executable.
   That executable is assumed to print a secret string to `stdout`.
4. Those secrets strings are then written to their final destination,
   either on the system that called `veil`,
   or, if the data specifies it, via SSH to a remote host.

So the most important parts are:

- NixOS module in `./modules/veil/`.
- `veil` shell script in `./packages/veil/veil.sh`.
- The nix invocation to interface the two with each other:
  ```
  nix eval "./#nixosConfigurations.$machine.config.veil" --json
  ```
- The user-defined script snippets that actually retrieve the secrets.
  Most of the time this will use a password manager's command-line
  interface, e.g.:
  ```
  gopass -o show somePath/someSecret
  ```

The rest ist just glue to tie these parts together and write whatever
the user-defined snippets return to files in the correct locations with
the correct ownership.

Security Considerations
=======================

All this is, of course, a terrible idea.

You should not write secrets to files, even if they come from a
password manager and only remain on the deploying system for a short
time.

You should not have them in clear text, especially not as command
line arguments, because other processes can read the executable line
via various means, if they're fast enough.

Secrets should be encrypted at rest on the target system that stores
them.
NixOS' standard solution is
[systemd-credentials](https://systemd.io/CREDENTIALS/)
which can use your machines TPM2 chip for encryption
([example](https://github.com/NixOS/nixpkgs/blob/fc4d0ee4baafd666d0ac67d94daeaa70c5a2b96c/nixos/tests/systemd-credentials-tpm2.nix#L4)).
Sops-nix and Age-nix encrypt secrets in the nix store, too, but are
vulnerable to store-now-decrypt-later attacks and often decrypt to
out-of-store filesystem locations.
Anyway, in-store encryption, wouldn't solve the problem that sometimes
secrets are needed at eval- or build-time or during the first boot.
We will get into that later.

Ideally, the machine would securely retrieve its own secrets
and only require a single "secret-zero" that it is deployed with to do so.
A common approach would be to have a systemd services that handles
secret retrieval and keep them up to date.
Further, it would be nice, if that secret-zero could only used to
retrieve other secrets, "switched hot", once the deployer confirmed
it made itself to the target machine un-intercepted.

The secrets would be short-lived, rotated often and updated automatically.
The machine would fetch them from some central secret-management system like
[OpenBao](https://github.com/openbao/),
where it only has access to its own secrets and access would be auditable
and monitored.

We cannot get into all of this and there's no one solution for nix
that satisfies it all.

As stated, this is a learning resource to demonstrate the
core-principles almost every nix secret management and deployment tool
uses.

You should use things like
[colmena](https://github.com/nix-community/colmena),
[deploy-rs](https://github.com/serokell/deploy-rs),
[sops-nix](https://github.com/Mic92/sops-nix),
[age-nix](https://github.com/ryantm/agenix),
[systemd-credentials](https://systemd.io/CREDENTIALS/),
[OpenBao](https://github.com/openbao/),
[gopass](https://github.com/gopasspw/gopass),
or
[secretspec](https://github.com/cachix/secretspec),
just to name a few.

It is not a ready to use tool, but you can make it one,
hence why the `veil.secrets.<name>.script` part is so general.
Remember:

> [!IMPORTANT]
> Essentially, every nix secret tool is "just" about declaring how to get the secret,
> how to manage what can access it and how to store it securely.


Why Side-Loading or the problem with secrets and Nix(OS)
========================================================

ToDo...

One of the oldest open issues with nix: https://github.com/NixOS/nix/issues/8
Numerous proposals over the years: https://github.com/NixOS/rfcs/pull/143

Crux: Secrets used at eval or boot time end up in the world-readable nix-store
and on/or builders, because the store has no access management nor
encryption or private parts (:snicker:).


Runtime vs. Boot-time vs. Build-time vs. Eval-time Secrets or the chicken and egg with user passwords
=====================================================================================================

ToDo...


Usage demonstration in development VM
=====================================

ToDo...
