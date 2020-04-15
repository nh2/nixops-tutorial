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
* The tutorial currently [requires](https://github.com/NixOS/nixops/issues/260) running the steps on Linux.


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

If you also want to delete all local information about past versions of the deployment, you can run:

    ./mynix nixops delete -d example-nginx-deployment


## Tutorial 2: Upgrading the OS and doing rollbacks

We've deployed a simple web server -- boring! Let's do something that's traditionally difficult.

If you have upgraded other Linux distributions before, you may remember it as an unpleasant process.
For example, in Ubuntu's `do-release-upgrade`, there are often large amounts of waiting, interspersed with occasional questions that you need to answer, such as how to merge your own modified config files with newer versions provided by the OS upstream.
That means you cannot just step away and let an upgrade complete by itself.
Further, upgrades often fail, and many distributions provide only assisted upgrades, not downgrades. For example, there exists no `do-release-downgrade` on Ubuntu.

With NixOps (and NixOS in general), these issues are addressed on a fundamental level.

* Because machines are configured declaratively, there are no interactive questions to be asked.
* Because NixOS configurations are immutable and stay on disk until your garbage-collect them, you can easily roll back to _any_ previous configuration.
  * One caveats applies: _Stateful_ software like `consul`, that writes its own mutable data into `/var` and auto-upgrades its schema when a new version is launched, may not allow to read a newer schema version with an older version of the software.
    You need to read the Changelogs of the software you use to determine this.

### Upgrading the OS

Let's try to upgrade our running server from the version of `nixpkgs` (and thus, NixOS) that is pinned in this git repository's `nix-channel/nixpkgs` submodule to a newer version.

This will provide us with a newer kernel, newer nginx, newer everything.

Prerequisites:

* Deploy your server as in Tutorial 1, but do not shut it down at the end.

You can also SSH into the server and run `systemctl status nginx.service` (you can press `q` to quit the pager and get back to the shell if you aren't already).
It should show you a line like:

```
           ├─2868 nginx: master process /nix/store/j8kzb88g64bk2baxmz94r074kv84yl32-nginx-1.14.1/bin/nginx -c /nix/store/9g1affc46wvyahihk1d4gq52j8vqagjw-nginx.conf -p /var/spool/nginx
```

Because Nix's store paths include the versions of packages in the directory name, you can easily determine that you're running `nginx-1.14.1` here.

Also run `uname -a` to see that your Linux kernel version is e.g. `4.14.111`.

Now execute the upgrade:

1. Upgrade the `nix-channel/nixpkgs` submodule to a newer version:
  * `cd nix-channel/nixpkgs/`
  * `git fetch` to fetch the latest commits.
  * `git checkout f6c1d3b1`

    That is the latest commit on the `release-19.09` branch at the time of writing.
    You could `git checkout origin/release-19.09` here, but we use an explicit commit for full reproducibility of this tutorial.
  * `cd ../..` back into the top-level directory.
2. Deploy with:

   ```sh
   ./mynix nixops deploy -d example-nginx-deployment
   ```

That's it. If you now SSH into the machine and run `systemctl status nginx.service` again, you should observe that you are now running the newer version `nginx-1.16.1`.

NixOps restarted all changed services for you, but running `uname -a` you can see that the kernel version is still the same as before.
That is because upgrading the kernel requires a reboot.

Deploy with reboot to ensure everything is upgraded:

```sh
./mynix nixops deploy -d example-nginx-deployment --force-reboot
```

Now `uname -a` should show the new kernel version.

### Rolling deployments

In production you likely want to upgrade one machine after the other ("rolling") as to not interrupt your users.

As of writing, NixOps does not have built-in functionality for that.

Instead, simply deploy individual machines sequentially:

```sh
./mynix nixops deploy -d example-nginx-deployment --force-reboot --include machine1
./mynix nixops deploy -d example-nginx-deployment --force-reboot --include machine2
# ...
```

It is recommended that you check that each machine is working fine before proceeding to the next, for minimal disruption.

### Rolling back

There are 2 methods you can use to roll back:

* Using `nixops rollback`.
* Simply bringing our configuration files into the old state and deploying again.

The second option is usually better, because it is more declarative, and you can commit your rollback into version control, like any other change.
But `nixops rollback` can be useful because it is even faster, and it is useful to know how it works because it showcases NixOS's immutability.

#### Execute a rollback using `nixops` rollback

1. List the past deployment generations using:

    `./mynix nixops list-generations -d example-nginx-deployment`. Example output:

    ```
    1   2020-04-14 20:00:00
    2   2020-04-14 20:15:01   (current)
    ```
2. Roll back to generation `1` using:

    `./mynix nixops rollback 1 -d example-nginx-deployment`

    You will see output like:

    ```
    switching from generation 2 to 1
    ...
    machine1..........................> activation finished successfully
    ```

As before, you can append `--force-reboot` to reboot into the changed kernel.

The rollback only takes 10 seconds for me, or 18 seconds including reboot.

#### Execute a rollback by checking out older nix files

1. `(cd nix-channel/nixpkgs/ && git checkout -)`

    This is similar to what we did when upgrading, but written as a one-liner, using `(` subshell parenthesis `)` to avoid having to `cd` back, and using `git checkout -` to checkout whatever the previously checked out commit was (you could also give an explicit commit).
2. Deploy `./mynix nixops deploy -d example-nginx-deployment --force-reboot`

And for the fun of it (as well as for Tutorial 3), let's switch again to the newer OS version:

```sh
(cd nix-channel/nixpkgs/ && git checkout f6c1d3b1)
./mynix nixops deploy -d example-nginx-deployment --force-reboot
```

By now you should have a feeling for how fast doing OS upgrades is with NixOps.


## Tutorial 3: Adding HTTPs

In the previous tutorials, we set up an HTTP server with nixops, and could open its IP address in our browser to see the returned content.

But modern sites should usually run on HTTPS!

Let's use [Let's Encrypt](https://en.wikipedia.org/wiki/Let%27s_Encrypt)'s _Automated Certificate Management Environment_ (ACME) to automatically get HTTPs certificates for our nginx web server.

Prequisites:

* This requires that you have executed Tutorial 2 to upgrade to a newer NixOS, because current Let's Encrypt no longer accepts the older ACME protocol.
* You need to own a domain name to point at your server's IP.
  Ephemeral domains like AWS's `ec2-1-2-3-4.eu-central-1.compute.amazonaws.com` are intentionally rejected by Let's Encrypt.
  If you do not have a domain name, you must skip executing this tutorial; but still read it!

Change your deployment:

1. Make a variable to contain your domain name:

    ```diff
    -  machine1 = { resources, nodes, ... }: {
    +  machine1 = { resources, nodes, ... }:
    +  let
    +    dnsName = "machine1.nixops-tutorial.aws.nh2.me";
    +  in
    +  {
    ```

    Replace `machine1.nixops-tutorial.aws.nh2.me` by whatever your domain is.

2. Point your domain name to your server's public IP (from `./mynix nixops info -d example-nginx-deployment`) by creating an DNS `A` record to it with your domain registrar.

    If you use AWS's [Route53](https://aws.amazon.com/route53/) for your domains, like I do for my AWS _Hosted Zone_ `aws.nh2.me`, then you can also let NixOps set it to your server's IP automatically, by adding next to the other `deployment.ec2` options:

    ```nix
    deployment.route53 = {
      accessKeyId = awsKeyId;
      hostName = dnsName;
      ttl = 1;
    };
    ```
3. Open the HTTPS port 443 in the firewall:

    ```diff
         networking.firewall.allowedTCPPorts = [
           80 # HTTP
    +      443 # HTTPs
         ];
    ```
4. Change your nginx config to reply to your `dnsName`, enable SSL and automatic ACME certificate fetching:

    ```diff
         # Enable nginx service
         services.nginx = {
           enable = true;
    -      virtualHosts."someDefaultHost" = {
    +      virtualHosts.${dnsName} = {
             default = true; # makes this the default vhost if no other one matches
             locations."/" = {
               root = pkgs.writeTextDir "index.html" "Hello world!";
             };
    +        addSSL = true;
    +        enableACME = true;
           };
         };
    ```

Now deploy.

You should now be able to visit your domain in your browser with `https://` prefix.

If it does not work, there was probably an issue getting a certificate from Let's Encrypt.
In that case, SSH into your server and run (replace the domain by yours accordingly):

```sh
journalctl -e -u acme-machine1.nixops-tutorial.aws.nh2.me.timer
```

This will show you the last errors of the service that fetches the certificate, hopefully allowing you to diagnose the problem.
