# NixOps tutorial

This repo is a practical tutorial for setting up [NixOps](https://nixos.org/nixops/) deployments.

It will walk you through various examples, from simpler to more complicated, explaining concepts and generalising on the way.

I will try to keep it up-to-date with new versions of Nix, nixpkgs and NixOps.

The examples assume basic familiarity with the Nix language, and NixOS configuration options, but you can also try to read through the tutorial and look up everything that you don't understand on the fly.


## Preface: Repo setup, fixed versions and `./mynix`

NixOps was originally designed to store its state in your home directory and use your globally configured version of nixpkgs.
To make things very reproducible, we will change some of its defaults. In particular we will:

* pin the version of [`nixpkgs`](https://github.com/NixOS/nixpkgs) using a `git submodule`
  * This means you must have cloned this repo with `git clone --recursive`, or run `git submodule update --init --recursive` after a normal clone.
  * It also lets us easily improve nixpkgs by making changes in this submodule (and then upstream them).
    This is very common when working with nixpkgs.
* pin the versions of `nix` and `nixops` to those that are in the submodule
* place all NixOps state in the current directory (in a file called `localstate.nixops`)

All of the above are done with the small script `./mynix`; read its code to check out what it does.

**You should run `./mynix` in front of all nix-related commands**, e.g. use `./mynix nixops` instead of `nixops` or `./mynix nix-build` instead of `nix-build`.

I recommend you to do the same for any production use of NixOps.

The files in this repo relevant to this pinning are (in case you want to copy them into your projects):

```
mynix
pinned-tools.nix
nix-channel/nixpkgs
```

## Prequisites

* An [Amazon AWS](http://aws.amazon.com) account
* AWS credentials set up in `~/.aws/credentials` (see [here](http://docs.aws.amazon.com/cli/latest/topic/config-vars.html#the-shared-credentials-file)); should look like this:

  ```ini
  [nixops-example-user]
  aws_access_key_id = AAAAAAAAAAAAAAAAAAAA
  aws_secret_access_key = ssssssssssssssssssssssssssssssssssssssss
  ```

  The account must have EC2 permissions.


## Tutorial 1: A simple web server

Read through `example-nginx-deployment.nix`, and check using the [NixOps manual](https://nixos.org/nixops/manual/) and the [NixOS options search page](https://nixos.org/nixos/options.html) what each of the options does.

    ./mynix nixops create example-nginx-deployment.nix -d example-nginx-deployment
    ./mynix nixops deploy -d example-nginx-deployment

Then run

    ./mynix nixops info -d example-nginx-deployment

copy the shown IP, and curl it from your machine using:

    curl IP

You should get `404 Not Found` in the output, but also `nginx`, indicating that your nginx is running.

If it does not work or hang, then your VPC/security group/firewall settings in AWS are probably off.

You can SSH into the machine you have declared there using:

    ./mynix nixops ssh -d example-nginx-deployment machine1

In the SSH session, run the `htop` monitoring tool.
You can quit it with `q`, and disconnect the SSH with `Ctrl+D`.

### Truly declarative configuration

Now remove the entry `pkgs.htop` from `environment.systemPackages`, and run

    ./mynix nixops deploy -d example-nginx-deployment

again (let's abbreviate this step "deploy").

If you SSH into the machine again, you will see that `htop` is no longer available.

This is a big difference to many other configuration management tools, where adding a line to install a package will install it, but deleting a that line will not uninstall it.

The property that after a `deploy` the machine will be exactly in the configured state (containing no more and no less) is called ["congruent" system management](https://blog.flyingcircus.io/2016/05/06/thoughts-on-systems-management-methods/).

### Changing a service

Now let's give our nginx some content.

Change the `services.nginx` attrset from

```nix
services.nginx = {
  enable = true;
};
```

into (again, look up each option on the [NixOS options search page](https://nixos.org/nixos/options.html))

```nix
services.nginx = {
  enable = true;
  virtualHosts."someDefaultHost" = {
    default = true; # makes this the default vhost if no other one matches
    locations."/" = {
      root = pkgs.writeTextDir "index.html" "Hello world!";
    };
  };
};
```

and deploy. You will see output like:

```
% ./mynix nixops deploy -d example-nginx-deployment
building all machine configurations...
these derivations will be built:
  /nix/store/g4y1hxlcj5vzrar9a436h3qm6h7hlngs-nginx.conf.drv
  /nix/store/9mylbbv0k2y812vaj257wg2nzarcwkqf-unit-script-nginx-pre-start.drv
  /nix/store/71165073r4y7pbas7dwdi1963lbbrqgs-unit-nginx.service.drv
  /nix/store/ajyk1ircw2f6k6cv0fqh5j4drjwjr6nv-system-units.drv
  /nix/store/skm2d9yazfgrkcwxqlsc9sf4zvai773a-etc.drv
  /nix/store/nd9hra6l0cv0lqqkhwky6qqx9shyrlhi-nixos-system-machine1-18.09.git.cd1b649.drv
  /nix/store/x9kgn5wrhjg53sm87xr5h3id36dp6dsf-nixops-machines.drv
building '/nix/store/g4y1hxlcj5vzrar9a436h3qm6h7hlngs-nginx.conf.drv'...
building '/nix/store/9mylbbv0k2y812vaj257wg2nzarcwkqf-unit-script-nginx-pre-start.drv'...
building '/nix/store/71165073r4y7pbas7dwdi1963lbbrqgs-unit-nginx.service.drv'...
building '/nix/store/ajyk1ircw2f6k6cv0fqh5j4drjwjr6nv-system-units.drv'...
building '/nix/store/skm2d9yazfgrkcwxqlsc9sf4zvai773a-etc.drv'...
building '/nix/store/nd9hra6l0cv0lqqkhwky6qqx9shyrlhi-nixos-system-machine1-18.09.git.cd1b649.drv'...
building '/nix/store/x9kgn5wrhjg53sm87xr5h3id36dp6dsf-nixops-machines.drv'...
machine1...> copying closure...
machine1...> copying 6 paths...
machine1...> copying path '/nix/store/y2h2idchc86qmdzzvp2wvxww9bzqkhwb-nginx.conf' to 'ssh://root@18.195.168.244'...
machine1...> copying path '/nix/store/5cmkg7arw5cazafdgynkl6y5s96v1vrf-unit-script-nginx-pre-start' to 'ssh://root@18.195.168.244'...
machine1...> copying path '/nix/store/0san3qp2xl9dz894ailylfypx44i809p-unit-nginx.service' to 'ssh://root@18.195.168.244'...
machine1...> copying path '/nix/store/29ibinhgl3a77d0fv4ffvhqlffa69dx9-system-units' to 'ssh://root@18.195.168.244'...
machine1...> copying path '/nix/store/4a81l4nsjry32gc43y4jxylwhc4hqdij-etc' to 'ssh://root@18.195.168.244'...
machine1...> copying path '/nix/store/jv8z2mv6j2kmsdqr19lm8zyjsfjzv20r-nixos-system-machine1-18.09.git.cd1b649' to 'ssh://root@18.195.168.244'...
example-nginx-deployment> closures copied successfully
machine1...> updating GRUB 2 menu...
machine1...> activating the configuration...
machine1...> setting up /etc...
machine1...> reloading user units for root...
machine1...> setting up tmpfiles
machine1...> restarting the following units: nginx.service
machine1...> activation finished successfully
example-nginx-deployment> deployment finished successfully
```

What's happening here?

* First `nixops` calls `nix` to build our machine declarations into the files involved.
  * The `.drv` files are descriptions of what is to be built (you can `cat` them), and they are built into corresponding outputs files or dirs, like the `...-nginx.conf` (`cat` it!).
  * The top-level one for the machine we have declared is the `...-nixos-system-machine1...` one. `ls -l` it to see that it's the full root file system for that machine!
  * The `...-nixops-machines.drv` describes our entire network of machines (we only have 1 for now).
* Then `nixops` calls `nix-copy-closure`, copying each file involved and the recursive dependencies to each machine (but only those that aren't already there).
* Then `nixops` runs the NixOS `switch-to-configuration` script on each machine, that activates the new machine configuration.

**Notice how it figured out that only the changed nginx service needed to be reloaded** (`restarting the following units: nginx.service`), without us having to tell that explicitly!

Now you should be able to

    curl IP

again and see the output `Hello World!`.

### Destroying the deployment

Don't forget to destroy the created machines with:

    ./mynix nixops destroy -d example-nginx-deployment

You can pass the `--confirm` option if you don't want it to ask interactive questions.
