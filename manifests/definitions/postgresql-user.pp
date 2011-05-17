/*

==Definition: postgresql::user

Create a new PostgreSQL user

*/
define postgresql::user(
  $ensure=present,
  $password=false,
  $superuser=false,
  $createdb=false,
  $createrole=false,
  $hostname='/var/run/postgresql',
  $port='5432',
  $user='postgres') {

  $pgpass = $password ? {
    false   => "",
    default => "$password",
  }

  $superusertext = $superuser ? {
    false   => "NOSUPERUSER",
    default => "SUPERUSER",
  }

  $createdbtext = $createdb ? {
    false   => "NOCREATEDB",
    default => "CREATEDB",
  }

  $createroletext = $createrole ? {
    false   => "NOCREATEROLE",
    default => "CREATEROLE",
  }

  # Connection string
  $connection = "-h ${hostname} -p ${port} -U ${user}"

  case $ensure {
    present: {

      # The createuser command always prompts for the password.
      # User with '-' like www-data must be inside double quotes
      exec { "Create postgres user $name":
        path => ["/bin", "/usr/bin"],
        command => $password ? {
          false => "psql ${connection} -c \"CREATE USER \\\"$name\\\" \" ",
          default => "psql ${connection} -c \"CREATE USER \\\"$name\\\" PASSWORD '$password'\" ",
        },
        user    => "postgres",
        unless  => "psql ${connection} -c '\\du' | egrep '^  *$name '",
        require => [User["postgres"], Service["postgresql"]],
      }

      exec { "Set SUPERUSER attribute for postgres user $name":
        path => ["/bin", "/usr/bin"],
        command => "psql ${connection} -c 'ALTER USER \"$name\" $superusertext' ",
        user    => "postgres",
        unless  => "psql ${connection} -tc \"SELECT rolsuper FROM pg_roles WHERE rolname = '$name'\" |grep -q $(echo $superuser |cut -c 1)",
        require => [User["postgres"], Exec["Create postgres user $name"],
                    Service["postgresql"]],
      }

      exec { "Set CREATEDB attribute for postgres user $name":
        path => ["/bin", "/usr/bin"],
        command => "psql ${connection} -c 'ALTER USER \"$name\" $createdbtext' ",
        user    => "postgres",
        unless  => "psql ${connection} -tc \"SELECT rolcreatedb FROM pg_roles WHERE rolname = '$name'\" |grep -q $(echo $createdb |cut -c 1)",
        require => [User["postgres"], Exec["Create postgres user $name"],
                    Service["postgresql"]],
      }

      exec { "Set CREATEROLE attribute for postgres user $name":
        path => ["/bin", "/usr/bin"],
        command => "psql ${connection} -c 'ALTER USER \"$name\" $createroletext' ",
        user    => "postgres",
        unless  => "psql ${connection} -tc \"SELECT rolcreaterole FROM pg_roles WHERE rolname = '$name'\" |grep -q $(echo $createrole |cut -c 1)",
        require => [User["postgres"], Exec["Create postgres user $name"],
                    Service["postgresql"]],
      }

      if $password {
        $host = $hostname ? {
          '/var/run/postgresql' => "localhost",
          default               => $hostname,
        }

        # change only if it's not the same password
        exec { "Change password for postgres user $name":
          path => ["/bin", "/usr/bin"],
          command => "psql ${connection} -c \"ALTER USER \\\"$name\\\" PASSWORD '$password' \"",
          user    => "postgres",
          require => [User["postgres"], Exec["Create postgres user $name"],
                      Service["postgresql"]],
        }
      }

    }

    absent:  {
      exec { "Remove postgres user $name":
        path => ["/bin", "/usr/bin"],
        require => Service["postgresql"],
        command => "psql ${connection} -c 'DROP USER \"$name\" ' ",
        user    => "postgres",
        onlyif  => "psql ${connection} -c '\\du' | grep '$name  *|'"
      }
    }

    default: {
      fail "Invalid 'ensure' value '$ensure' for postgres::user"
      }
    }
}
