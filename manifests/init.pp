# Class: supervisor
#
# Usage:
#   include supervisor
#
#   class { 'supervisor':
#     version                 => '3.1.3',
#     include_superlance      => false,
#     enable_http_inet_server => true,
#   }

class supervisor (
  $enable_http_inet_server  = false,
  $include_superlance       = true,
  $version                  = '3.1.3',
) {

  case $::osfamily {
    redhat: {
      if $::operatingsystem == 'Amazon' {
        $path_config    = '/etc'
      }
      else {
        $path_config    = '/etc'
      }
    }
    debian: {
      $path_config    = '/etc'
    }
    default: { fail("ERROR: ${::osfamily} based systems are not supported!") }
  }

  # uncomment this when internal pr_856 is merged
  require ::python

  package { 'supervisor':
    ensure   => $version,
    provider => 'pip'
  }

  # install start/stop script
  file { '/etc/init.d/supervisord':
    source => "puppet:///modules/supervisor/${::osfamily}.supervisord",
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/var/log/supervisor':
    ensure  => directory,
    purge   => true,
    backup  => false,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Package['supervisor'],
  }

  file { "${path_config}/supervisord.conf":
    ensure  => file,
    content => template('supervisor/supervisord.conf.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['supervisor'],
    notify  => Service['supervisord'],
  }

  file { "${path_config}/supervisord.d":
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File["${path_config}/supervisord.conf"],
  }

  exec { "Reload systemd daemon for new supervisord config":
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    subscribe   => [
      File["/etc/init.d/supervisord"],
      File["${path_config}/supervisord.conf"],
    ]
  }

  service { 'supervisord':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => [
      File["/etc/init.d/supervisord"],
      File["${path_config}/supervisord.conf"],
    ],
    subscribe  => Exec["Reload systemd daemon for new supervisord config"],
  }

  if $include_superlance {
    package { 'superlance':
      ensure   => installed,
      provider => 'pip',
      require  => Package['supervisor'],
    }
  }

}
