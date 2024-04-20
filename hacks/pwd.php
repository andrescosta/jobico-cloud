<?php

$username = "debian";
$password = "debian";
$randomSaltString = 'setARandomStringHere';
$hashedPassword = crypt($password, '$6$rounds=4096$' . $randomSaltString . '$');
echo $hashedPassword;

