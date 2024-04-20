<?php

# Fill in these settings as appropriate to you.

# Set the hostname for the guest.
$hostname = "template-debian-12";

# Specify your username and password
$username = "debian";
$password = "debian";

# Set a random salt string here for password hashing
$randomSaltString = 'setARandomStringHere';

# Specify the public keys of the private-keys you wish to login with.
$sshPublicKeys = [
    'ssh-rsa AAAAB3Nz...',
];

##### End of settings. Do not edit below this line #######
##########################################################

# Need to hash passwords this way
$hashedPassword = crypt($password, '$6$rounds=4096$' . $randomSaltString . '$');

# Cloud-init users and groups documentation: https://bit.ly/3XFhEM0
$mainUser = [
    'name' => $username,

    # This will set the password even if the user already exists. If you don't want to allow overwriting an
    # existing user password, use 'passwd' instead
    'hashed_passwd' => $hashedPassword,

    # Allow the user to run sudo commands without a password.
    'sudo' => 'ALL=(ALL) NOPASSWD:ALL',

    # Add the user to groups if you wish
    #'groups' => [],

    'shell' => "/bin/bash",

    # Specify the lock password, which specifies whether the user can log in to the terminal with a password
    # (not to be confused with ssh_pwauth, which is for SSH connections).
    # Debian 12 likes the older lock-passwd instead of lock_passwd it appears.
    'lock-passwd' => false, # old versions are lock-passwd, new versions are lock_passwd

    'ssh_authorized_keys' => $sshPublicKeys,
];

$users = [
    $mainUser
];

$config = [
    'hostname' => $hostname,

    # Set this to true if you wish for cloud-init to set the /etc/hosts file on every boot.
    # THis would set the new hostname.
    # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#update-etc-hosts
    'manage_etc_hosts' => false,

    # Allow password authentication for SSH.
    'ssh_pwauth' => false,

    # disable root login
    'disable_root' => true,

    'users' => $users,
];


$content = '#cloud-config' . PHP_EOL;

// create the yaml content, removing the optional YAML start/end dividers that nobody appears to use.
$yamlContent = yaml_emit($config);
$lines = explode(PHP_EOL, $yamlContent);
unset($lines[0]);
unset($lines[count($lines)-1]);
$content = $content . implode(PHP_EOL, $lines);

file_put_contents('cloud-init.cfg', $content);

